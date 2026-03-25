import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_profile_page.dart';
import 'home_tabs.dart';
import 'kids_home_page.dart';

class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({super.key});

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage>
    with TickerProviderStateMixin {

  // ─── Animaciones ──────────────────────────────────────────────────────────
  AnimationController? _bgController;
  AnimationController? _floatController;
  bool _initialized = false;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF118AB2),
    Color(0xFFFFB347), Color(0xFFC77DFF), Color(0xFF80ED99),
    Color(0xFFF4A261), Color(0xFF2EC4B6), Color(0xFFE76F51),
  ];

  List<_Dot> _dotData = [];
  final user = FirebaseAuth.instance.currentUser;

  void _initAnimations() {
    if (_initialized) return;
    _initialized = true;

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    final rnd = Random();
    _dotData = List.generate(45, (i) {
      final r = Random(i * 17 + 5);
      return _Dot(
        color:   _dotColors[r.nextInt(_dotColors.length)],
        xFactor: r.nextDouble(),
        yFactor: r.nextDouble(),
        size:    3 + r.nextDouble() * 5,
        phase:   rnd.nextDouble() * 2 * pi,
        opacity: 0.4 + r.nextDouble() * 0.45,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void dispose() {
    _bgController?.dispose();
    _floatController?.dispose();
    super.dispose();
  }

  // ─── PIN HANDLERS ─────────────────────────────────────────────────────────
  void _handleParentAccess(BuildContext context, String? savedPin, bool pinEnabled) {
    debugPrint("--- Intento de acceso a Perfil Padre ---");
    if (!pinEnabled) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeTabs()));
      return;
    }
    if (savedPin == null || savedPin.isEmpty) {
      _showCreatePinDialog(context);
    } else {
      _showLoginPinDialog(context, savedPin);
    }
  }

  void _showCreatePinDialog(BuildContext context) {
    String newPin = "";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Configura tu PIN de Padre", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Este código protegerá tu acceso a los ajustes."),
            const SizedBox(height: 20),
            TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              decoration: const InputDecoration(hintText: "****", border: OutlineInputBorder()),
              onChanged: (value) => newPin = value.trim(),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final numericPin = RegExp(r'^[0-9]{4}$');
              if (!numericPin.hasMatch(newPin)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("El PIN debe ser de 4 números."))
                );
                return;
              }
              if (user != null) {
                try {
                  await FirebaseFirestore.instance
                      .collection('users').doc(user!.uid)
                      .set({'parentPin': newPin, 'pinEnabled': true}, SetOptions(merge: true));
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => HomeTabs()));
                } catch (e) {
                  debugPrint("Error: $e");
                }
              }
            },
            child: const Text("Guardar PIN"),
          ),
        ],
      ),
    );
  }

  void _showLoginPinDialog(BuildContext context, String savedPin) {
    String inputPin = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Perfil Protegido", textAlign: TextAlign.center),
        content: TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 10),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (value) => inputPin = value.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (inputPin == savedPin) {
                Navigator.pop(context);
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => HomeTabs()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("PIN Incorrecto"),
                      backgroundColor: Colors.redAccent)
                );
              }
            },
            child: const Text("Entrar"),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        _buildBackground(),
        _buildDots(size),
        _buildBody(context),
      ]),
    );
  }

  Widget _buildBackground() {
    _initAnimations();
    return AnimatedBuilder(
      animation: _bgController!,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFFD4F4DD), Color(0xFFFFF9E6),
              Color(0xFFFFD7A5), Color(0xFFE0F2E9),
            ],
            transform: GradientRotation(_bgController!.value * 2 * pi),
          ),
        ),
      ),
    );
  }

  Widget _buildDots(Size size) {
    if (_floatController == null || _dotData.isEmpty) return const SizedBox();
    return AnimatedBuilder(
      animation: _floatController!,
      builder: (_, __) => Stack(
        children: _dotData.map((d) {
          final dy = sin(_floatController!.value * 2 * pi + d.phase) * 10;
          return Positioned(
            left: d.xFactor * size.width,
            top:  d.yFactor * size.height + dy,
            child: Opacity(
              opacity: d.opacity,
              child: Container(
                width: d.size, height: d.size,
                decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user?.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return const Center(child: Text("Ocurrió un error al cargar datos"));
        }
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var userData   = userSnapshot.data!.data() as Map<String, dynamic>?;
        String? savedPin   = userData?['parentPin'];
        bool    pinEnabled = userData?['pinEnabled'] ?? false;

        // ✅ Si pinEnabled es false O el pin está vacío → sin candado
        // Si pinEnabled es true Y hay pin → candado cerrado
        final bool hasPinActive = pinEnabled && (savedPin != null && savedPin.isNotEmpty);
        String parentName = userData?['parentName'] ?? "Papá / Mamá";

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          Image.asset(
                            'assets/splash.png',
                            height: 90,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported, size: 80, color: Colors.white54),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'SELECCIONA TU PERFIL',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                              color: const Color(0xFF50288C).withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '¿Quién eres hoy? 👋',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                color: Color(0xFF1A0A36)),
                          ),
                          const SizedBox(height: 22),

                          // ── Perfil Padre con candado dinámico ─────────────
                          _profileItem(
                            label: parentName,
                            color: const Color(0xFFFFE577).withOpacity(0.75),
                            // ✅ Candado cerrado si hay PIN activo, abierto si no
                            icon: hasPinActive ? Icons.lock_rounded : Icons.lock_open_rounded,
                            iconColor: hasPinActive
                                ? const Color(0xFF7C3AED)
                                : Colors.black45,
                            onTap: () => _handleParentAccess(context, savedPin, pinEnabled),
                          ),

                          const SizedBox(height: 12),

                          // ── Perfiles Hijos ─────────────────────────────────
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users').doc(user?.uid)
                                .collection('children')
                                .orderBy('createdAt', descending: true).snapshots(),
                            builder: (context, kidsSnapshot) {
                              if (!kidsSnapshot.hasData) return const SizedBox();
                              final kids = kidsSnapshot.data!.docs;
                              return Column(
                                children: kids.map((kidDoc) {
                                  var kidData = kidDoc.data() as Map<String, dynamic>;
                                  String name = kidData['name'] ?? "Niño";
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _profileItem(
                                      label: name,
                                      color: const Color(0xFFB4F8C8).withOpacity(0.75),
                                      icon: Icons.face,
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => KidsHomePage(kidName: name)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),

                          // ── Agregar perfil ─────────────────────────────────
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const AddProfilePage())),
                            child: Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.55), width: 1.2),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline,
                                      color: const Color(0xFF3C2864).withOpacity(0.55), size: 20),
                                  const SizedBox(width: 8),
                                  Text('Agregar otro perfil',
                                      style: TextStyle(
                                          color: const Color(0xFF3C2864).withOpacity(0.60),
                                          fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ Acepta iconColor opcional para colorear el candado
  Widget _profileItem({
    required String   label,
    required Color    color,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.5),
            child: const Icon(Icons.person, color: Colors.black54),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: Color(0xFF1A0A36))),
          ),
          Icon(icon, size: 20, color: iconColor ?? Colors.black45),
        ]),
      ),
    );
  }
}

class _Dot {
  final Color  color;
  final double xFactor, yFactor, size, phase, opacity;
  const _Dot({required this.color, required this.xFactor, required this.yFactor,
      required this.size, required this.phase, required this.opacity});
}
