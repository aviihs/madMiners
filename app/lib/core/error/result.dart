import 'failures.dart';

/// Either a value or a [Failure]. Keeps use-case signatures honest.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure f) onErr, R Function(T v) onOk) => switch (this) {
    Ok<T>(:final value) => onOk(value),
    Err<T>(:final failure) => onErr(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
