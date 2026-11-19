import 'dart:async';
import 'dart:math';

import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/game_target.dart';
import '../../domain/entities/session_event.dart';
import '../../domain/repositories/game_session_repository.dart';

/// Runs the authoritative [GameSimulation] on-device: offline practice
/// against bots, using exactly the same rules as the server.
class LocalGameSession implements GameSession {
  LocalGameSession(this.target);

  final OfflineTarget target;
  static const _you = 'local-player';

  final _events = StreamController<SessionEvent>.broadcast();
  late final GameSimulation _sim;
  Timer? _timer;

  @override
  Stream<SessionEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    _sim = GameSimulation(settings: target.settings, seed: Random().nextInt(1 << 31));
    _sim.addHuman(_you, target.playerName);
    // Let listeners subscribe before the first event.
    await Future<void>.delayed(Duration.zero);
    _events
      ..add(const SessionLink(LinkStatus.connected, rttMs: 0))
      ..add(SessionJoined(youId: _you, roomCode: 'OFFLINE', settings: target.settings, map: _sim.map.clone(), reconnected: false));
    _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ Balance.tickRate), (_) => _tick());
  }

  void _tick() {
    _sim.update(1 / Balance.tickRate);
    if (_sim.tick % Balance.snapshotEvery == 0 || _sim.ended) {
      _events.add(SessionSnapshot(_sim.takeSnapshot()));
    }
    if (_sim.ended) {
      _timer?.cancel();
      _events.add(SessionEnded(_sim.results()));
    }
  }

  @override
  void sendInput(PlayerInput input) => _sim.setInput(_you, input);

  @override
  void buyUpgrade(UpgradeKind kind) => _sim.requestUpgrade(_you, kind);

  @override
  void chat(String text) => _sim.chat(_you, text);

  @override
  Future<void> leave() async {
    _timer?.cancel();
    await _events.close();
  }
}
