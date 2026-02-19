import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart'; // Asegúrate de que la ruta sea correcta
import '../screens/profile_selection_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // --- PASO 2: MONITOREO DEL ESTADO DE AUTENTICACIÓN ---
    // El StreamBuilder escucha a Firebase en tiempo real.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Si ya hay datos (usuario logueado)
        if (snapshot.hasData && snapshot.data != null) {
          return const ProfileSelectionPage();
        }

        // Si no hay datos (usuario no logueado)
        if (snapshot.connectionState == ConnectionState.active &&
            !snapshot.hasData) {
          return LoginScreen();
        }

        // Por defecto, mientras carga
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
