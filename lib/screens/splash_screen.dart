import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Controladores de animación ───────────────────────────────────────────
  late AnimationController _bgController;      // Fondo degradado giratorio
  late AnimationController _floatController;   // Frutas y puntos flotantes
  late AnimationController _entryController;   // Entrada de la tarjeta y logo

  // Animaciones de entrada
  late Animation<Offset> _cardSlide;
  late Animation<double>  _cardFade;
  late Animation<double>  _logoScale;
  late Animation<double>  _logoFade;

  // ─── Datos ────────────────────────────────────────────────────────────────
  final List<String> _emojis = [
    "⭐","🍎","🍌","🥕","🥦","🍊","🍇","🍓","🍒","🍍","🥝","🍐","🥑","🍉","🍋",
    "⭐","🍎","🥕","🍊","🍇",
  ];
  final int _cantidadFrutas = 20;
  final int _cantidadPuntos = 40;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF118AB2),
    Color(0xFFFFB347), Color(0xFFC77DFF), Color(0xFF80ED99),
    Color(0xFFF4A261), Color(0xFF2EC4B6), Color(0xFFE76F51),
  ];

  // Posiciones y tamaños generados una sola vez para no regenerar en cada frame
  late final List<_FloatingEmoji> _emojiData;
  late final List<_Dot> _dotData;

  @override
  void initState() {
    super.initState();

    // Fondo animado (24 s, loop)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    // Frutas y puntos flotantes (8 s, loop)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Entrada (900 ms, una sola vez)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _cardFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0, 0.7)));

    _logoScale = Tween<double>(begin: 0.75, end: 1.0)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.elasticOut));

    _logoFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0, 0.5)));

    _entryController.forward();

    // Generamos los datos estáticos de emojis y puntos
    final rnd = Random();
    _emojiData = List.generate(_cantidadFrutas, (i) {
      final r = Random(i * 31 + 7);
      return _FloatingEmoji(
        emoji: _emojis[i % _emojis.length],
        xFactor: r.nextDouble(),
        yFactor: r.nextDouble() * 0.62, // solo zona superior
        size: 22 + r.nextDouble() * 14,
        speed: 5 + r.nextDouble() * 5,
        phase: rnd.nextDouble() * 2 * pi,
      );
    });

    _dotData = List.generate(_cantidadPuntos, (i) {
      final r = Random(i * 17 + 3);
      return _Dot(
        color: _dotColors[r.nextInt(_dotColors.length)],
        xFactor: r.nextDouble(),
        yFactor: r.nextDouble() * 0.68,
        size: 3 + r.nextDouble() * 5,
        phase: rnd.nextDouble() * 2 * pi,
        opacity: 0.45 + r.nextDouble() * 0.45,
      );
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fondo degradado animado
          _buildBackground(),

          // 2. Puntos de colores pequeños
          _buildDots(size),

          // 3. Emojis flotantes
          _buildEmojis(size),

          // 4. Imagen / logo (parte superior)
          _buildTopLogo(size),

          // 5. Tarjeta liquid glass (parte inferior)
          _buildGlassCard(size, context),
        ],
      ),
    );
  }

  // ─── FONDO ─────────────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFD4F4DD),
                Color(0xFFFFF9E6),
                Color(0xFFFFD7A5),
                Color(0xFFE0F2E9),
              ],
              transform: GradientRotation(_bgController.value * 2 * pi),
            ),
          ),
        );
      },
    );
  }

  // ─── PUNTOS DE COLORES ──────────────────────────────────────────────────────
  Widget _buildDots(Size size) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) {
        return Stack(
          children: _dotData.map((d) {
            final offset = sin(_floatController.value * 2 * pi + d.phase) * 10;
            return Positioned(
              left: d.xFactor * size.width,
              top: d.yFactor * size.height + offset,
              child: Opacity(
                opacity: d.opacity,
                child: Container(
                  width: d.size,
                  height: d.size,
                  decoration: BoxDecoration(
                    color: d.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── EMOJIS FLOTANTES ───────────────────────────────────────────────────────
  Widget _buildEmojis(Size size) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) {
        return Stack(
          children: _emojiData.map((e) {
            final offset = sin(_floatController.value * 2 * pi + e.phase) * 18;
            final angle  = sin(_floatController.value * pi + e.phase) * 0.2;
            return Positioned(
              left: e.xFactor * size.width,
              top: e.yFactor * size.height + offset,
              child: Opacity(
                opacity: 0.65,
                child: Transform.rotate(
                  angle: angle,
                  child: Text(e.emoji, style: TextStyle(fontSize: e.size)),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── LOGO SUPERIOR ──────────────────────────────────────────────────────────
  Widget _buildTopLogo(Size size) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: size.height * 0.58,
      child: FadeTransition(
        opacity: _logoFade,
        child: ScaleTransition(
          scale: _logoScale,
          child: Center(
            child: Image.asset(
              'assets/splash.png',
              fit: BoxFit.contain,
              height: size.height * 0.50,
            ),
          ),
        ),
      ),
    );
  }

  // ─── TARJETA LIQUID GLASS ───────────────────────────────────────────────────
  Widget _buildGlassCard(Size size, BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: size.height * 0.46,
      child: FadeTransition(
        opacity: _cardFade,
        child: SlideTransition(
          position: _cardSlide,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
            child: BackdropFilter(
              // Blur suave: las frutas del fondo se ven difuminadas pero presentes
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  // Muy poca opacidad blanca → el fondo se transparenta
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Handle pill ───────────────────────────────
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Etiqueta pequeña ──────────────────────────
                    Text(
                      'TU ALIADO SALUDABLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                        color: const Color(0xFF50288C).withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Título bienvenida ─────────────────────────
                    const Text(
                      '¡Bienvenido a\nStarNutri! ',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A0A36),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Subtítulo ─────────────────────────────────
                    Text(
                      ' Aprender a comer bien\nnunca fue tan divertido.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: const Color(0xFF3C2864).withOpacity(0.70),
                      ),
                    ),

                    const Spacer(),

                    // ── Botón negro ───────────────────────────────
                    _buildButton(context),

                    const SizedBox(height: 14),

                    // ── Puntos de navegación ──────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _navDot(active: true),
                        const SizedBox(width: 6),
                        _navDot(),
                        const SizedBox(width: 6),
                        _navDot(),
                      ],
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

  // ─── BOTÓN ─────────────────────────────────────────────────────────────────
  Widget _buildButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          'INICIAR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }

  // ─── PUNTO DE NAVEGACIÓN ────────────────────────────────────────────────────
  Widget _navDot({bool active = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 22 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF7C3AED).withOpacity(0.5)
            : const Color(0xFF50288C).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─── Modelos de datos para emojis y puntos ─────────────────────────────────
class _FloatingEmoji {
  final String emoji;
  final double xFactor, yFactor, size, speed, phase;
  const _FloatingEmoji({
    required this.emoji,
    required this.xFactor,
    required this.yFactor,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

class _Dot {
  final Color color;
  final double xFactor, yFactor, size, phase, opacity;
  const _Dot({
    required this.color,
    required this.xFactor,
    required this.yFactor,
    required this.size,
    required this.phase,
    required this.opacity,
  });
}