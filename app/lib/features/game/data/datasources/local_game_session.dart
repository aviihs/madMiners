import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/game_target.dart';
import '../../domain/entities/session_event.dart';
import '../../domain/repositories/game_session_repository.dart';

/// Offline practice against bots, using exactly the same rules as the server.
///
/// On phones and desktop the simulation (bots, pathfinding, fluids…) runs in
/// a background isolate, so the UI thread only has to draw: that's what keeps
/// the game smooth on mid-range Android. On the web (no isolates) it runs on
/// the main thread as before.
class LocalGameSession implements GameSession {
  LocalGameSession(this.target);

  final OfflineTarget target;
  static const _you = 'local-player';

  final _events = StreamController<SessionEvent>.broadcast();
  late final _Backend _backend = kIsWeb || runOnMainThread ? _InlineBackend(_emit) : _IsolateBackend(_emit);

  /// Tests that drive time with a fake clock (widget tests) need the
  /// simulation on the main thread.
  static bool runOnMainThread = false;

  @override
  Stream<SessionEvent> get events => _events.stream;

  void _emit(SessionEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  Future<void> start() => _backend.start(target.settings, target.playerName, Random().nextInt(1 << 31));

  @override
  void sendInput(PlayerInput input) => _backend.send(('in', input));

  @override
  void buyUpgrade(UpgradeKind kind) => _backend.send(('up', kind));

  @override
  void buyItem(ItemKind kind) => _backend.send(('buy', kind));

  @override
  void useItem(ItemKind kind) => _backend.send(('use', kind));

  @override
  void chat(String text) => _backend.send(('chat', text));

  @override
  Future<void> leave() async {
    await _backend.stop();
    await _events.close();
  }
}

abstract class _Backend {
  Future<void> start(MatchSettings settings, String name, int seed);
  void send(Object command);
  Future<void> stop();
}

/// Applies a UI command to the simulation (shared by both backends).
void _apply(GameSimulation sim, Object command) {
  const you = LocalGameSession._you;
  switch (command) {
    case ('in', final PlayerInput i):
      sim.setInput(you, i);
    case ('up', final UpgradeKind k):
      sim.requestUpgrade(you, k);
    case ('buy', final ItemKind k):
      sim.buyItem(you, k);
    case ('use', final ItemKind k):
      sim.useItem(you, k);
    case ('chat', final String t):
      sim.chat(you, t);
  }
}

/// Runs ticks at a steady rate and reports what clients need to know.
/// Lives wherever the simulation lives (isolate or main thread).
class _Runner {
  _Runner(this.sim, this.out, {this.wallClock = true});

  /// Isolate: steady ticks from a real clock. Main thread (web, widget
  /// tests): one tick per timer beat, which also follows a fake test clock.
  final bool wallClock;
  final GameSimulation sim;

  /// Receives `('snap', WorldSnapshot)`, `('hint', TreasureHint)`, `('end', MatchResult)`.
  final void Function(Object) out;
  TreasureHint _hint = TreasureHint.none;
  Timer? _timer;
  final _clock = Stopwatch();
  int _done = 0;

  void start() {
    if (!wallClock) {
      _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ Balance.tickRate), (_) => _tick());
      return;
    }
    _clock.start();
    // Fixed-step: catch up on missed ticks (a few at most), never drift.
    _timer = Timer.periodic(const Duration(milliseconds: 8), (_) {
      final due = _clock.elapsedMicroseconds * Balance.tickRate ~/ 1000000;
      var steps = 0;
      while (_done < due && steps < 4 && _timer != null) {
        _tick();
        _done++;
        steps++;
      }
      if (due - _done > 8) _done = due; // fell far behind (app paused): skip ahead
    });
  }

  void _tick() {
    sim.update(1 / Balance.tickRate);
    if (sim.tick % Balance.snapshotEvery == 0 || sim.ended) {
      out(('snap', sim.takeSnapshot()));
      final h = sim.hintFor(LocalGameSession._you);
      if (h != _hint) {
        _hint = h;
        out(('hint', h));
      }
    }
    if (sim.ended) {
      stop();
      out(('end', sim.results()));
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Turns runner messages into session events on the UI side.
void _deliver(Object msg, void Function(SessionEvent) emit, MatchSettings settings) {
  switch (msg) {
    case ('joined', final GameMap map):
      emit(const SessionLink(LinkStatus.connected, rttMs: 0));
      emit(SessionJoined(youId: LocalGameSession._you, roomCode: 'OFFLINE', settings: settings, map: map, reconnected: false));
    case ('snap', final WorldSnapshot s):
      emit(SessionSnapshot(s));
    case ('hint', final TreasureHint h):
      emit(SessionHint(h));
    case ('end', final MatchResult r):
      emit(SessionEnded(r));
  }
}

// ---- background isolate -----------------------------------------------------------

class _IsolateBackend implements _Backend {
  _IsolateBackend(this._emit);
  final void Function(SessionEvent) _emit;
  final _fromSim = ReceivePort();
  Isolate? _isolate;
  SendPort? _toSim;
  final List<Object> _pending = [];
  late MatchSettings _settings;

  @override
  Future<void> start(MatchSettings settings, String name, int seed) async {
    _settings = settings;
    _fromSim.listen((msg) {
      if (msg is SendPort) {
        _toSim = msg;
        _pending.forEach(msg.send);
        _pending.clear();
        return;
      }
      _deliver(msg as Object, _emit, _settings);
    });
    _isolate = await Isolate.spawn(_simMain, (_fromSim.sendPort, settings, name, seed), debugName: 'mad-miners-sim');
  }

  @override
  void send(Object command) {
    final port = _toSim;
    if (port == null) {
      _pending.add(command);
    } else {
      port.send(command);
    }
  }

  @override
  Future<void> stop() async {
    _toSim?.send('stop');
    _fromSim.close();
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
  }
}

/// Entry point of the simulation isolate.
void _simMain((SendPort, MatchSettings, String, int) args) {
  final (out, settings, name, seed) = args;
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  final sim = GameSimulation(settings: settings, seed: seed)..addHuman(LocalGameSession._you, name);
  out.send(('joined', sim.publicMap()));
  final runner = _Runner(sim, out.send)..start();
  inbox.listen((cmd) {
    if (cmd == 'stop') {
      runner.stop();
      inbox.close();
      return;
    }
    _apply(sim, cmd as Object);
  });
}

// ---- web: same thread -------------------------------------------------------------

class _InlineBackend implements _Backend {
  _InlineBackend(this._emit);
  final void Function(SessionEvent) _emit;
  GameSimulation? _sim;
  _Runner? _runner;

  @override
  Future<void> start(MatchSettings settings, String name, int seed) async {
    final sim = _sim = GameSimulation(settings: settings, seed: seed)..addHuman(LocalGameSession._you, name);
    // Let listeners subscribe before the first event.
    await Future<void>.delayed(Duration.zero);
    _deliver(('joined', sim.publicMap()), _emit, settings);
    _runner = _Runner(sim, (m) => _deliver(m, _emit, settings), wallClock: false)..start();
  }

  @override
  void send(Object command) {
    final sim = _sim;
    if (sim != null) _apply(sim, command);
  }

  @override
  Future<void> stop() async => _runner?.stop();
}
