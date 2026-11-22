import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/lobby/presentation/pages/lobby_page.dart';
import 'di.dart';
import 'settings.dart';
import 'theme.dart';
import 'ui/ui.dart';

class MadMinersApp extends StatelessWidget {
  const MadMinersApp({super.key, this.auth});

  /// Already started by the loading screen (see `boot/app_root.dart`).
  /// When null (tests), the app creates and starts its own.
  final AuthCubit? auth;

  @override
  Widget build(BuildContext context) {
    final app = _materialApp();
    return auth != null ? BlocProvider.value(value: auth!, child: app) : BlocProvider(create: (_) => sl<AuthCubit>()..start(), child: app);
  }

  Widget _materialApp() => MaterialApp(
    title: 'Mad Miners',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // Menu blur follows the "High quality graphics" setting.
    builder: (context, child) => ValueListenableBuilder<bool>(
      valueListenable: sl<GameSettings>().highGraphics,
      builder: (context, hq, _) => GlassScope(blur: hq, child: child!),
    ),
    home: BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.runtimeType != b.runtimeType || b is AuthSignedOut || b is AuthSignedIn,
      builder: (context, state) => switch (state) {
        // Only seen when the server is slow to wake up after the loading screen.
        AuthRestoring() => const Scaffold(
          body: AppBackground(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(radius: 14),
                  SizedBox(height: 14),
                  Text('Connecting to the mine…', style: MMText.callout),
                ],
              ),
            ),
          ),
        ),
        AuthSignedOut() => LoginPage(key: const ValueKey('login'), state: state),
        AuthSignedIn(:final session) => LobbyPage(key: ValueKey(session.profile.id), session: session),
      },
    ),
  );
}
