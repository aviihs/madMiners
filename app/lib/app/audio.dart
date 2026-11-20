import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'settings.dart';

/// Sound effects, background music and vibration, all honouring
/// [GameSettings]. Every call is fire-and-forget and never throws: a device
/// without audio (or a test run) simply stays silent.
class GameAudio {
  GameAudio(this.settings, {bool enabled = true}) : _enabled = enabled {
    settings.music.addListener(_syncMusic);
  }

  final GameSettings settings;
  final bool _enabled;
  bool _ready = false;
  bool _wantMusic = false;
  final Map<Sfx, DateTime> _last = {};

  static const _files = {
    Sfx.dig: 'dig.wav',
    Sfx.rockBreak: 'break.wav',
    Sfx.coin: 'coin.wav',
    Sfx.gem: 'gem.wav',
    Sfx.explosion: 'explosion.wav',
    Sfx.smallBlast: 'small_blast.wav',
    Sfx.jump: 'jump.wav',
    Sfx.land: 'land.wav',
    Sfx.jet: 'jet.wav',
    Sfx.hurt: 'hurt.wav',
    Sfx.lava: 'lava.wav',
    Sfx.victory: 'victory.wav',
    Sfx.defeat: 'defeat.wav',
    Sfx.tick: 'tick.wav',
    Sfx.spring: 'spring.wav',
    Sfx.alarm: 'alarm.wav',
    Sfx.chest: 'chest.wav',
  };

  /// Shortest gap between two plays of the same sound, so a busy mine
  /// doesn't turn into noise.
  static const _minGap = {
    Sfx.dig: Duration(milliseconds: 90),
    Sfx.rockBreak: Duration(milliseconds: 60),
    Sfx.coin: Duration(milliseconds: 50),
    Sfx.jet: Duration(milliseconds: 420),
    Sfx.alarm: Duration(milliseconds: 1500),
  };

  Future<void> init() async {
    if (!_enabled || _ready) return;
    try {
      await FlameAudio.audioCache.loadAll([..._files.values, 'music.wav']);
      FlameAudio.bgm.initialize();
      _ready = true;
      _syncMusic();
    } catch (e) {
      debugPrint('Audio unavailable: $e');
    }
  }

  void play(Sfx s, {double volume = 1}) {
    if (!_ready || !settings.sfx.value || volume <= 0.02) return;
    final now = DateTime.now();
    final gap = _minGap[s];
    if (gap != null && now.difference(_last[s] ?? DateTime(0)) < gap) return;
    _last[s] = now;
    unawaited(FlameAudio.play(_files[s]!, volume: volume.clamp(0, 1)).then((_) {}, onError: (_) {}));
  }

  /// Start or stop the soundtrack (e.g. on in matches, off in menus).
  void music({required bool on}) {
    _wantMusic = on;
    _syncMusic();
  }

  void _syncMusic() {
    if (!_ready) return;
    try {
      if (_wantMusic && settings.music.value) {
        if (!FlameAudio.bgm.isPlaying) unawaited(FlameAudio.bgm.play('music.wav', volume: 0.35).catchError((_) {}));
      } else {
        unawaited(FlameAudio.bgm.stop().catchError((_) {}));
      }
    } catch (_) {}
  }

  /// Light/medium/heavy haptic tap, if vibration is on.
  void buzz([Haptic kind = Haptic.light]) {
    if (!_enabled || !settings.vibration.value) return;
    switch (kind) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}

enum Sfx { dig, rockBreak, coin, gem, explosion, smallBlast, jump, land, jet, hurt, lava, victory, defeat, tick, spring, alarm, chest }

enum Haptic { light, medium, heavy }
