import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// --- CLASE DE SEGURIDAD (Punto 1: Prevención de Inyección) ---
class SecurityUtils {
  static String sanitizeText(String input) {
    print(" [SEGURIDAD] Iniciando sanitización de: '$input'");

    String sanitized = input.trim();
    String finalResult = sanitized.replaceAll(RegExp(r'[<>{}\[\]\\|^`"~]'), '');

    if (input != finalResult) {
      print("⚠️ [SEGURIDAD] Caracteres peligrosos eliminados. Resultado: '$finalResult'");
    } else {
      print(" [SEGURIDAD] Input limpio, no se detectaron amenazas.");
    }

    return finalResult;
  }
}

class AddProfilePage extends StatefulWidget {
  const AddProfilePage({super.key});

  @override
  State<AddProfilePage> createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  final _nameController = TextEditingController();
  final _ageController  = TextEditingController();
  final _formKey        = GlobalKey<FormState>();
  bool _isLoading       = false;

  Future<void> _saveChildProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final String nombreLimpio = SecurityUtils.sanitizeText(_nameController.text);
      final int    edadLimpia   = int.parse(_ageController.text);

      if (nombreLimpio.length >= 3 && nombreLimpio.length <= 20) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('children')
            .add({
              'name':      nombreLimpio,
              'age':       edadLimpia,
              'createdAt': FieldValue.serverTimestamp(),
              'rol':       'Niño',
            });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Perfil de niño agregado!")),
        );
      } else {
        throw "El nombre debe tener entre 3 y 20 caracteres.";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFD4F4DD),
              Color(0xFFFFF9E6),
              Color(0xFFFFD7A5),
              Color(0xFFE0F2E9),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Imagen superior ─────────────────────────────────────────
                Image.asset(
                  'assets/splash.png',
                  height: 130,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),

                // ── Card con efecto blur ─────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.60),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            // Título
                            const Text(
                              "Nuevo Perfil",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A0A36),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Agrega al niño o niña",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1A0A36).withOpacity(0.50),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Campo Nombre ──────────────────────────────────
                            _glassField(
                              controller: _nameController,
                              label: "Nombre del niño/a",
                              icon: Icons.child_care_rounded,
                              maxLength: 20,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ ]'),
                                ),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return "Escribe un nombre";
                                final nameRegExp = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$');
                                if (!nameRegExp.hasMatch(v)) return "Solo se permiten letras (sin signos)";
                                if (v.trim().length < 3) return "Nombre demasiado corto";
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // ── Campo Edad ────────────────────────────────────
                            _glassField(
                              controller: _ageController,
                              label: "Edad",
                              icon: Icons.cake_rounded,
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Escribe la edad";
                                final n = int.tryParse(v);
                                if (n == null || n <= 0) return "Edad no válida";
                                if (n > 10) return "Perfil solo para menores";
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // ── Botón Guardar ─────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A0A36),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _saveChildProfile,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Guardar Perfil",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // ── Cancelar ──────────────────────────────────────
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "Cancelar",
                                style: TextStyle(
                                  color: const Color(0xFF1A0A36).withOpacity(0.45),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Campo de texto con estilo glass ────────────────────────────────────────
  Widget _glassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(
            color: Color(0xFF1A0A36),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: const Color(0xFF1A0A36).withOpacity(0.55),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon,
                color: const Color(0xFF7C3AED).withOpacity(0.70), size: 20),
            counterText: "",
            filled: true,
            fillColor: Colors.white.withOpacity(0.30),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.60), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFF7C3AED), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFFFF6BA1), width: 1.4),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFFFF6BA1), width: 1.8),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 15),
          ),
        ),
      ),
    );
  }
}
