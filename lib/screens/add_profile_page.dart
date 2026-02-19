import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// --- CLASE DE SEGURIDAD (Punto 1: Prevención de Inyección) ---
class SecurityUtils {
  static String sanitizeText(String input) {
    print(" [SEGURIDAD] Iniciando sanitización de: '$input'");

    // 1. Eliminar espacios extra
    String sanitized = input.trim();

    // 2. Eliminar caracteres peligrosos para NoSQL Injection
    String finalResult = sanitized.replaceAll(RegExp(r'[<>{}\[\]\\|^`"~]'), '');

    if (input != finalResult) {
      print(
        "⚠️ [SEGURIDAD] Caracteres peligrosos eliminados. Resultado: '$finalResult'",
      );
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
  final _ageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _saveChildProfile() async {
    // Validación del formulario antes de procesar
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      // --- IMPLEMENTACIÓN DE SEGURIDAD: SANITIZACIÓN ---
      // Aplicamos la limpieza antes de que el dato toque la base de datos
      final String nombreLimpio = SecurityUtils.sanitizeText(
        _nameController.text,
      );
      final int edadLimpia = int.parse(_ageController.text);

      // Verificación de longitud extra por seguridad (Punto 1 del documento)
      if (nombreLimpio.length >= 3 && nombreLimpio.length <= 20) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('children')
            .add({
              'name': nombreLimpio,
              'age': edadLimpia,
              'createdAt': FieldValue.serverTimestamp(),
              'rol': 'Niño', // Control de acceso por roles
            });

        // Verificamos que el widget siga activo para evitar errores de consola
        if (!mounted) return;

        Navigator.pop(context); // Regresa a la pantalla de selección
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Perfil de niño agregado!")),
        );
      } else {
        throw "El nombre debe tener entre 3 y 20 caracteres.";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF6A3), Color(0xFFFFD194)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Nuevo Perfil",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // CAMPO NOMBRE CON VALIDACIÓN
                      TextFormField(
                        controller: _nameController,
                        maxLength: 20,
                        // --- SEGURIDAD: Bloquea caracteres especiales mientras el usuario escribe ---
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ ]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: "Nombre del niño/a",
                          border: OutlineInputBorder(),
                          counterText: "",
                          
                        ),
                        validator: (v) {
                          print(
                            " [VALIDACIÓN] Verificando caracteres de: '$v'",
                          );

                          if (v == null || v.trim().isEmpty) {
                            print(" [VALIDACIÓN] Error: Campo vacío.");
                            return "Escribe un nombre";
                          }

                          // --- SEGURIDAD: Validar mediante RegExp que no haya símbolos ---
                          final nameRegExp = RegExp(
                            r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$',
                          );
                          if (!nameRegExp.hasMatch(v)) {
                            print(
                              " [VALIDACIÓN] Error: Se detectaron símbolos prohibidos.",
                            );
                            return "Solo se permiten letras (sin signos)";
                          }

                          if (v.trim().length < 3) {
                            print(" [VALIDACIÓN] Error: Nombre muy corto.");
                            return "Nombre demasiado corto";
                          }

                          print(
                            "[VALIDACIÓN] Caracteres permitidos confirmados.",
                          );
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // CAMPO EDAD CON VALIDACIÓN
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: "Edad",
                          border: OutlineInputBorder(),
                          counterText: "",
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Escribe la edad";
                          final n = int.tryParse(v);
                          if (n == null || n <= 0) return "Edad no válida";
                          if (n > 10) return "Perfil solo para menores";
                          return null;
                        },
                      ),
                      const SizedBox(height: 25),

                      // BOTÓN DE ACCIÓN
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6F991),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _saveChildProfile,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black87,
                                  ),
                                )
                              : const Text(
                                  "Guardar Perfil",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
