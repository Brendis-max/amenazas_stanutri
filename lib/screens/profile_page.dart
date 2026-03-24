import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starnutri/screens/profile_selection_page.dart';
import 'login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  // ─── Paleta ───────────────────────────────────────────────────────────────
  static const Color _dark   = Color(0xFF1A0A36);
  static const Color _mid    = Color(0xFF50288C);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _pink   = Color(0xFFFF6BA1);
  static const Color _blue   = Color(0xFF5DCCFF);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _green  = Color(0xFF4ECB71);
  static const Color _yellow = Color(0xFFFFD166);

  // ─── Animaciones ──────────────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _floatCtrl;
  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
  ];
  late final List<_Dot> _dots;

  // ─── Estado ───────────────────────────────────────────────────────────────
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pinCtrl  = TextEditingController();
  bool _isPinEnabled = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    final rnd = Random();
    _dots = List.generate(22, (i) {
      final r = Random(i * 17 + 3);
      return _Dot(color: _dotColors[r.nextInt(_dotColors.length)], x: r.nextDouble(), y: r.nextDouble(),
          size: 3 + r.nextDouble() * 5, phase: rnd.nextDouble() * 2 * pi, opacity: 0.18 + r.nextDouble() * 0.28);
    });
    _nameCtrl.text = user?.displayName ?? user?.email?.split('@')[0].toUpperCase() ?? 'PADRE/MAMÁ';
    _loadSettings();
  }

  @override
  void dispose() { _bgCtrl.dispose(); _floatCtrl.dispose(); _nameCtrl.dispose(); _pinCtrl.dispose(); super.dispose(); }

  Future<void> _loadSettings() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _isPinEnabled = doc.data()?['pinEnabled'] ?? false;
        _pinCtrl.text = doc.data()?['parentPin']  ?? '';
      });
    }
  }

  void _showAddChildDialog() {
    final nameCtrl = TextEditingController();
    final ageCtrl  = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Agregar hijo/a', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _dark)),
                const SizedBox(height: 20),
                _dialogField(nameCtrl, 'Nombre del niño/a', Icons.child_care_rounded),
                const SizedBox(height: 14),
                _dialogField(ageCtrl, 'Edad', Icons.cake_rounded, isNumber: true),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: _dark.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700, color: _dark)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.isNotEmpty && ageCtrl.text.isNotEmpty) {
                        await FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('children').add({
                          'name': nameCtrl.text.trim(),
                          'age':  int.tryParse(ageCtrl.text.trim()) ?? 0,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w800)),
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _dark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _dark.withOpacity(0.35), fontSize: 14),
          prefixIcon: Icon(icon, color: _purple.withOpacity(0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        _buildBg(),
        _buildDots(size),
        SafeArea(child: Column(children: [
          _buildAppBar(),
          Expanded(child: _buildContent()),
        ])),
      ]),
    );
  }

  Widget _buildBg() => AnimatedBuilder(
    animation: _bgCtrl,
    builder: (_, __) => Container(decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: const [Color(0xFFD4F4DD), Color(0xFFFFF9E6), Color(0xFFFFD7A5), Color(0xFFE0F2E9)],
      transform: GradientRotation(_bgCtrl.value * 2 * pi),
    ))),
  );

  Widget _buildDots(Size size) => AnimatedBuilder(
    animation: _floatCtrl,
    builder: (_, __) => Stack(children: _dots.map((d) {
      final dy = sin(_floatCtrl.value * 2 * pi + d.phase) * 10;
      return Positioned(left: d.x * size.width, top: d.y * size.height + dy,
        child: Opacity(opacity: d.opacity, child: Container(width: d.size, height: d.size,
            decoration: BoxDecoration(color: d.color, shape: BoxShape.circle))));
    }).toList()),
  );

  Widget _buildAppBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.4))),
          ),
          child: Row(children: [
            Expanded(child: const Text('Mi Perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _dark))),
            _glassButton(Icons.logout_rounded, _pink, () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Tarjeta de perfil ─────────────────────────────────────────────
        _glass(radius: 28, child: Column(children: [
          Row(children: [
            // Avatar
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _yellow, width: 3),
                boxShadow: [BoxShadow(color: _yellow.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ClipOval(child: Image.asset('assets/splash.png', fit: BoxFit.cover)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Nombre editable
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.35), borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'Tu nombre',
                    hintStyle: TextStyle(color: _dark.withOpacity(0.35)),
                    suffixIcon: Icon(Icons.edit_rounded, size: 16, color: _dark.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Perfil de Administrador', style: TextStyle(fontSize: 13, color: _dark.withOpacity(0.55), fontWeight: FontWeight.w500)),
            ])),
          ]),
          const SizedBox(height: 16),
          // Badge de nivel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _yellow.withOpacity(0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _yellow.withOpacity(0.40)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.star_rounded, color: _yellow, size: 20),
              const SizedBox(width: 8),
              const Text('Nivel de Nutrición — Excelente progreso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _dark)),
            ]),
          ),
        ])),

        const SizedBox(height: 24),

        // ── Mis hijos ─────────────────────────────────────────────────────
        Row(children: [
          const Expanded(child: Text('Mis hijos', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _dark))),
          GestureDetector(
            onTap: _showAddChildDialog,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _orange.withOpacity(0.18), shape: BoxShape.circle, border: Border.all(color: _orange.withOpacity(0.40))),
              child: const Icon(Icons.add_rounded, color: _orange, size: 22),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('children').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_purple)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _glass(child: Column(children: [
                Icon(Icons.child_care_rounded, size: 40, color: _purple.withOpacity(0.4)),
                const SizedBox(height: 10),
                Text('Agrega tu primer hijo', style: TextStyle(fontSize: 15, color: _dark.withOpacity(0.55), fontWeight: FontWeight.w600)),
              ]));
            }
            final kids = snapshot.data!.docs;
            final cardColors = [_orange, _blue, _purple, _pink, _green];
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.05),
              itemCount: kids.length,
              itemBuilder: (context, i) {
                final kid = kids[i].data() as Map<String, dynamic>;
                final Color c = cardColors[i % cardColors.length];
                return _kidCard(docId: kids[i].id, name: kid['name'] ?? 'Sin nombre', age: (kid['age'] ?? 0).toString(), color: c);
              },
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Seguridad ─────────────────────────────────────────────────────
        const Text('Seguridad Parental', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _dark)),
        const SizedBox(height: 14),
        _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PIN de seguridad', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
              Text('Protege el acceso a la configuración', style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.50))),
            ])),
            Switch(
              value: _isPinEnabled,
              activeColor: _purple,
              onChanged: (v) => setState(() => _isPinEnabled = v),
            ),
          ]),
          if (_isPinEnabled) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.40), borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _dark),
                decoration: InputDecoration(
                  hintText: 'Nuevo PIN (4 dígitos)',
                  hintStyle: TextStyle(color: _dark.withOpacity(0.35)),
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: _purple.withOpacity(0.6), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  counterText: '',
                ),
              ),
            ),
          ],
        ])),

        const SizedBox(height: 24),

        // ── Botones ───────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
                'parentName': _nameCtrl.text.trim(),
                'pinEnabled': _isPinEnabled,
                'parentPin':  _isPinEnabled ? _pinCtrl.text.trim() : '',
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Configuración guardada'),
                  backgroundColor: _green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  margin: const EdgeInsets.all(16),
                ));
              }
            },
            child: const Text('GUARDAR CAMBIOS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSelectionPage())),
            icon: Icon(Icons.people_outline_rounded, color: _mid),
            label: Text('Ver perfiles', style: TextStyle(color: _mid, fontWeight: FontWeight.w800, fontSize: 15)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _mid.withOpacity(0.40), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _kidCard({required String docId, required String name, required String age, required Color color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.35), width: 1.2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('children').doc(docId).delete(),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.35), shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 14, color: color),
                ),
              ),
            ),
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: color.withOpacity(0.20), shape: BoxShape.circle),
              child: Icon(Icons.child_care_rounded, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _dark), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('$age años', style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.55), fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  Widget _glass({required Widget child, double radius = 22}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.30)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _Dot {
  final Color color; final double x, y, size, phase, opacity;
  const _Dot({required this.color, required this.x, required this.y, required this.size, required this.phase, required this.opacity});
}
