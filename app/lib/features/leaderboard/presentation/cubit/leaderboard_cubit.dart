import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/get_global_leaderboard.dart';

enum Board { today, allTime }

class LeaderboardState {
  const LeaderboardState({this.board = Board.today, this.loading = true, this.entries = const [], this.error});
  final Board board;
  final bool loading;
  final List<LeaderboardEntry> entries;
  final String? error;
}

class LeaderboardCubit extends Cubit<LeaderboardState> {
  LeaderboardCubit(this._global, this._today) : super(const LeaderboardState());
  final GetGlobalLeaderboard _global;
  final GetTodayLeaderboard _today;

  Future<void> load(String token, [Board? board]) async {
    final b = board ?? state.board;
    emit(LeaderboardState(board: b));
    final r = await (b == Board.today ? _today(token) : _global(token));
    emit(
      r.fold(
        (f) => LeaderboardState(board: b, loading: false, error: f.message),
        (e) => LeaderboardState(board: b, loading: false, entries: e),
      ),
    );
  }
}
