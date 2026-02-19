import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
   // Este es el "oído" que detecta si el token es válido o si expiró
    Stream<User?> get userStatus => _auth.authStateChanges();
  // Iniciar sesión con Email y Contraseña
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential res = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return res.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Error al iniciar sesión";
    }
  }

  // Registrar nuevo usuario
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return res.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Error al registrarse";
    }
  }

  // Google Sign In (Funciona en Android y Web con tu Client ID)
  // En lib/services/auth_service.dart

Future<User?> loginGoogle() async {
  try {
    // Agregamos el clientId directamente aquí para evitar el error de "Assertion failed"
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: "452503015485-fhbcaqqt4rchha7j5ps61q63sri98df4.apps.googleusercontent.com",
    );

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
}