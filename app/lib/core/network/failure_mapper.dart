import '../error/failures.dart';
import '../error/result.dart';
import 'api_exception.dart';

/// Runs a data-layer call and maps transport exceptions to [Failure]s.
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on OfflineException {
    return const Err(NetworkFailure());
  } on ApiException catch (e) {
    if (e.status == 401) return const Err(UnauthorizedFailure());
    return Err(ServerFailure(e.message, code: e.code));
  }
}
