import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/get_global_leaderboard.dart';

class LeaderboardState {
  const LeaderboardState({this.loading = true, this.entries = const [], this.error});
  final bool loading;
  final List<LeaderboardEntry> entries;
  final String? error;
}

class LeaderboardCubit extends Cubit<LeaderboardState> {
  LeaderboardCubit(this._get) : super(const LeaderboardState());
  final GetGlobalLeaderboard _get;

  Future<void> load(String token) async {
    emit(const LeaderboardState());
    final r = await _get(token);
    emit(r.fold((f) => LeaderboardState(loading: false, error: f.message), (e) => LeaderboardState(loading: false, entries: e)));
  }
}
