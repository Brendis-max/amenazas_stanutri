import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print("→ Intentando conectar con Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("→ Firebase inicializado OK ✅");

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    print("→ Error crítico al inicializar Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "StarNutri",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).copyWith(
          bodyLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          bodyMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3142),
          ),
          titleMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3142),
          ),
          labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
