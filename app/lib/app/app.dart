import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/lobby/presentation/pages/lobby_page.dart';
import 'di.dart';
import 'theme.dart';

class MadMinersApp extends StatelessWidget {
  const MadMinersApp({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<AuthCubit>()..start(),
    child: MaterialApp(
      title: 'Mad Miners',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (a, b) => a.runtimeType != b.runtimeType || b is AuthSignedOut || b is AuthSignedIn,
        builder: (context, state) => switch (state) {
          AuthRestoring() => const Scaffold(body: Center(child: CircularProgressIndicator())),
          AuthSignedOut() => LoginPage(key: const ValueKey('login'), state: state),
          AuthSignedIn(:final session) => LobbyPage(key: ValueKey(session.profile.id), session: session),
        },
      ),
    ),
  );
}
