import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  late AnimationController _bgController;
  bool _bgInit = false;

  // ── Card flip controllers (one per card) ──────────────────────────────────
  List<AnimationController> _flipControllers = [];
  late List<Animation<double>> _flipAnims;

  void _initBg() {
    if (_bgInit) return;
    _bgInit = true;
    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────
  final List<Map<String, String>> _pairs = [
    {'emoji': '🍎', 'name': 'Manzana'},
    {'emoji': '🥕', 'name': 'Zanahoria'},
    {'emoji': '🍌', 'name': 'Plátano'},
    {'emoji': '🥦', 'name': 'Brócoli'},
    {'emoji': '🍓', 'name': 'Fresa'},
    {'emoji': '🥑', 'name': 'Aguacate'},
    {'emoji': '🍊', 'name': 'Naranja'},
    {'emoji': '🐟', 'name': 'Pescado'},
  ];

  late List<Map<String, dynamic>> _cards;
  List<int> _flipped  = [];
  List<int> _matched  = [];
  bool      _checking = false;
  int       _moves    = 0;
  bool      _gameWon  = false;
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

    // Dispose old controllers
if (_flipControllers.isNotEmpty) {

      for (final c in _flipControllers) { c.dispose(); }
    }

    _flipControllers = List.generate(cards.length, (_) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    ));
    _flipAnims = _flipControllers.map((c) =>
      Tween<double>(begin: 0, end: pi).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ),
    ).toList();

    setState(() {
      _cards    = cards;
      _flipped  = [];
      _matched  = [];
      _moves    = 0;
      _gameWon  = false;
      _checking = false;
      _pointsEarned = 0;
    });
  }

  // Declare early so initState doesn't crash

  @override
  void dispose() {
    _bgController.dispose();
    for (final c in _flipControllers) { c.dispose(); }
    super.dispose();
  }

  void _onTap(int index) {
    if (_checking) return;
    if (_flipped.contains(index)) return;
    if (_matched.contains(index)) return;
    if (_flipped.length >= 2) return;

    HapticFeedback.selectionClick();
    _flipControllers[index].forward();
    setState(() => _flipped.add(index));

    if (_flipped.length == 2) {
      _moves++;
      _checking = true;
      Future.delayed(const Duration(milliseconds: 950), () {
        final a = _cards[_flipped[0]];
        final b = _cards[_flipped[1]];
        if (a['id'] == b['id'] && a['type'] != b['type']) {
          HapticFeedback.mediumImpact();
          setState(() => _matched.addAll(_flipped));
          if (_matched.length == _cards.length) {
            _pointsEarned = max(20 - _moves + 5, 5);
            _gameWon = true;
            _savePoints(_pointsEarned);
            Future.delayed(const Duration(milliseconds: 300), _showWin);
          }
        } else {
          // Flip back
          for (final i in _flipped) {
            _flipControllers[i].reverse();
          }
        }
        setState(() { _flipped = []; _checking = false; });
      });
    }
  }

  Future<void> _savePoints(int pts) async {
    if (widget.userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('kids_points').doc(widget.kidName)
          .set({
        'points': FieldValue.increment(pts),
        'memory_best_moves': _moves,
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
        moves: _moves,
        pts: _pointsEarned,
        onReplay: () { Navigator.pop(context); _initGame(); },
        onHome:  () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
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
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: _glassCircle(child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A0A36))),
                  ),
                  const SizedBox(width: 12),
                  Text('🧠 Memoria Nutricional',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
                  const Spacer(),
                  _glassChip('$_moves movs', const Color(0xFF7C3AED)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildGame() {
    final total   = _cards.length;
    final matched = _matched.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 70, 14, 14),
        child: Column(
          children: [
            // ── Progress bar
            Stack(children: [
              Container(height: 10, decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.30),
                borderRadius: BorderRadius.circular(10),
              )),
              FractionallySizedBox(
                widthFactor: total > 0 ? matched / total : 0,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(colors: [Color(0xFFFF6BA1), Color(0xFF7C3AED)]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${matched ~/ 2} / ${total ~/ 2} parejas',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF3C2864).withOpacity(0.55))),
              Text('$_moves movimientos',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF3C2864).withOpacity(0.55))),
            ]),
            const SizedBox(height: 14),

            // ── Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _cards.length <= 12 ? 4 : 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _cards.length,
                itemBuilder: (_, i) => _buildCard(i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(int i) {
    final isMatched = _matched.contains(i);
    final card = _cards[i];

    return GestureDetector(
      onTap: () => _onTap(i),
      child: AnimatedBuilder(
        animation: _flipAnims[i],
        builder: (_, __) {
          final angle = _flipAnims[i].value;
          final isFront = angle < pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront
                ? _cardFace(isMatched: isMatched)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: _cardBack(card: card, isMatched: isMatched),
                  ),
          );
        },
      ),
    );
  }

  Widget _cardFace({required bool isMatched}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isMatched
            ? const Color(0xFF4ECB71).withOpacity(0.22)
            : const Color(0xFF7C3AED).withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatched
              ? const Color(0xFF4ECB71).withOpacity(0.55)
              : const Color(0xFF7C3AED).withOpacity(0.32),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          isMatched ? '✅' : '?',
          style: GoogleFonts.nunito(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: isMatched
                ? const Color(0xFF4ECB71)
                : const Color(0xFF7C3AED).withOpacity(0.45)),
        ),
      ),
    );
  }

  Widget _cardBack({required Map<String, dynamic> card, required bool isMatched}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isMatched
            ? const Color(0xFF4ECB71).withOpacity(0.22)
            : Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatched
              ? const Color(0xFF4ECB71).withOpacity(0.60)
              : Colors.white.withOpacity(0.80),
          width: isMatched ? 2 : 1.5,
        ),
        boxShadow: isMatched
            ? [BoxShadow(color: const Color(0xFF4ECB71).withOpacity(0.20), blurRadius: 10)]
            : [],
      ),
      child: Center(
        child: card['type'] == 'emoji'
            ? Text(card['emoji'], style: const TextStyle(fontSize: 30))
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  card['name'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36)),
                ),
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
  final int moves, pts;
  final VoidCallback onReplay, onHome;
  const _WinDialog({required this.moves, required this.pts, required this.onReplay, required this.onHome});

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
                  Text('¡Ganaste!',
                      style: GoogleFonts.nunito(
                        fontSize: 30, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
                  const SizedBox(height: 8),
                  Text('En $moves movimientos',
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
