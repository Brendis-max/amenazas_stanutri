import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'profile_selection_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService auth = AuthService();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;

  // ----------- SEGURIDAD BÁSICA -----------
  String sanitizeInput(String input) {
    return input.trim().replaceAll(RegExp(r'[<>{}\[\]\\|^`"~]'), '');
  }
  
  bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  // ----------- NAVEGACIÓN DIRECTA -----------
  void goSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            children: [
              // IMAGEN
              SizedBox(
                width: double.infinity,
                height: 300,
                child: Image.asset(
                  'assets/splash.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.image, size: 100, color: Colors.grey),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Bienvenido",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // EMAIL
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: "Email",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Campo obligatorio";
                        if (!isValidEmail(v)) return "Email inválido";
                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // PASSWORD
                    TextFormField(
                      controller: passController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Contraseña",
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Campo obligatorio";
                        if (v.length < 6) return "Mínimo 6 caracteres";
                        return null;
                      },
                    ),

                    const SizedBox(height: 25),

                    // BOTÓN LOGIN
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                setState(() => isLoading = true);
                                print("🚀 [AUTH] Intentando login...");

                                try {
                                  await auth.loginWithEmail(
                                    sanitizeInput(emailController.text),
                                    passController.text,
                                  );
                                  print("✅ [AUTH SUCCESS] Cambiando de pantalla...");
                                  if (mounted) goSelection();
                                } on FirebaseAuthException catch (e) {
                                  print("❌ Error Firebase: ${e.code}");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: ${e.message}")),
                                  );
                                } catch (e) {
                                  print("🚨 Error: $e");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Datos incorrectos")),
                                  );
                                } finally {
                                  if (mounted) setState(() => isLoading = false);
                                }
                              },
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Continue",
                                style: TextStyle(color: Colors.white, fontSize: 17),
                              ),
                      ),
                    ),

                    // REGISTRO
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text(
                        "¿No tienes cuenta? Regístrate aquí",
                        style: TextStyle(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    const Text("or", style: TextStyle(color: Colors.black38)),
                    const SizedBox(height: 15),

                    // GOOGLE
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 218, 218, 218),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await auth.loginGoogle();
                            if (mounted) goSelection();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Error con Google")),
                            );
                          }
                        },
                        icon: const Icon(Icons.g_mobiledata, color: Colors.black, size: 40),
                        label: const Text(
                          "Continue with Google",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}