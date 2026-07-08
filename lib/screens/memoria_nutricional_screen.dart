import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════
//  MODELO
// ══════════════════════════════════════════════════════════

class FruitCard {
  final String id;
  final String pairId;
  final String name;
  final String assetPath;
  bool isFlipped;
  bool isMatched;

  FruitCard({
    required this.id,
    required this.pairId,
    required this.name,
    required this.assetPath,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

const List<Map<String, String>> _catalog = [
  {'name': 'Cherry',     'asset': 'assets/cards/cherry.png'},
  {'name': 'Kiwi',       'asset': 'assets/cards/kiwi.png'},
  {'name': 'Fresa',      'asset': 'assets/cards/fresa.png'},
  {'name': 'Peach',      'asset': 'assets/cards/peach.png'},
  {'name': 'Pear',       'asset': 'assets/cards/pear.png'},
  {'name': 'Blueberry',  'asset': 'assets/cards/blueberry.png'},
  {'name': 'Lemon',      'asset': 'assets/cards/lemon.png'},
  {'name': 'Orange',     'asset': 'assets/cards/orange.png'},
  {'name': 'Papaya',     'asset': 'assets/cards/papaya.png'},
  {'name': 'Uva',        'asset': 'assets/cards/uva.png'},
  {'name': 'Banana',     'asset': 'assets/cards/banana.png'},
  {'name': 'Piña',       'asset': 'assets/cards/pina.png'},
  {'name': 'Watermelon', 'asset': 'assets/cards/watermelon.png'},
  {'name': 'Mango',      'asset': 'assets/cards/mango.png'},
];

const String _cardBackAsset = 'assets/cards/card_back.png';

// ══════════════════════════════════════════════════════════
//  MODELO DE PUNTO FLOTANTE (igual que KidsHomePage)
// ══════════════════════════════════════════════════════════

class _Dot {
  final Color  color;
  final double xFactor, yFactor, size, phase, opacity;
  const _Dot({
    required this.color, required this.xFactor, required this.yFactor,
    required this.size, required this.phase, required this.opacity,
  });
}

// ══════════════════════════════════════════════════════════
//  PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════════

class MemoriaNutricionalScreen extends StatefulWidget {
  const MemoriaNutricionalScreen({super.key});

  @override
  State<MemoriaNutricionalScreen> createState() =>
      _MemoriaNutricionalScreenState();
}

class _MemoriaNutricionalScreenState extends State<MemoriaNutricionalScreen>
    with TickerProviderStateMixin {

  int? _pairCount;

  // ── Animaciones de fondo (igual que KidsHomePage) ──────
  late AnimationController _bgController;
  late AnimationController _floatController;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF80ED99),
  ];
  late final List<_Dot> _dotData;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();

    _floatController = AnimationController(
      vsync: this, duration: const Duration(seconds: 8),
    )..repeat();

    final rnd = Random();
    _dotData = List.generate(35, (i) {
      final r = Random(i * 17 + 5);
      return _Dot(
        color:   _dotColors[r.nextInt(_dotColors.length)],
        xFactor: r.nextDouble(), yFactor: r.nextDouble(),
        size:    3 + r.nextDouble() * 5,
        phase:   rnd.nextDouble() * 2 * pi,
        opacity: 0.4 + r.nextDouble() * 0.45,
      );
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ── Fondo animado (idéntico al de KidsHomePage) ────────
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: const [
              Color(0xFFD4F4DD), Color(0xFFFFF9E6),
              Color(0xFFFFD7A5), Color(0xFFE0F2E9),
            ],
            transform: GradientRotation(_bgController.value * 2 * pi),
          ),
        ),
      ),
    );
  }

  Widget _buildDots(Size size) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) => Stack(
        children: _dotData.map((d) {
          final dy = sin(_floatController.value * 2 * pi + d.phase) * 10;
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildDots(size),
          SafeArea(
            child: _pairCount == null
                ? _DifficultyScreen(onSelect: (pairs) {
                    setState(() => _pairCount = pairs);
                  })
                : _GameScreen(
                    pairCount: _pairCount!,
                    onRestart: () => setState(() => _pairCount = null),
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PANTALLA SELECCIÓN DE DIFICULTAD
// ══════════════════════════════════════════════════════════

class _DifficultyScreen extends StatelessWidget {
  final void Function(int pairs) onSelect;
  const _DifficultyScreen({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header glassmorphism estilo KidsHomePage
        _KidsHeader(title: 'Memoria Nutricional', subtitle: 'Elige tu nivel'),
        const SizedBox(height: 16),

        // Decoración
        const Text('🍓🍋🍇🍊🫐', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          '¡Encuentra todas las parejas!',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF50288C),
          ),
        ),
        const SizedBox(height: 20),

        // Tarjetas de nivel
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _LevelCard(
                emoji: '⭐',
                level: 'Fácil',
                description: '6 parejas · 12 cartas',
                pairCount: 6,
                color: const Color(0xFF4ECB71),
                pts: '+15 pts',
                onTap: () => onSelect(6),
              ),
              const SizedBox(height: 14),
              _LevelCard(
                emoji: '⭐⭐',
                level: 'Normal',
                description: '8 parejas · 16 cartas',
                pairCount: 8,
                color: const Color(0xFFFF8C42),
                pts: '+20 pts',
                onTap: () => onSelect(8),
              ),
              const SizedBox(height: 14),
              _LevelCard(
                emoji: '⭐⭐⭐',
                level: 'Difícil',
                description: '14 parejas · 28 cartas',
                pairCount: 14,
                color: const Color(0xFFFF6BA1),
                pts: '+30 pts',
                onTap: () => onSelect(14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String emoji;
  final String level;
  final String description;
  final int pairCount;
  final Color color;
  final String pts;
  final VoidCallback onTap;

  const _LevelCard({
    required this.emoji,
    required this.level,
    required this.description,
    required this.pairCount,
    required this.color,
    required this.pts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.40), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 19)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: const Color(0xFF1A0A36),
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF3C2864).withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    pts,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
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
}

// ══════════════════════════════════════════════════════════
//  PANTALLA DE JUEGO
// ══════════════════════════════════════════════════════════

class _GameScreen extends StatefulWidget {
  final int pairCount;
  final VoidCallback onRestart;
  const _GameScreen({required this.pairCount, required this.onRestart});

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  late List<FruitCard> _cards;
  final List<FruitCard> _selected = [];
  bool _locked = false;
  int _moves = 0;
  int _matched = 0;
  int _score = 0;
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _elapsed = '0:00';

  @override
  void initState() {
    super.initState();
    _buildCards();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final s = _stopwatch.elapsed.inSeconds;
          _elapsed = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _buildCards() {
    final chosen = List.of(_catalog)..shuffle(Random());
    final pairs = chosen.take(widget.pairCount).toList();
    final cards = <FruitCard>[];
    for (var i = 0; i < pairs.length; i++) {
      for (var j = 0; j < 2; j++) {
        cards.add(FruitCard(
          id: '${i}_$j',
          pairId: '$i',
          name: pairs[i]['name']!,
          assetPath: pairs[i]['asset']!,
        ));
      }
    }
    cards.shuffle(Random());
    _cards = cards;
  }

  void _onTap(FruitCard card) {
    if (_locked) return;
    if (card.isFlipped || card.isMatched) return;
    if (_selected.length == 2) return;

    setState(() {
      card.isFlipped = true;
      _selected.add(card);
    });

    if (_selected.length == 2) {
      _moves++;
      _locked = true;
      Future.delayed(const Duration(milliseconds: 900), _checkMatch);
    }
  }

  void _checkMatch() {
    final a = _selected[0];
    final b = _selected[1];
    if (a.pairId == b.pairId) {
      setState(() {
        a.isMatched = true;
        b.isMatched = true;
        _matched++;
        _score += (_moves <= widget.pairCount + 2) ? 25 : 15;
      });
      if (_matched == widget.pairCount) {
        _stopwatch.stop();
        _timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), _showWin);
      }
    } else {
      setState(() {
        a.isFlipped = false;
        b.isFlipped = false;
      });
    }
    _selected.clear();
    _locked = false;
  }

  void _showWin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WinDialog(
        moves: _moves,
        elapsed: _elapsed,
        score: _score,
        onRestart: () {
          Navigator.pop(context);
          widget.onRestart();
        },
        onPlayAgain: () {
          Navigator.pop(context);
          setState(() {
            _moves = 0;
            _matched = 0;
            _score = 0;
            _selected.clear();
            _locked = false;
            _buildCards();
            _stopwatch..reset()..start();
          });
        },
      ),
    );
  }

  int get _crossAxisCount {
    if (widget.pairCount <= 6) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header glassmorphism con stats integradas
        _KidsHeader(
          title: 'Memoria Nutricional',
          subtitle: _levelLabel,
          trailing: _StatsBar(moves: _moves, elapsed: _elapsed, score: _score),
        ),
        const SizedBox(height: 8),

        // Barra de progreso glassmorphism
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_matched / widget.pairCount).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6BA1), Color(0xFF7C3AED)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Tablero
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              itemCount: _cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (_, i) => _CardTile(
                card: _cards[i],
                onTap: () => _onTap(_cards[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String get _levelLabel {
    if (widget.pairCount <= 6) return '⭐ Fácil';
    if (widget.pairCount <= 8) return '⭐⭐ Normal';
    return '⭐⭐⭐ Difícil';
  }
}

// ══════════════════════════════════════════════════════════
//  CARTA CON ANIMACIÓN FLIP
// ══════════════════════════════════════════════════════════

class _CardTile extends StatefulWidget {
  final FruitCard card;
  final VoidCallback onTap;
  const _CardTile({required this.card, required this.onTap});

  @override
  State<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<_CardTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _showFront = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _anim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _CardTile old) {
    super.didUpdateWidget(old);
    if (widget.card.isFlipped && !_showFront) {
      _ctrl.forward().then((_) => setState(() => _showFront = true));
    } else if (!widget.card.isFlipped && _showFront) {
      setState(() => _showFront = false);
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle = _anim.value * pi;
          final isFront = angle > pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: isFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _FrontFace(card: widget.card),
                  )
                : _BackFace(),
          );
        },
      ),
    );
  }
}

class _BackFace extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        _cardBackAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.25),
                    const Color(0xFFFF6BA1).withOpacity(0.20),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.45),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Text('⭐', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrontFace extends StatelessWidget {
  final FruitCard card;
  const _FrontFace({required this.card});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.isMatched
              ? const Color(0xFF4ECB71)
              : Colors.transparent,
          width: 3,
        ),
        boxShadow: card.isMatched
            ? [
                BoxShadow(
                    color: const Color(0xFF4ECB71).withOpacity(0.4),
                    blurRadius: 10)
              ]
            : [],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              card.assetPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: const Color(0xFFFFD7A5).withOpacity(0.35),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🍓', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: const Color(0xFF1A0A36),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (card.isMatched)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: Color(0xFF4ECB71), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DIÁLOGO VICTORIA
// ══════════════════════════════════════════════════════════

class _WinDialog extends StatelessWidget {
  final int moves;
  final String elapsed;
  final int score;
  final VoidCallback onRestart;
  final VoidCallback onPlayAgain;

  const _WinDialog({
    required this.moves,
    required this.elapsed,
    required this.score,
    required this.onRestart,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 50)),
                const SizedBox(height: 6),
                Text(
                  '¡Lo lograste!',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: const Color(0xFF1A0A36),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Encontraste todas las parejas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF3C2864).withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip(icon: '🎯', label: 'Movimientos', value: '$moves'),
                    _StatChip(icon: '⏱️', label: 'Tiempo', value: elapsed),
                  ],
                ),
                const SizedBox(height: 14),

                // Puntos con gradiente
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6BA1), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐ ', style: TextStyle(fontSize: 18)),
                      Text(
                        '$score pts',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: '🔁 Jugar de nuevo',
                        color: const Color(0xFF4ECB71),
                        onTap: onPlayAgain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DialogButton(
                        label: '🏠 Niveles',
                        color: const Color(0xFFFF6BA1),
                        onTap: onRestart,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: const Color(0xFF1A0A36),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF3C2864).withOpacity(0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DialogButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.45), width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HEADER GLASSMORPHISM — ESTILO KIDS HOME PAGE
// ══════════════════════════════════════════════════════════

class _KidsHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _KidsHeader({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFF6BA1).withOpacity(0.22),
                  const Color(0xFF7C3AED).withOpacity(0.16),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Botón volver — igual que _glassCircle del KidsHomePage
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: Color(0xFF1A0A36),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Logo: solo cuando NO hay stats al lado (deja espacio en el
                // header de juego, que es donde antes desbordaba)
                if (trailing == null) ...[
                  Flexible(
                    child: Image.asset(
                      'assets/starnutri2.png',
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('🌟', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Título y subtítulo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: const Color(0xFF1A0A36),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF3C2864).withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing (stats, etc.) — Flexible para que nunca desborde
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: trailing!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  BARRA DE STATS (glassmorphism)
// ══════════════════════════════════════════════════════════

class _StatsBar extends StatelessWidget {
  final int moves;
  final String elapsed;
  final int score;
  const _StatsBar({required this.moves, required this.elapsed, required this.score});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '⭐$score',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    color: const Color(0xFFFF8C42),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '⏱$elapsed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF3C2864).withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
