import 'dart:io';
import 'package:flutter/foundation.dart'; // debugPrint ke liye
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
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  static Future<void> signOut() async => await _auth.signOut();

  static Future<String?> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return 'No user signed in.';
    try {
      await user.updateDisplayName(name);
      await user.reload();
      return null;
    } catch (e) {
      return 'Could not update name. Try again.';
    }
  }

  /// NEW: current password verify + new password set
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return 'No user signed in.';
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred); // current password verify
      await user.updatePassword(newPassword);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      debugPrint('changePassword failed: $e');
      return 'Could not update password. Try again.';
    }
  }

  static Future<String?> uploadProfilePhoto(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      await user.reload();
      return url;
    } on FirebaseException catch (e) {
      debugPrint('Storage upload failed → code: ${e.code}, msg: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Storage upload failed → $e');
      return null;
    }
  }

  static String _errorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'requires-recent-login':
        return 'Please log out and log back in, then try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
