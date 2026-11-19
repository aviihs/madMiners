import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({required this.serverUrl, this.error, this.busy = false});
  final String serverUrl;
  final String? error;
  final bool busy;
  @override
  List<Object?> get props => [serverUrl, error, busy];
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session);
  final Session session;
  @override
  List<Object?> get props => [session];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required SignInAsGuest signIn,
    required RestoreSession restore,
    required RefreshProfile refresh,
    required SignOut signOut,
    required AuthRepository repo,
  }) : _signIn = signIn,
       _restore = restore,
       _refresh = refresh,
       _signOut = signOut,
       _repo = repo,
       super(const AuthRestoring());

  final SignInAsGuest _signIn;
  final RestoreSession _restore;
  final RefreshProfile _refresh;
  final SignOut _signOut;
  final AuthRepository _repo;

  Future<void> start() async {
    final result = await _restore();
    if (result == null) return emit(AuthSignedOut(serverUrl: _repo.lastServerUrl));
    result.fold(
      (f) => emit(AuthSignedOut(serverUrl: _repo.lastServerUrl, error: f.message)),
      (s) => emit(AuthSignedIn(s)),
    );
  }

  Future<void> signInAsGuest(String username, String serverUrl) async {
    emit(AuthSignedOut(serverUrl: serverUrl, busy: true));
    final result = await _signIn(username: username, serverUrl: serverUrl);
    result.fold(
      (f) => emit(AuthSignedOut(serverUrl: serverUrl, error: f.message)),
      (s) => emit(AuthSignedIn(s)),
    );
  }

  void playOffline(String username) {
    final name = username.trim().isEmpty ? 'Miner' : username.trim();
    emit(AuthSignedIn(Session.offline(name)));
  }

  Future<void> refreshProfile() async {
    final s = state;
    if (s is! AuthSignedIn || !s.session.isOnline) return;
    if (await _refresh(s.session) case Ok(:final value)) emit(AuthSignedIn(value));
  }

  /// After a store purchase / equip, the server returns the fresh profile.
  void profileUpdated(PlayerProfile profile) {
    final s = state;
    if (s is AuthSignedIn) emit(AuthSignedIn(s.session.copyWith(profile: profile)));
  }

  Future<void> signOut() async {
    await _signOut();
    emit(AuthSignedOut(serverUrl: _repo.lastServerUrl));
  }
}
