/// A success-or-failure value for operations whose failure is expected and shown to the user
/// (import of a backup file, parsing user input). Programming errors still throw.
sealed class Result<T> {
  const Result();

  /// Shorthand for [Ok].
  const factory Result.ok(T value) = Ok<T>;

  /// Shorthand for [Err].
  const factory Result.err(String message, [Object? cause]) = Err<T>;

  bool get isOk => this is Ok<T>;

  /// The value, or null when this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// Maps the success value; errors pass through unchanged.
  Result<R> map<R>(R Function(T value) f) => switch (this) {
        Ok<T>(:final value) => Ok<R>(f(value)),
        Err<T>(:final message, :final cause) => Err<R>(message, cause),
      };
}

/// Success.
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

/// Failure with a plain-language [message] suitable for the UI.
final class Err<T> extends Result<T> {
  const Err(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  bool operator ==(Object other) => other is Err<T> && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'Err($message)';
}
