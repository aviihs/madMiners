import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences, saved on the device: sound, vibration and the size of
/// the touch controls.
class GameSettings {
  GameSettings(this._prefs)
    : music = ValueNotifier(_prefs.getBool(_kMusic) ?? true),
      sfx = ValueNotifier(_prefs.getBool(_kSfx) ?? true),
      vibration = ValueNotifier(_prefs.getBool(_kVibe) ?? true),
      controlScale = ValueNotifier((_prefs.getDouble(_kScale) ?? 1.0).clamp(minScale, maxScale)),
      leftHanded = ValueNotifier(_prefs.getBool(_kLeft) ?? false),
      highGraphics = ValueNotifier(_prefs.getBool(_kGfx) ?? !_isMobile) {
    highGraphics.addListener(() => _prefs.setBool(_kGfx, highGraphics.value));
    music.addListener(() => _prefs.setBool(_kMusic, music.value));
    sfx.addListener(() => _prefs.setBool(_kSfx, sfx.value));
    vibration.addListener(() => _prefs.setBool(_kVibe, vibration.value));
    controlScale.addListener(() => _prefs.setDouble(_kScale, controlScale.value));
    leftHanded.addListener(() => _prefs.setBool(_kLeft, leftHanded.value));
  }

  final SharedPreferences _prefs;
  static const _kMusic = 'settings.music';
  static const _kSfx = 'settings.sfx';
  static const _kVibe = 'settings.vibration';
  static const _kScale = 'settings.controlScale';
  static const _kLeft = 'settings.leftHanded';
  static const _kGfx = 'settings.highGraphics';

  static bool get _isMobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static const double minScale = 0.75;
  static const double maxScale = 1.35;

  final ValueNotifier<bool> music;
  final ValueNotifier<bool> sfx;
  final ValueNotifier<bool> vibration;

  /// Size multiplier for the joystick and action buttons.
  final ValueNotifier<double> controlScale;

  /// Swap sides: buttons on the left, joystick on the right.
  final ValueNotifier<bool> leftHanded;

  /// Extra effects (menu blur, more lights and particles). Off by default on
  /// phones so the game stays smooth on mid-range devices.
  final ValueNotifier<bool> highGraphics;
}
