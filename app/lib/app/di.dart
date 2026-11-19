import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/server_config.dart';
import '../core/network/api_client.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
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
import '../features/store/data/datasources/store_remote_data_source.dart';
import '../features/store/data/repositories/store_repository_impl.dart';
import '../features/store/domain/repositories/store_repository.dart';
import '../features/store/domain/usecases/store_usecases.dart';
import '../features/store/presentation/cubit/store_cubit.dart';

/// Service locator. The only place that knows concrete implementations.
final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Core
  sl
    ..registerSingleton<SharedPreferences>(await SharedPreferences.getInstance())
    ..registerLazySingleton(ServerConfig.new)
    ..registerLazySingleton(() => ApiClient(sl()))
    // Auth
    ..registerLazySingleton(() => AuthRemoteDataSource(sl()))
    ..registerLazySingleton(() => SessionLocalDataSource(sl()))
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl(), sl()))
    ..registerFactory(() => SignInAsGuest(sl()))
    ..registerFactory(() => RestoreSession(sl()))
    ..registerFactory(() => RefreshProfile(sl()))
    ..registerFactory(() => SignOut(sl()))
    ..registerFactory(() => CheckServer(sl()))
    ..registerFactory(() => FindServer(sl()))
    ..registerFactory(() => AuthCubit(signIn: sl(), restore: sl(), refresh: sl(), signOut: sl(), repo: sl()))
    // Lobby
    ..registerLazySingleton(() => LobbyRemoteDataSource(sl()))
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
