import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/server_config.dart';
import '../core/network/api_client.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/datasources/google_auth_data_source.dart';
import '../features/auth/data/datasources/session_local_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/auth_usecases.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/game/data/repositories/game_session_repository_impl.dart';
import '../features/game/domain/repositories/game_session_repository.dart';
import '../features/game/domain/usecases/open_game_session.dart';
import '../features/leaderboard/data/datasources/leaderboard_remote_data_source.dart';
import '../features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import '../features/leaderboard/domain/repositories/leaderboard_repository.dart';
import '../features/leaderboard/domain/usecases/get_global_leaderboard.dart';
import '../features/leaderboard/presentation/cubit/leaderboard_cubit.dart';
import '../features/lobby/data/datasources/lobby_remote_data_source.dart';
import '../features/lobby/data/repositories/lobby_repository_impl.dart';
import '../features/lobby/domain/repositories/lobby_repository.dart';
import '../features/lobby/domain/usecases/lobby_usecases.dart';
import '../features/lobby/presentation/cubit/lobby_cubit.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/profile/data/repositories/profile_repository_impl.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/domain/usecases/profile_usecases.dart';
import '../features/profile/presentation/cubit/profile_cubit.dart';
import '../features/store/data/datasources/store_remote_data_source.dart';
import '../features/store/data/repositories/store_repository_impl.dart';
import '../features/store/domain/repositories/store_repository.dart';
import '../features/store/domain/usecases/store_usecases.dart';
import '../features/store/presentation/cubit/store_cubit.dart';
import '../features/rewards/data/rewards_remote_data_source.dart';
import 'audio.dart';
import 'settings.dart';

/// Service locator. The only place that knows concrete implementations.
final sl = GetIt.instance;

bool get _isTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

Future<void> configureDependencies() async {
  // Core
  sl
    ..registerSingleton<SharedPreferences>(await SharedPreferences.getInstance())
    ..registerLazySingleton(ServerConfig.new)
    ..registerLazySingleton(() => GameSettings(sl()))
    // Silent under `flutter test` (no audio plugin there).
    ..registerLazySingleton(() => GameAudio(sl(), enabled: !_isTest))
    ..registerLazySingleton(() => ApiClient(sl()))
    // Auth
    ..registerLazySingleton(() => AuthRemoteDataSource(sl()))
    ..registerLazySingleton(() => SessionLocalDataSource(sl()))
    ..registerLazySingleton(GoogleAuthDataSource.new)
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl(), sl(), sl()))
    ..registerFactory(() => SignInAsGuest(sl()))
    ..registerFactory(() => SignInWithGoogle(sl()))
    ..registerFactory(() => RestoreSession(sl()))
    ..registerFactory(() => RefreshProfile(sl()))
    ..registerFactory(() => SignOut(sl()))
    ..registerFactory(() => CheckServer(sl()))
    ..registerFactory(() => FindServer(sl()))
    ..registerFactory(() => AuthCubit(signIn: sl(), google: sl(), restore: sl(), refresh: sl(), signOut: sl(), repo: sl()))
    // Lobby
    ..registerLazySingleton(() => LobbyRemoteDataSource(sl()))
    ..registerLazySingleton(() => RewardsRemoteDataSource(sl()))
    ..registerLazySingleton<LobbyRepository>(() => LobbyRepositoryImpl(sl()))
    ..registerFactory(() => ListRooms(sl()))
    ..registerFactory(() => CreateRoom(sl()))
    ..registerFactory(() => JoinRoom(sl()))
    ..registerFactory(() => JoinRoomByCode(sl()))
    ..registerFactory(() => QuickPlay(sl()))
    ..registerFactory(
      () => LobbyCubit(listRooms: sl(), createRoom: sl(), joinRoom: sl(), joinByCode: sl(), quickPlay: sl()),
    )
    // Leaderboard
    ..registerLazySingleton(() => LeaderboardRemoteDataSource(sl()))
    ..registerLazySingleton<LeaderboardRepository>(() => LeaderboardRepositoryImpl(sl()))
    ..registerFactory(() => GetGlobalLeaderboard(sl()))
    ..registerFactory(() => GetTodayLeaderboard(sl()))
    ..registerFactory(() => LeaderboardCubit(sl(), sl()))
    // Profile
    ..registerLazySingleton(() => ProfileRemoteDataSource(sl()))
    ..registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl(sl()))
    ..registerFactory(() => GetMatchHistory(sl()))
    ..registerFactory(() => GetWalletHistory(sl()))
    ..registerFactory(() => ProfileCubit(sl(), sl()))
    // Store
    ..registerLazySingleton(() => StoreRemoteDataSource(sl()))
    ..registerLazySingleton<StoreRepository>(() => StoreRepositoryImpl(sl()))
    ..registerFactory(() => PurchaseCosmetic(sl()))
    ..registerFactory(() => EquipCosmetic(sl()))
    ..registerFactory(() => StoreCubit(sl(), sl()))
    // Game
    ..registerLazySingleton<GameSessionRepository>(() => GameSessionRepositoryImpl(sl()))
    ..registerFactory(() => OpenGameSession(sl()));
}
