import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final auth = AuthService();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;

  // --- SEGURIDAD: PREVENCIÓN DE INYECCIÓN (Paso 1) ---
  String sanitizeInput(String input) {
    // Limpiamos espacios y caracteres que podrían usarse en ataques NoSQL
    return input.trim().replaceAll(RegExp(r'[<>{}\[\]\\|^`"~]'), '');
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
              // IMAGEN DE CABECERA
              SizedBox(
                width: double.infinity,
                height: 300,
                child: Image.asset(
                  'assets/splash.png', 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.person_add, size: 100, color: Colors.grey),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Column(
                  children: [
                    const Text(
                      "Crea tu cuenta", 
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Regístrate para gestionar los perfiles",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 25),

                    // CAMPO EMAIL
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: "Email", 
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      validator: (v) => (v != null && v.contains('@')) ? null : "Email inválido",
                    ),
                    const SizedBox(height: 15),

                    // CAMPO PASSWORD
                    TextFormField(
                      controller: passController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Contraseña (min. 6)", 
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      validator: (v) => (v != null && v.length < 6) ? "Demasiado corta" : null,
                    ),
                    
                    const SizedBox(height: 30),

                    // BOTÓN REGISTRARSE
                    SizedBox(
                      width: double.infinity, 
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                        ),
                        onPressed: isLoading ? null : _handleRegister,
                        child: isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text(
                              "Registrarse", 
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)
                            ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // BOTÓN PARA REGRESAR AL LOGIN
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "¿Ya tienes cuenta? Inicia sesión",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LÓGICA DE REGISTRO CON SEGURIDAD ---
  Future<void> _handleRegister() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    
    // Evidencia para consola
    print("🚀 [SISTEMA] Iniciando proceso de registro seguro...");

    try {
      final String cleanEmail = sanitizeInput(emailController.text);
      final String password = passController.text;

      print("🛡️ [SEGURIDAD] Email sanitizado: $cleanEmail");

      await auth.registerWithEmail(cleanEmail, password);
      
      print("✅ [AUTH] Usuario creado exitosamente en Firebase.");

      if (!mounted) return;

      // Al usar AuthWrapper, al registrarse Firebase loguea al usuario automáticamente.
      // Solo cerramos esta pantalla y el Wrapper nos llevará a la página de perfiles.
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cuenta creada con éxito"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print("🚨 [ERROR] Fallo en el registro: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}