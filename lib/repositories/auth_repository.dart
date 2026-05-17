import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Udostępnienie instancji repozytorium w drzewie providerów Riverpod
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

// Nasłuchiwanie zmian stanu uwierzytelnienia jako reaktywny strumień
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Licznik wymuszający przebudowanie _AuthGate po potwierdzeniu e-maila —
// konieczny, bo authStateChanges() nie emituje przy samej zmianie emailVerified
final emailVerifiedRefreshProvider = StateProvider<int>((ref) => 0);

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Logowanie e-mail
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Rejestracja użytkownika i natychmiastowy zapis profilu w Firestore —
  // oba kroki wykonywane sekwencyjnie, aby zapewnić spójność danych
  Future<void> signUpWithEmail(
      String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      print('[AuthRepo] signUpWithEmail: user is null after createUser');
      return;
    }

    await user.updateDisplayName(displayName);

    // Wysyłka maila weryfikacyjnego na tej konkretnej instancji User —
    // pewniejsze niż _auth.currentUser, bo bez ryzyka race condition.
    // Wyjątki rzucane przez sendEmailVerification są tu jawnie logowane —
    // ciche połknięcie błędu wcześniej uniemożliwiało diagnozę problemów
    // z dostarczaniem maili.
    try {
      print('[AuthRepo] Calling sendEmailVerification for ${user.email}');
      await user.sendEmailVerification();
      print('[AuthRepo] sendEmailVerification completed without exception');
    } catch (e, st) {
      print('[AuthRepo] sendEmailVerification FAILED: ${e.runtimeType}: $e');
      print('$st');
      rethrow;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': displayName,
      'email': email,
      'level': 'recreational',
      'positions': <String>[],
      'createdAt': Timestamp.now(),
    });
  }

  // Logowanie przez Google OAuth2 i tworzenie profilu przy pierwszym logowaniu —
  // sprawdzenie istnienia dokumentu, by nie nadpisywać istniejących danych
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

      // Wymiana tokenu Google na credential Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) return;

      // Tworzenie dokumentu tylko przy pierwszym logowaniu
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

  // Wysłanie e-maila z linkiem weryfikacyjnym do aktualnie zalogowanego użytkownika
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // Odświeżenie danych użytkownika z serwera — konieczne by sprawdzić aktualny status weryfikacji
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // Wylogowanie z Firebase i Google — oba serwisy rozłączane niezależnie
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}