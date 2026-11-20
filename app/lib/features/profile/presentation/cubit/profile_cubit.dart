import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/history.dart';
import '../../domain/usecases/profile_usecases.dart';

class ProfileState {
  const ProfileState({this.loading = true, this.matches = const [], this.wallet = const [], this.error});
  final bool loading;
  final List<MatchHistoryItem> matches;
  final List<WalletEntry> wallet;
  final String? error;
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._matches, this._wallet) : super(const ProfileState());
  final GetMatchHistory _matches;
  final GetWalletHistory _wallet;

  Future<void> load(String token) async {
    final (m, w) = await (_matches(token), _wallet(token)).wait;
    String? error;
    final matches = m.fold((f) {
      error = f.message;
      return <MatchHistoryItem>[];
    }, (v) => v);
    final wallet = w.fold((f) {
      error ??= f.message;
      return <WalletEntry>[];
    }, (v) => v);
    emit(ProfileState(loading: false, matches: matches, wallet: wallet, error: error));
  }
}
