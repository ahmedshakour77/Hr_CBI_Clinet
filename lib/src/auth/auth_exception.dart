/// A sign-in failure with a message fit to show a user.
///
/// Platform and network layers throw a wide variety of types; everything the
/// auth layer surfaces is funnelled through here so the UI has exactly one
/// thing to catch and one string to render.
class AuthException implements Exception {
  const AuthException(this.message, {this.cause, this.isCancellation = false});

  /// Human-readable, already suitable for a SnackBar.
  final String message;

  /// The underlying error, kept for logging.
  final Object? cause;

  /// True when the user backed out. Callers should stay silent rather than
  /// showing an error for something the user did deliberately.
  final bool isCancellation;

  const AuthException.cancelled()
    : message = 'Sign-in was cancelled.',
      cause = null,
      isCancellation = true;

  @override
  String toString() =>
      'AuthException: $message${cause == null ? '' : ' ($cause)'}';
}
