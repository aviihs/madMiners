import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/room.dart';
import '../../domain/usecases/lobby_usecases.dart';

class LobbyState extends Equatable {
  const LobbyState({this.rooms = const [], this.loading = false, this.busy = false, this.error, this.ticket});

  final List<RoomSummary> rooms;
  final bool loading;

  /// A join/create request is in flight.
  final bool busy;
  final String? error;

  /// One-shot: set when the player may enter a room.
  final RoomTicket? ticket;

  LobbyState copyWith({List<RoomSummary>? rooms, bool? loading, bool? busy, String? error, RoomTicket? ticket}) =>
      LobbyState(rooms: rooms ?? this.rooms, loading: loading ?? this.loading, busy: busy ?? this.busy, error: error, ticket: ticket);

  @override
  List<Object?> get props => [rooms, loading, busy, error, ticket];
}

class LobbyCubit extends Cubit<LobbyState> {
  LobbyCubit({
    required ListRooms listRooms,
    required CreateRoom createRoom,
    required JoinRoom joinRoom,
    required JoinRoomByCode joinByCode,
    required QuickPlay quickPlay,
  }) : _list = listRooms,
       _create = createRoom,
       _join = joinRoom,
       _joinByCode = joinByCode,
       _quick = quickPlay,
       super(const LobbyState());

  final ListRooms _list;
  final CreateRoom _create;
  final JoinRoom _join;
  final JoinRoomByCode _joinByCode;
  final QuickPlay _quick;

  Future<void> refresh(String token) async {
    emit(state.copyWith(loading: true));
    final r = await _list(token);
    emit(r.fold((f) => state.copyWith(loading: false, error: f.message), (rooms) => state.copyWith(loading: false, rooms: rooms)));
  }

  Future<void> quickPlay(String token) => _enter(() => _quick(token));
  Future<void> create(String token, CreateRoomParams p) => _enter(() => _create(token, p));
  Future<void> join(String token, String roomId) => _enter(() => _join(token, roomId));
  Future<void> joinByCode(String token, String code) => _enter(() => _joinByCode(token, code));

  void ticketConsumed() => emit(state.copyWith());

  Future<void> _enter(Future<Result<RoomTicket>> Function() call) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    final r = await call();
    emit(r.fold((f) => state.copyWith(busy: false, error: f.message), (t) => state.copyWith(busy: false, ticket: t)));
  }
}
