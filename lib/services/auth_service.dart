import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Updates the signed-in user's display name and reloads the local
  /// FirebaseAuth user so the new value is readable immediately.
  static Future<String?> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return 'No user signed in.';
    try {
      await user.updateDisplayName(name);
      await user.reload();
      return null; // success
    } catch (e) {
      return 'Could not update name. Try again.';
    }
  }

  /// Uploads [file] to Firebase Storage at profile_photos/{uid}.jpg,
  /// sets it as the user's photoURL, reloads the user, and returns the
  /// download URL (or null if the upload/update failed).
  static Future<String?> uploadProfilePhoto(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      await user.reload();
      return url;
    } catch (e) {
      return null;
    }
  }

  static String _errorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
