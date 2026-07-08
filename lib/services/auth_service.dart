import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // ✅ para kIsWeb
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get userStatus => _auth.authStateChanges();

  // ─── LOGIN CON EMAIL ────────────────────────────────────────────────────
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential res = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // ✅ Ver token JWT del usuario
      final token = await res.user?.getIdToken();
      print('🔑 [EMAIL LOGIN] ID Token:');
      print(token);

      // ✅ Ver información decodificada del token
      final tokenResult = await res.user?.getIdTokenResult();
      print('📋 [EMAIL LOGIN] Token Info:');
      print('   UID:        ${res.user?.uid}');
      print('   Email:      ${res.user?.email}');
      print('   Expira:     ${tokenResult?.expirationTime}');
      print('   Emitido:    ${tokenResult?.issuedAtTime}');
      print('   Proveedor:  ${tokenResult?.signInProvider}');

      return res.user;
    } on FirebaseAuthException catch (e) {
      print('❌ [EMAIL LOGIN] Error: ${e.code} - ${e.message}');
      throw e.message ?? "Error al iniciar sesión";
    }
  }

  // ─── REGISTRO CON EMAIL ─────────────────────────────────────────────────
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // ✅ Ver token del usuario recién registrado
      final token = await res.user?.getIdToken();
      print('🔑 [REGISTER] ID Token:');
      print(token);

      print('📋 [REGISTER] Usuario creado:');
      print('   UID:   ${res.user?.uid}');
      print('   Email: ${res.user?.email}');

      return res.user;
    } on FirebaseAuthException catch (e) {
      print('❌ [REGISTER] Error: ${e.code} - ${e.message}');
      throw e.message ?? "Error al registrarse";
    }
  }

  // ─── LOGIN CON GOOGLE ───────────────────────────────────────────────────
  Future<User?> loginGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // ✅ serverClientId no es soportado en Web, solo en Android/iOS
        serverClientId: kIsWeb
            ? null
            : "452503015485-fhbcaqqt4rchha7j5ps61q63sri98df4.apps.googleusercontent.com",
      );

      await googleSignIn.signOut();

      final GoogleSignInAccount? gUser = await googleSignIn.signIn();
      if (gUser == null) {
        print('⚠️ [GOOGLE] Usuario canceló el login');
        return null;
      }

      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // ✅ Tokens de Google
      print('🔑 [GOOGLE] Access Token:');
      print(gAuth.accessToken);
      print('🔑 [GOOGLE] ID Token (JWT):');
      print(gAuth.idToken);

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      UserCredential res = await _auth.signInWithCredential(credential);

      // ✅ Token de Firebase (diferente al de Google)
      final firebaseToken = await res.user?.getIdToken();
      print('🔑 [GOOGLE→FIREBASE] Firebase ID Token:');
      print(firebaseToken);

      // ✅ Info completa del token Firebase
      final tokenResult = await res.user?.getIdTokenResult();
      print('📋 [GOOGLE→FIREBASE] Token Info:');
      print('   UID:        ${res.user?.uid}');
      print('   Email:      ${res.user?.email}');
      print('   Nombre:     ${res.user?.displayName}');
      print('   Foto:       ${res.user?.photoURL}');
      print('   Expira:     ${tokenResult?.expirationTime}');
      print('   Proveedor:  ${tokenResult?.signInProvider}');

      return res.user;
    } catch (e) {
      print('❌ [GOOGLE] Error: $e');
      return null;
    }
  }

  // ─── OBTENER TOKEN DEL USUARIO ACTUAL ──────────────────────────────────
  /// Llama este método desde cualquier parte de la app para
  /// obtener el token fresco del usuario que está logueado.
  Future<String?> getCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️ No hay usuario logueado');
      return null;
    }

    // forceRefresh: true → obtiene token nuevo aunque el anterior sea válido
    final token = await user.getIdToken(true);
    print('🔑 [CURRENT USER] Token actualizado:');
    print(token);
    return token;
  }

  // ─── CERRAR SESIÓN ──────────────────────────────────────────────────────
  Future<void> signOut() async {
    print('👋 Cerrando sesión de: ${_auth.currentUser?.email}');
    await GoogleSignIn().signOut();
    await _auth.signOut();
    print('✅ Sesión cerrada correctamente');
  }
}
