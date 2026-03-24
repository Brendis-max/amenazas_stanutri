import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryGamePage extends StatefulWidget {
  final String kidName;
  final String userId;
  const MemoryGamePage({super.key, required this.kidName, required this.userId});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage>
    with TickerProviderStateMixin {

  AnimationController? _bgController;
  bool _bgInit = false;

  void _initBg() {
    if (_bgInit) return;
    _bgInit = true;
    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController?.dispose();
    super.dispose();
  }

  // ─── Datos del juego ──────────────────────────────────────────────────────
  final List<Map<String, String>> _pairs = [
    {'emoji': '🍎', 'name': 'Manzana'},
    {'emoji': '🥕', 'name': 'Zanahoria'},
    {'emoji': '🍌', 'name': 'Plátano'},
    {'emoji': '🥦', 'name': 'Brócoli'},
    {'emoji': '🍓', 'name': 'Fresa'},
    {'emoji': '🥑', 'name': 'Aguacate'},
  ];

  late List<Map<String, dynamic>> _cards;
  List<int> _flipped    = [];
  List<int> _matched    = [];
  bool      _checking   = false;
  int       _moves       = 0;
  bool      _gameWon    = false;
  int       _pointsEarned = 0;

  @override
  void initState() {
    super.initState();
    _initBg();
    _initGame();
  }

  void _initGame() {
    final cards = <Map<String, dynamic>>[];
    for (final p in _pairs) {
      cards.add({'emoji': p['emoji']!, 'name': p['name']!, 'type': 'emoji', 'id': p['name']});
      cards.add({'emoji': p['emoji']!, 'name': p['name']!, 'type': 'name',  'id': p['name']});
    }
    cards.shuffle(Random());
    setState(() {
      _cards   = cards;
      _flipped = [];
      _matched = [];
      _moves   = 0;
      _gameWon = false;
      _checking = false;
      _pointsEarned = 0;
    });
  }

  void _onTap(int index) {
    if (_checking) return;
    if (_flipped.contains(index)) return;
    if (_matched.contains(index)) return;
    if (_flipped.length >= 2) return;

    setState(() => _flipped.add(index));

    if (_flipped.length == 2) {
      _moves++;
      _checking = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        final a = _cards[_flipped[0]];
        final b = _cards[_flipped[1]];
        if (a['id'] == b['id'] && a['type'] != b['type']) {
          _matched.addAll(_flipped);
          if (_matched.length == _cards.length) {
            _pointsEarned = max(15 - _moves + 5, 5);
            _gameWon = true;
            _savePoints(_pointsEarned);
          }
        }
        setState(() { _flipped = []; _checking = false; });
      });
    }
  }

  Future<void> _savePoints(int pts) async {
    if (widget.userId.isEmpty) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('kids_points').doc(widget.kidName);
      await ref.set({
        'points': FieldValue.increment(pts),
        'memory_best_moves': _moves,
        'last_played': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _initBg();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBg(),
          _buildGame(),
          if (_gameWon) _buildWinOverlay(),
        ],
      ),
    );
  }

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
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _glassCircle(child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: Color(0xFF1A0A36))),
                    ),
                    const SizedBox(width: 12),
                    Text('🧠 Memoria Nutricional',
                        style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A0A36))),
                    const Spacer(),
                    _glassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Text('$_moves movimientos',
                          style: GoogleFonts.nunito(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C3AED))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBg() {
    if (_bgController == null) return Container(color: const Color(0xFFD4F4DD));
    return AnimatedBuilder(
      animation: _bgController!,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: const [Color(0xFFD4F4DD), Color(0xFFFFF9E6),
                           Color(0xFFFFD7A5), Color(0xFFE0F2E9)],
            transform: GradientRotation(_bgController!.value * 2 * pi),
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
        child: Column(
          children: [
            // Progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(children: [
                Container(height: 8, color: Colors.white.withOpacity(0.3)),
                FractionallySizedBox(
                  widthFactor: _matched.length / _cards.length,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6BA1), Color(0xFF7C3AED)]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _cards.length,
                itemBuilder: (_, i) {
                  final isFlipped  = _flipped.contains(i) || _matched.contains(i);
                  final isMatched  = _matched.contains(i);
                  final card       = _cards[i];

                  return GestureDetector(
                    onTap: () => _onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: isMatched
                            ? const Color(0xFF4ECB71).withOpacity(0.25)
                            : isFlipped
                                ? Colors.white.withOpacity(0.55)
                                : const Color(0xFF7C3AED).withOpacity(0.20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMatched
                              ? const Color(0xFF4ECB71).withOpacity(0.6)
                              : isFlipped
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF7C3AED).withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isFlipped
                            ? card['type'] == 'emoji'
                                ? Text(card['emoji'], style: const TextStyle(fontSize: 28))
                                : Text(
                                    card['name'],
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11, fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A0A36)),
                                  )
                            : Text('?',
                                style: GoogleFonts.nunito(
                                  fontSize: 22, fontWeight: FontWeight.w900,
                                  color: const Color(0xFF7C3AED).withOpacity(0.5))),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  Text('¡Ganaste!',
                      style: GoogleFonts.nunito(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        color: const Color(0xFF1A0A36))),
                  const SizedBox(height: 8),
                  Text('En $_moves movimientos',
                      style: TextStyle(
                        fontSize: 14, color: const Color(0xFF3C2864).withOpacity(0.65))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.5)),
                    ),
                    child: Text('⭐ +$_pointsEarned puntos',
                        style: GoogleFonts.nunito(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF8C42))),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _initGame,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.5)),
                            ),
                            child: Center(
                              child: Text('🔄 Jugar otra vez',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800, fontSize: 13,
                                    color: const Color(0xFF1A0A36))),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text('← Volver',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800, fontSize: 13,
                                    color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassCircle({required Widget child}) {
    return ClipRRect(
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
    );
  }
}
