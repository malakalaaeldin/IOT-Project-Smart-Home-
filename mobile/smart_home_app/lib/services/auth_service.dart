import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication (email/password). No credentials live in the code:
/// users type them on the login screen.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  /// Turns Firebase error codes into sentences a user can act on.
  static String friendlyError(Object error) {
    final code = error is FirebaseAuthException ? error.code : '';
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return "That email and password don't match an account.";
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead.';
      case 'weak-password':
        return 'Choose a password of at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Check Wi-Fi or mobile data.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
    }
    if (error is FirebaseAuthException) return error.message ?? error.code;
    return error.toString();
  }
}
