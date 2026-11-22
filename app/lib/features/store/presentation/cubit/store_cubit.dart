import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/player_profile.dart';
import '../../domain/usecases/store_usecases.dart';

class StoreState {
  const StoreState({this.slot = CosmeticSlot.outfit, this.preview, this.busyItem, this.error, this.message});
  final CosmeticSlot slot;

  /// Item being tried on (not necessarily owned).
  final CosmeticDef? preview;
  final String? busyItem;
  final String? error;
  final String? message;

  StoreState copyWith({
    CosmeticSlot? slot,
    CosmeticDef? preview,
    bool clearPreview = false,
    String? busyItem,
    String? error,
    String? message,
  }) => StoreState(
    slot: slot ?? this.slot,
    preview: clearPreview ? null : (preview ?? this.preview),
    busyItem: busyItem,
    error: error,
    message: message,
  );
}

class StoreCubit extends Cubit<StoreState> {
  StoreCubit(this._purchase, this._equip) : super(const StoreState());
  final PurchaseCosmetic _purchase;
  final EquipCosmetic _equip;

  void selectSlot(CosmeticSlot s) => emit(state.copyWith(slot: s, clearPreview: true));
  void tryOn(CosmeticDef c) => emit(state.copyWith(preview: c));

  /// Returns the updated profile on success.
  Future<PlayerProfile?> buy(String token, CosmeticDef c) async {
    emit(state.copyWith(busyItem: c.id));
    final bought = await _purchase(token, c.id);
    if (bought case Err(:final failure)) {
      emit(state.copyWith(error: failure.message));
      return null;
    }
    // Wear it right away.
    final r = await _equip(token, c.id);
    return r.fold(
      (f) {
        emit(state.copyWith(error: f.message));
        return (bought as Ok<PlayerProfile>).value;
      },
      (p) {
        emit(state.copyWith(message: '${c.name} unlocked!', clearPreview: true));
        return p;
      },
    );
  }

  Future<PlayerProfile?> equip(String token, CosmeticDef c) async {
    emit(state.copyWith(busyItem: c.id));
    final r = await _equip(token, c.id);
    return r.fold(
      (f) {
        emit(state.copyWith(error: f.message));
        return null;
      },
      (p) {
        emit(state.copyWith(clearPreview: true));
        return p;
      },
    );
  }
}
