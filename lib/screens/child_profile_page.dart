import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pantalla que captura y guarda los datos extra del niño:
/// sexo, peso, nivel de actividad y alergias.
/// Se abre automáticamente si faltan datos, o manualmente para actualizar.
class ChildProfilePage extends StatefulWidget {
  final String childId;
  final String childName;
  final bool   isUpdate; // true = mostrar botón "Actualizar"

  const ChildProfilePage({
    super.key,
    required this.childId,
    required this.childName,
    this.isUpdate = false,
  });

  @override
  State<ChildProfilePage> createState() => _ChildProfilePageState();
}

class _ChildProfilePageState extends State<ChildProfilePage>
    with SingleTickerProviderStateMixin {

  // ─── Paleta ───────────────────────────────────────────────────────────────
  static const Color _dark   = Color(0xFF1A0A36);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _pink   = Color(0xFFFF6BA1);
  static const Color _blue   = Color(0xFF5DCCFF);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _green  = Color(0xFF4ECB71);

  // ─── Animación ────────────────────────────────────────────────────────────
  AnimationController? _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();
    _loadExistingData();
  }

  @override
  void dispose() {
    _bgCtrl?.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ─── Estado del formulario ────────────────────────────────────────────────
  String             _sex           = 'niño';
  String             _activityLevel = 'moderado';
  final List<String> _allergies     = [];
  final _weightCtrl  = TextEditingController();
  bool   _isSaving   = false;
  bool   _isLoading  = true;

  static const _allergyOptions = [
    'Gluten', 'Lactosa', 'Mariscos', 'Nueces', 'Huevo', 'Soya', 'Ninguna',
  ];

  // ─── Cargar datos existentes ──────────────────────────────────────────────
  Future<void> _loadExistingData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) { setState(() => _isLoading = false); return; }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('children').doc(widget.childId)
          .get();

      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _sex           = d['sex']           ?? 'niño';
          _activityLevel = d['activityLevel']  ?? 'moderado';
          _weightCtrl.text = (d['weightKg'] ?? '').toString();
          final saved = List<String>.from(d['allergies'] ?? []);
          _allergies
            ..clear()
            ..addAll(saved);
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  // ─── Guardar en Firestore ─────────────────────────────────────────────────
  Future<void> _save() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('children').doc(widget.childId)
          .set({
        'sex':           _sex,
        'activityLevel': _activityLevel,
        'weightKg':      double.tryParse(_weightCtrl.text) ?? 0,
        'allergies':     _allergies,
      }, SetOptions(merge: true));

      if (!mounted) return;
      _snack(widget.isUpdate
          ? 'Perfil actualizado correctamente ✓'
          : 'Perfil guardado correctamente ✓');
      Navigator.pop(context, true); // devuelve true = datos guardados
    } catch (e) {
      _snack('Error al guardar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED))))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                          child: _buildForm(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBg() {
    if (_bgCtrl == null) return Container(color: const Color(0xFFD4F4DD));
    return AnimatedBuilder(
      animation: _bgCtrl!,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: const [Color(0xFFD4F4DD), Color(0xFFFFF9E6),
                           Color(0xFFFFD7A5), Color(0xFFE0F2E9)],
            transform: GradientRotation(_bgCtrl!.value * 2 * pi),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.4))),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _glassCircle(child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 17, color: _dark)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isUpdate ? 'Actualizar perfil' : 'Completar perfil',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _dark),
              ),
              Text(widget.childName,
                  style: TextStyle(fontSize: 13, color: _dark.withOpacity(0.55))),
            ],
          )),
        ]),
      ),
    ),
  );

  Widget _buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // Info card
      _glass(child: Row(children: [
        const Text('ℹ️', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(
          'Estos datos ayudan a la IA a generar recomendaciones '
          'nutricionales más precisas para ${widget.childName}.',
          style: TextStyle(fontSize: 13, color: _dark.withOpacity(0.65), height: 1.4),
        )),
      ])),
      const SizedBox(height: 24),

      // ── Sexo ────────────────────────────────────────────────────────────
      _sectionLabel('Sexo del niño', Icons.child_care_rounded),
      const SizedBox(height: 12),
      Row(children: [
        _sexOption('niño',  Icons.face_rounded,  _blue),
        const SizedBox(width: 12),
        _sexOption('niña',  Icons.face_2_rounded, _pink),
      ]),
      const SizedBox(height: 24),

      // ── Peso ────────────────────────────────────────────────────────────
      _sectionLabel('Peso aproximado', Icons.monitor_weight_outlined),
      const SizedBox(height: 12),
      _glass(child: TextField(
        controller: _weightCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _dark),
        decoration: InputDecoration(
          hintText: 'Ej: 28.5  (opcional)',
          hintStyle: TextStyle(color: _dark.withOpacity(0.35), fontSize: 14),
          prefixIcon: Icon(Icons.monitor_weight_outlined,
              color: _purple.withOpacity(0.6), size: 22),
          suffixText: 'kg',
          suffixStyle: TextStyle(fontSize: 14, color: _dark.withOpacity(0.45)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      )),
      const SizedBox(height: 24),

      // ── Actividad ────────────────────────────────────────────────────────
      _sectionLabel('Nivel de actividad física', Icons.directions_run_rounded),
      const SizedBox(height: 12),
      Row(children: [
        _activityOption('bajo',     'Poco\nactivo',  Icons.airline_seat_recline_normal_rounded, _orange),
        const SizedBox(width: 8),
        _activityOption('moderado', 'Moderado',      Icons.directions_walk_rounded, _green),
        const SizedBox(width: 8),
        _activityOption('alto',     'Muy\nactivo',   Icons.directions_run_rounded, _purple),
      ]),
      const SizedBox(height: 24),

      // ── Alergias ─────────────────────────────────────────────────────────
      _sectionLabel('Alergias / Intolerancias', Icons.warning_amber_rounded),
      const SizedBox(height: 12),
      _glass(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecciona si aplica',
              style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.55))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allergyOptions.map((a) {
              final sel = _allergies.contains(a);
              return GestureDetector(
                onTap: () => setState(() {
                  if (a == 'Ninguna') {
                    _allergies.clear();
                  } else {
                    _allergies.remove('Ninguna');
                    sel ? _allergies.remove(a) : _allergies.add(a);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _pink.withOpacity(0.18) : Colors.white.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? _pink.withOpacity(0.65) : Colors.white.withOpacity(0.6),
                      width: sel ? 2 : 1),
                  ),
                  child: Text(a, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: sel ? _pink : _dark.withOpacity(0.6))),
                ),
              );
            }).toList(),
          ),
        ],
      )),
      const SizedBox(height: 36),

      // ── Botón guardar ────────────────────────────────────────────────────
      SizedBox(
        width: double.infinity, height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(
                  widget.isUpdate ? 'ACTUALIZAR PERFIL' : 'GUARDAR Y CONTINUAR',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ),
    ],
  );

  // ─── Widgets de opciones ──────────────────────────────────────────────────
  Widget _sexOption(String value, IconData icon, Color color) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _sex = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _sex == value ? color.withOpacity(0.18) : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _sex == value ? color.withOpacity(0.60) : Colors.white.withOpacity(0.5),
            width: _sex == value ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: _sex == value ? color : _dark.withOpacity(0.35), size: 28),
          const SizedBox(height: 6),
          Text(_capitalize(value),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: _sex == value ? color : _dark.withOpacity(0.55))),
        ]),
      ),
    ),
  );

  Widget _activityOption(String value, String label, IconData icon, Color color) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _activityLevel = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _activityLevel == value ? color.withOpacity(0.18) : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _activityLevel == value ? color.withOpacity(0.60) : Colors.white.withOpacity(0.5),
            width: _activityLevel == value ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: _activityLevel == value ? color : _dark.withOpacity(0.35), size: 22),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _activityLevel == value ? color : _dark.withOpacity(0.5))),
        ]),
      ),
    ),
  );

  // ─── Helpers de UI ────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, IconData icon) => Row(children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: _purple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: _purple, size: 16),
    ),
    const SizedBox(width: 10),
    Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _dark)),
  ]);

  Widget _glass({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
        ),
        child: child,
      ),
    ),
  );

  Widget _glassCircle({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.55)),
        ),
        child: Center(child: child),
      ),
    ),
  );

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? _pink : _purple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _capitalize(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}
