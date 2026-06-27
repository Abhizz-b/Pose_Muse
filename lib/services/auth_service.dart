import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

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

  /// Reauthenticate + change password
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
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      debugPrint('changePassword failed: $e');
      return 'Could not update password. Try again.';
    }
  }

  /// Profile photo upload — Firebase Storage nahi hai,
  /// isliye image ko base64 mein convert karke Firestore mein save karte hain.
  /// Returns base64 string on success, null on failure.
  static Future<String?> uploadProfilePhoto(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      // File bytes padhte hain
      final bytes = await file.readAsBytes();

      // 300 KB se bada hai to reject karo (Firestore doc limit ~1MB)
      if (bytes.lengthInBytes > 300 * 1024) {
        debugPrint('uploadProfilePhoto: file too large (${bytes.lengthInBytes} bytes)');
        return null;
      }

      final base64Str = base64Encode(bytes);

      // Firestore mein save karo
      await FirestoreService.saveProfilePhoto(base64Str);

      return base64Str; // caller ko base64 dete hain taaki UI update ho sake
    } catch (e) {
      debugPrint('uploadProfilePhoto failed: $e');
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
