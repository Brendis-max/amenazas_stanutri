import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get userStatus => _auth.authStateChanges();

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential res = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return res.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Error al iniciar sesión";
    }
  }

  Future<User?> registerWithEmail(String email, String password) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return res.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Error al registrarse";
    }
  }

  Future<User?> loginGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // ✅ En Android usa serverClientId (el ID web de OAuth)
        serverClientId: "452503015485-fhbcaqqt4rchha7j5ps61q63sri98df4.apps.googleusercontent.com",
      );

      // ✅ Esto fuerza que siempre aparezca el selector de cuentas
      await googleSignIn.signOut();

      final GoogleSignInAccount? gUser = await googleSignIn.signIn();
      if (gUser == null) return null;

      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      UserCredential res = await _auth.signInWithCredential(credential);
      return res.user;
    } catch (e) {
      print("Error Google: $e");
      return null;
    }
  }

  // ✅ Nuevo método de cerrar sesión completo
  Future<void> signOut() async {
    await GoogleSignIn().signOut(); // limpia la sesión de Google también
    await _auth.signOut();
  }
}