import 'package:equatable/equatable.dart';

/// Domain-level failure. Data sources throw; repositories convert to this.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});
  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Cannot reach the game server.']);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Session expired. Please sign in again.']) : super(code: 'UNAUTHORIZED');
}
