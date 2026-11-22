import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../app.dart';
import '../audio.dart';
import '../di.dart';
import 'loading_screen.dart';

/// Startup sequence:
///
/// 1. The OS splash (logo on the game's dark colour) stays up while the
///    loading art is decoded, so nothing ever flashes white or pops in.
/// 2. The loading screen fades in and the bar follows real work: settings,
///    sounds, then restoring the saved session.
/// 3. The menu is built *behind* the loading screen and gets a couple of
///    frames to lay out and paint, then the loading screen fades away. The
///    first frame the player sees of the menu is never a slow one.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _progress = ValueNotifier<double>(0);
  bool _started = false;
  bool _artReady = false;
  bool _leaving = false;
  bool _gone = false;
  AuthCubit? _auth;

  /// Shortest time the loading screen stays up, so it never just blinks.
  static const _minShown = Duration(milliseconds: 1500);

  /// Longest we wait for the server to confirm a saved session. After that
  /// the menu opens anyway and finishes signing in by itself.
  static const _maxAuthWait = Duration(seconds: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_boot());
    }
  }

  Future<void> _boot() async {
    // 1. Decode the art while the OS splash is still showing.
    try {
      await Future.wait([for (final a in LoadingArt.all) precacheImage(a, context)]);
    } catch (_) {
      // Missing art must never block the game from starting.
    }
    FlutterNativeSplash.remove();
    if (!mounted) return;
    setState(() => _artReady = true);
    final shown = Stopwatch()..start();
    _progress.value = 0.12;

    // 2. Real work.
    await configureDependencies();
    _progress.value = 0.3;
    await sl<GameAudio>().init().timeout(const Duration(seconds: 4), onTimeout: () {});
    _progress.value = 0.62;

    final auth = sl<AuthCubit>();
    unawaited(auth.start());
    if (auth.state is AuthRestoring) {
      await auth.stream.firstWhere((s) => s is! AuthRestoring).timeout(_maxAuthWait, onTimeout: () => auth.state);
    }
    _progress.value = 0.88;
    if (!mounted) return;

    // 3. Build the menu underneath and let it settle for two frames.
    setState(() => _auth = auth);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    _progress.value = 1;

    final left = _minShown - shown.elapsed;
    // Let the bar visibly reach 100% before fading out.
    await Future<void>.delayed(left > const Duration(milliseconds: 450) ? left : const Duration(milliseconds: 450));
    if (mounted) setState(() => _leaving = true);
  }

  @override
  void dispose() {
    _progress.dispose();
    _auth?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(key: ValueKey('base'), color: LoadingScreen.background),
        if (_auth case final auth?) MadMinersApp(key: const ValueKey('app'), auth: auth),
        if (!_gone)
          IgnorePointer(
            key: const ValueKey('loading'),
            ignoring: _leaving,
            child: AnimatedOpacity(
              opacity: _leaving ? 0 : 1,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOut,
              onEnd: () {
                if (_leaving) setState(() => _gone = true);
              },
              child: LoadingScreen(progress: _progress, showArt: _artReady),
            ),
          ),
      ],
    ),
  );
}
