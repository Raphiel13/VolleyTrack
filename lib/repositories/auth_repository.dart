import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmail(
      String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) return;

    await user.updateDisplayName(displayName);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': displayName,
      'email': email,
      'level': 'recreational',
      'positions': <String>[],
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      print('Starting Google Sign In');
      final googleUser = await GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId:
            '239125281431-m0nmnroi0685u1me1rd6k7686bpuvv08.apps.googleusercontent.com',
      ).signIn();
      print('Google user: ${googleUser?.email}');
      if (googleUser == null) {
        print('GoogleSignIn: user cancelled or null');
        return;
      }

      print('Getting credentials');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) return;

      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await docRef.get();
      if (!snap.exists) {
        await docRef.set({
          'name': user.displayName ?? 'Gracz',
          'email': user.email ?? '',
          'level': 'recreational',
          'positions': <String>[],
          'createdAt': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Error type: ${e.runtimeType}, message: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
