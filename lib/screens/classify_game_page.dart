import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassifyGamePage extends StatefulWidget {
  final String kidName;
  final String userId;
  const ClassifyGamePage({super.key, required this.kidName, required this.userId});

  @override
  State<ClassifyGamePage> createState() => _ClassifyGamePageState();
}

class _ClassifyGamePageState extends State<ClassifyGamePage>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _cardController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();
    _cardController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350),
    );
    _shakeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _initGame();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────
  final List<Map<String, String>> _allFoods = [
    {'name': '🍎 Manzana',     'cat': 'Frutas'},
    {'name': '🍌 Plátano',     'cat': 'Frutas'},
    {'name': '🍓 Fresa',       'cat': 'Frutas'},
    {'name': '🍊 Naranja',     'cat': 'Frutas'},
    {'name': '🍇 Uvas',        'cat': 'Frutas'},
    {'name': '🥭 Mango',       'cat': 'Frutas'},
    {'name': '🥦 Brócoli',     'cat': 'Verduras'},
    {'name': '🥕 Zanahoria',   'cat': 'Verduras'},
    {'name': '🌽 Elote',       'cat': 'Verduras'},
    {'name': '🍅 Tomate',      'cat': 'Verduras'},
    {'name': '🥬 Espinaca',    'cat': 'Verduras'},
    {'name': '🧅 Cebolla',     'cat': 'Verduras'},
    {'name': '🥚 Huevo',       'cat': 'Proteínas'},
    {'name': '🍗 Pollo',       'cat': 'Proteínas'},
    {'name': '🐟 Pescado',     'cat': 'Proteínas'},
    {'name': '🫘 Frijoles',    'cat': 'Proteínas'},
    {'name': '🥩 Carne',       'cat': 'Proteínas'},
    {'name': '🥜 Cacahuate',   'cat': 'Proteínas'},
    {'name': '🥛 Leche',       'cat': 'Lácteos'},
    {'name': '🧀 Queso',       'cat': 'Lácteos'},
    {'name': '🍦 Yogurt',      'cat': 'Lácteos'},
    {'name': '🧈 Mantequilla', 'cat': 'Lácteos'},
  ];

  final Map<String, Map<String, dynamic>> _catConfig = {
    'Frutas':    {'emoji': '🍎', 'color': const Color(0xFFFF6B8A), 'bg': const Color(0xFFFFE8EF)},
    'Verduras':  {'emoji': '🥦', 'color': const Color(0xFF10B981), 'bg': const Color(0xFFE8FDF5)},
    'Proteínas': {'emoji': '🥩', 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFFF8E8)},
    'Lácteos':   {'emoji': '🥛', 'color': const Color(0xFF06B6D4), 'bg': const Color(0xFFE8F8FF)},
  };

  late List<Map<String, String>> _remaining;
  final Map<String, List<Map<String, String>>> _placed = {
    'Frutas': [], 'Verduras': [], 'Proteínas': [], 'Lácteos': [],
  };

  int _correct = 0;
  int _wrong = 0;
  bool _gameWon = false;
  String? _hoveredCat;
  bool _isWrong = false;

  void _initGame() {
    final rng = Random();
    final list = List<Map<String, String>>.from(_allFoods)..shuffle(rng);
    setState(() {
      _remaining = list.take(16).toList();
      _placed.forEach((key, val) => val.clear());
      _correct = 0;
      _wrong = 0;
      _gameWon = false;
      _hoveredCat = null;
      _isWrong = false;
    });
    _cardController.forward(from: 0);
  }

  void _onDrop(String cat) {
    if (_remaining.isEmpty) return;
    final food = _remaining.first;

    HapticFeedback.lightImpact();

    if (food['cat'] == cat) {
      setState(() {
        _remaining.removeAt(0);
        _placed[cat]!.add(food);
        _correct++;
        if (_remaining.isEmpty) _gameWon = true;
      });
      _cardController.forward(from: 0);
      if (_gameWon) {
        _savePoints(20);
        Future.delayed(const Duration(milliseconds: 400), _showWin);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() { _wrong++; _isWrong = true; });
      _shakeController.forward(from: 0).then((_) {
        setState(() { _isWrong = false; });
        final copy = List<Map<String, String>>.from(_remaining)..shuffle();
        setState(() => _remaining = copy);
      });
    }
    setState(() => _hoveredCat = null);
  }

  Future<void> _savePoints(int pts) async {
    if (widget.userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('kids_points').doc(widget.kidName)
          .set({
        'points': FieldValue.increment(pts),
        'classify_correct': _correct,
        'last_played': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showWin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _WinDialog(
        correct: _correct,
        wrong: _wrong,
        pts: 20,
        onReplay: () { Navigator.pop(context); _initGame(); },
        onHome:  () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 70, 14, 14),
              child: Column(children: [
                _buildStats(),
                const SizedBox(height: 12),
                _buildFoodCard(),
                const SizedBox(height: 14),
                Expanded(child: _buildCategories()),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.4))),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _glassBtn(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A0A36)),
                  ),
                  const SizedBox(width: 12),
                  Text('🍽️ Clasifica Alimentos',
                      style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
                  const Spacer(),
                  _glassChip('📦 ${_remaining.length} quedan', const Color(0xFF7C3AED)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Stats ────────────────────────────────────────────────────────────────
  Widget _buildStats() {
    return Row(children: [
      _statBadge('✅ $_correct', const Color(0xFF10B981)),
      const SizedBox(width: 8),
      _statBadge('❌ $_wrong',  const Color(0xFFFF6B8A)),
      const Spacer(),
      _statBadge('📦 ${_remaining.length}', const Color(0xFF7C3AED)),
    ]);
  }

  Widget _statBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text,
          style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    );
  }

  // ─── Food Card (Draggable) ────────────────────────────────────────────────
  Widget _buildFoodCard() {
    if (_remaining.isEmpty) return const SizedBox(height: 100);
    final food = _remaining.first;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) {
        final dx = _isWrong
            ? sin(_shakeAnim.value * pi * 6) * 10
            : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
        ),
        child: Draggable<Map<String, String>>(
          data: food,
          onDragStarted: () => HapticFeedback.selectionClick(),
          feedback: Material(
            color: Colors.transparent,
            child: _foodChip(food['name']!, isDragging: true),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _foodChip(food['name']!),
          ),
          child: _foodChip(food['name']!),
        ),
      ),
    );
  }

  Widget _foodChip(String name, {bool isDragging = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDragging ? 0.95 : 0.70),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.55), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(isDragging ? 0.30 : 0.12),
            blurRadius: isDragging ? 24 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(name,
          style: GoogleFonts.nunito(
            fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
    );
  }

  // ─── Categories Grid ──────────────────────────────────────────────────────
  Widget _buildCategories() {
    final cats = _catConfig.keys.toList();
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: cats.map((cat) => _buildDropZone(cat)).toList(),
    );
  }

  Widget _buildDropZone(String cat) {
    final cfg   = _catConfig[cat]!;
    final color = cfg['color'] as Color;
    final bg    = cfg['bg'] as Color;
    final items = _placed[cat]!;
    final isHovered = _hoveredCat == cat;

    return DragTarget<Map<String, String>>(
      onWillAcceptWithDetails: (details) {
        setState(() => _hoveredCat = cat);
        return true;
      },
      onLeave: (_) => setState(() => _hoveredCat = null),
      onAcceptWithDetails: (details) => _onDrop(cat),
      builder: (context, candidateData, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovered ? color.withOpacity(0.22) : bg.withOpacity(0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isHovered ? color : color.withOpacity(0.30),
              width: isHovered ? 2.5 : 1.5,
            ),
            boxShadow: isHovered
                ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16, offset: const Offset(0,4))]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(cfg['emoji'] as String, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(cat,
                            style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w900,
                              color: color)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${items.length}',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (isHovered)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('¡Suéltalo aquí!',
                              style: GoogleFonts.nunito(
                                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ),
                      ),
                    Expanded(
                      child: Wrap(
                        spacing: 4, runSpacing: 4,
                        children: items.map((f) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              f['name']!.split(' ').first,
                              style: const TextStyle(fontSize: 18),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Background ───────────────────────────────────────────────────────────
  Widget _buildBg() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: const [Color(0xFFD4F4DD), Color(0xFFFFF9E6), Color(0xFFFFD7A5), Color(0xFFE0F2E9)],
            transform: GradientRotation(_bgController.value * 2 * pi),
          ),
        ),
      ),
    );
  }

  Widget _glassBtn({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _glassChip(String text, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(text,
              style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ),
    );
  }
}

// ─── Win Dialog ───────────────────────────────────────────────────────────────
class _WinDialog extends StatelessWidget {
  final int correct, wrong, pts;
  final VoidCallback onReplay, onHome;
  const _WinDialog({required this.correct, required this.wrong, required this.pts, required this.onReplay, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.60), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 70)),
                  const SizedBox(height: 12),
                  Text('¡Clasificado!',
                      style: GoogleFonts.nunito(
                        fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
                  const SizedBox(height: 8),
                  Text('$correct correctos · $wrong errores',
                      style: TextStyle(fontSize: 14, color: const Color(0xFF3C2864).withOpacity(0.6))),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withOpacity(0.28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('⭐ +$pts puntos',
                        style: GoogleFonts.nunito(
                          fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFFFF8C42))),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onReplay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.5)),
                          ),
                          child: Center(child: Text('🔄 Otra vez',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1A0A36)))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onHome,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: Text('← Volver',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white))),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
