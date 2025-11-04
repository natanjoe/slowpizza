import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> loginAdmin(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      // Verifica claims do admin
      IdTokenResult tokenResult = await user!.getIdTokenResult();
      if (tokenResult.claims != null && tokenResult.claims!['role'] == 'admin') {
        return user;
      } else {
        await _auth.signOut();
        return null;
      }
    } catch (e) {
      print("Erro no login: $e");
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
