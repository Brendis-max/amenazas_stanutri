import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_selection_page.dart';
import 'memory_game_page.dart';
import 'classify_game_page.dart';
import 'quiz_game_page.dart';
import 'garden_game_page.dart';

class KidsHomePage extends StatefulWidget {
  final String kidName;
  const KidsHomePage({super.key, required this.kidName});

  @override
  State<KidsHomePage> createState() => _KidsHomePageState();
}

class _KidsHomePageState extends State<KidsHomePage>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _floatController;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF80ED99),
  ];
  late final List<_Dot> _dotData;

  int _totalPoints = 0;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

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

    _loadPoints();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadPoints() async {
    if (userId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('kids_points').doc(widget.kidName)
          .get();
      if (snap.exists && mounted) {
        setState(() => _totalPoints = (snap.data()?['points'] ?? 0) as int);
      }
    } catch (_) {}
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildDots(size),
          SafeArea(child: _buildContent()),
        ],
      ),
    );
  }

  // ─── FONDO ────────────────────────────────────────────────────────────────
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

  // ─── CONTENIDO ────────────────────────────────────────────────────────────
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header: logo + nombre + salir + puntos ────────────────────
          _buildHeader(),
          const SizedBox(height: 22),

          // ── Bienvenida hero ───────────────────────────────────────────
          _buildHeroWelcome(),
          const SizedBox(height: 24),

          // ── Dato curioso ──────────────────────────────────────────────
          _buildFunFact(),
          const SizedBox(height: 26),

          // ── Juegos ────────────────────────────────────────────────────
          Text(
            'JUEGOS',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: const Color(0xFF50288C).withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '🎮 ¡Juega y aprende!',
            style: GoogleFonts.nunito(
              fontSize: 26, fontWeight: FontWeight.w900,
              color: const Color(0xFF1A0A36), height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _buildGamesGrid(),
          const SizedBox(height: 26),

          // ── Mis logros ────────────────────────────────────────────────
          Text(
            'LOGROS',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: const Color(0xFF50288C).withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '🏆 Mis logros',
            style: GoogleFonts.nunito(
              fontSize: 26, fontWeight: FontWeight.w900,
              color: const Color(0xFF1A0A36), height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _buildAchievements(),
        ],
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        // Botón salir
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSelectionPage()),
          ),
          child: _glassCircle(
            child: const Icon(Icons.exit_to_app, size: 20, color: Color(0xFF1A0A36)),
          ),
        ),
        const SizedBox(width: 10),

        // Logo
        Image.asset(
          'assets/starnutri2.png',
          height: 36,
          errorBuilder: (_, __, ___) =>
              const Text('🌟', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 10),

        // Nombre
        Expanded(
          child: Text(
            widget.kidName.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: const Color(0xFF1A0A36), letterSpacing: 1,
            ),
          ),
        ),

        // Puntos badge
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.55)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 5),
                  Text(
                    '$_totalPoints pts',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w900, fontSize: 15,
                      color: const Color(0xFFFF8C42),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── HERO BIENVENIDA ──────────────────────────────────────────────────────
  Widget _buildHeroWelcome() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6BA1).withOpacity(0.20),
                const Color(0xFF7C3AED).withOpacity(0.15),
                const Color(0xFF5DCCFF).withOpacity(0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, ${widget.kidName}! 🌟',
                style: GoogleFonts.nunito(
                  fontSize: 24, fontWeight: FontWeight.w900,
                  color: const Color(0xFF1A0A36),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '¿Listo para aprender nutrición jugando?',
                style: TextStyle(
                  fontSize: 14, height: 1.4,
                  color: const Color(0xFF3C2864).withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_totalPoints / 200 pts',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: const Color(0xFF50288C).withOpacity(0.75),
                    ),
                  ),
                  Text(
                    '${((_totalPoints / 200) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C3AED).withOpacity(0.75),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double fillWidth = constraints.maxWidth *
                      (_totalPoints / 200).clamp(0.0, 1.0);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 12,
                      child: Stack(
                        children: [
                          Container(
                            width: constraints.maxWidth,
                            height: 12,
                            color: Colors.white.withOpacity(0.35),
                          ),
                          Container(
                            width: fillWidth,
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6BA1), Color(0xFF7C3AED)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── DATO CURIOSO ─────────────────────────────────────────────────────────
  Widget _buildFunFact() {
    const facts = [
      '🥕 Las zanahorias ayudan a tus ojos a ver mejor en la oscuridad.',
      '🍌 Los plátanos te dan energía para correr y jugar todo el día.',
      '🥦 El brócoli tiene vitaminas que fortalecen tus huesos.',
      '💧 Tomar agua te ayuda a concentrarte mejor en la escuela.',
      '🍓 Las fresas tienen vitamina C que protege tu cuerpo.',
    ];
    final fact = facts[DateTime.now().day % facts.length];

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('💡', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Sabías que?',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800, fontSize: 16,
                        color: const Color(0xFF1A0A36),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fact,
                      style: TextStyle(
                        fontSize: 13, height: 1.4,
                        color: const Color(0xFF3C2864).withOpacity(0.7),
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

  // ─── GRID DE JUEGOS ───────────────────────────────────────────────────────
  Widget _buildGamesGrid() {
    final games = [
      {
        'title':  'Memoria\nNutricional',
        'emoji':  '🧠',
        'points': '+15 pts',
        'desc':   'Encuentra las parejas',
        'color':  const Color(0xFFFF6BA1),
        'page':   MemoryGamePage(kidName: widget.kidName, userId: userId),
      },
      {
        'title':  'Clasifica\nAlimentos',
        'emoji':  '🍽️',
        'points': '+20 pts',
        'desc':   'Arrastra y clasifica',
        'color':  const Color(0xFF7C3AED),
        'page':   ClassifyGamePage(kidName: widget.kidName, userId: userId),
      },
      {
        'title':  'Quiz\nNutricional',
        'emoji':  '❓',
        'points': '+25 pts',
        'desc':   'Responde preguntas',
        'color':  const Color(0xFF5DCCFF),
        'page':   QuizGamePage(kidName: widget.kidName, userId: userId),
      },
      {
        'title':  'Jardín\nSaludable',
        'emoji':  '🌱',
        'points': '+30 pts',
        'desc':   'Cultiva tus plantas',
        'color':  const Color(0xFF4ECB71),
        'page':   GardenGamePage(kidName: widget.kidName, userId: userId),
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.90,
      children: games.map((g) {
        final Color color = g['color'] as Color;
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => g['page'] as Widget),
            );
            _loadPoints();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color.withOpacity(0.40), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g['emoji'] as String,
                        style: const TextStyle(fontSize: 40)),
                    const Spacer(),
                    Text(
                      g['title'] as String,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900, fontSize: 16,
                        color: const Color(0xFF1A0A36), height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      g['desc'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF3C2864).withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        g['points'] as String,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── LOGROS ───────────────────────────────────────────────────────────────
  Widget _buildAchievements() {
    final achievements = [
      {'emoji': '🌟', 'title': 'Primer juego',  'desc': 'Juega por primera vez',  'needed': 1,   'color': const Color(0xFFFFD166)},
      {'emoji': '🔥', 'title': 'En racha',       'desc': 'Gana 3 juegos seguidos', 'needed': 50,  'color': const Color(0xFFFF6BA1)},
      {'emoji': '🏆', 'title': 'Campeón nutri',  'desc': 'Acumula 100 puntos',     'needed': 100, 'color': const Color(0xFF7C3AED)},
      {'emoji': '🌈', 'title': 'Experto',         'desc': 'Acumula 200 puntos',     'needed': 200, 'color': const Color(0xFF5DCCFF)},
    ];

    return Column(
      children: achievements.map((a) {
        final int needed    = a['needed'] as int;
        final Color color   = a['color'] as Color;
        final bool unlocked = _totalPoints >= needed;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: unlocked
                      ? color.withOpacity(0.18)
                      : Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: unlocked
                        ? color.withOpacity(0.45)
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      a['emoji'] as String,
                      style: TextStyle(
                        fontSize: 32,
                        color: unlocked
                            ? null
                            : const Color(0xFF3C2864).withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['title'] as String,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800, fontSize: 15,
                              color: unlocked
                                  ? const Color(0xFF1A0A36)
                                  : const Color(0xFF3C2864).withOpacity(0.4),
                            ),
                          ),
                          Text(
                            a['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF3C2864).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '✓ Logrado',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: color,
                          ),
                        ),
                      )
                    else
                      Text(
                        '$needed pts',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF3C2864).withOpacity(0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _glassCircle({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ─── Modelos ──────────────────────────────────────────────────────────────────
class _Dot {
  final Color  color;
  final double xFactor, yFactor, size, phase, opacity;
  const _Dot({
    required this.color, required this.xFactor, required this.yFactor,
    required this.size, required this.phase, required this.opacity,
  });
}
