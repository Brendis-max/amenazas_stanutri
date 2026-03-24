import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {

  // ─── Controladores de animación ───────────────────────────────────────────
  late AnimationController _bgController;
  late AnimationController _floatController;
  late AnimationController _entryController;
  late Animation<Offset>   _cardSlide;
  late Animation<double>   _cardFade;

  // ─── Form ─────────────────────────────────────────────────────────────────
  final auth            = AuthService();
  final emailController = TextEditingController();
  final passController  = TextEditingController();
  final formKey         = GlobalKey<FormState>();
  bool  isLoading       = false;
  bool  _obscurePass    = true;

  // ─── Datos visuales ───────────────────────────────────────────────────────
  final List<String> _emojis = [
    "⭐","🍎","🍌","🥕","🥦","🍊","🍇","🍓","🍒","🍍",
    "🥝","🍐","🥑","🍉","🍋","⭐","🍎","🥕","🍊","🍇",
  ];

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF118AB2),
    Color(0xFFFFB347), Color(0xFFC77DFF), Color(0xFF80ED99),
    Color(0xFFF4A261), Color(0xFF2EC4B6), Color(0xFFE76F51),
  ];

  late final List<_FloatingEmoji> _emojiData;
  late final List<_Dot>           _dotData;

  // ─── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _cardFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0, 0.7)));

    _entryController.forward();

    final rnd = Random();

    _emojiData = List.generate(20, (i) {
      final r = Random(i * 31 + 13);
      return _FloatingEmoji(
        emoji:   _emojis[i % _emojis.length],
        xFactor: r.nextDouble(),
        yFactor: r.nextDouble(),
        size:    20 + r.nextDouble() * 14,
        phase:   rnd.nextDouble() * 2 * pi,
      );
    });

    _dotData = List.generate(40, (i) {
      final r = Random(i * 17 + 9);
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
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    _entryController.dispose();
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String sanitizeInput(String input) =>
      input.trim().replaceAll(RegExp(r'[<>{}\[\]\\|^`"~]'), '');

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildBackground(),
          _buildDots(size),
          _buildEmojis(size),
          _buildContent(size),
        ],
      ),
    );
  }

  // ─── FONDO DEGRADADO ANIMADO ──────────────────────────────────────────────
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) => Container(
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
      ),
    );
  }

  // ─── PUNTOS DE COLORES ────────────────────────────────────────────────────
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

  // ─── EMOJIS FLOTANTES ─────────────────────────────────────────────────────
  Widget _buildEmojis(Size size) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) => Stack(
        children: _emojiData.map((e) {
          final dy    = sin(_floatController.value * 2 * pi + e.phase) * 18;
          final angle = sin(_floatController.value * pi  + e.phase) * 0.2;
          return Positioned(
            left: e.xFactor * size.width,
            top:  e.yFactor * size.height + dy,
            child: Opacity(
              opacity: 0.60,
              child: Transform.rotate(
                angle: angle,
                child: Text(e.emoji, style: TextStyle(fontSize: e.size)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── CONTENIDO PRINCIPAL ──────────────────────────────────────────────────
  Widget _buildContent(Size size) {
    return SafeArea(
      child: Column(
        children: [
          // ── Logo superior ────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Center(
              child: Image.asset(
                'assets/splash.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image, size: 80, color: Colors.white54),
              ),
            ),
          ),

          // ── Tarjeta liquid glass ─────────────────────────────────────────
          FadeTransition(
            opacity: _cardFade,
            child: SlideTransition(
              position: _cardSlide,
              child: _buildGlassCard(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TARJETA LIQUID GLASS ─────────────────────────────────────────────────
  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
            border: Border.all(
              color: Colors.white.withOpacity(0.55),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 32),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Handle pill
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Etiqueta superior
                  Text(
                    'ÚNETE A NOSOTROS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: const Color(0xFF50288C).withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Título
                  const Text(
                    'Crea tu cuenta\nen StarNutri 🌱',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A0A36),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtítulo
                  Text(
                    'Regístrate para gestionar tus perfiles',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF3C2864).withOpacity(0.60),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Campo Email ────────────────────────────────────────
                  _glassField(
                    controller: emailController,
                    hint: 'Correo electrónico',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Campo obligatorio';
                      if (!v.contains('@')) return 'Email inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Campo Contraseña ───────────────────────────────────
                  _glassField(
                    controller: passController,
                    hint: 'Contraseña (mín. 6 caracteres)',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF50288C).withOpacity(0.6),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Campo obligatorio';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 26),

                  // ── Botón Registrarse (negro) ──────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: isLoading ? null : _handleRegister,
                      child: isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'CREAR CUENTA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Volver al login ────────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '¿Ya tienes cuenta? Inicia sesión',
                        style: TextStyle(
                          color: const Color(0xFF3C2864).withOpacity(0.75),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF3C2864).withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── CAMPO GLASS REUTILIZABLE ─────────────────────────────────────────────
  Widget _glassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      obscureText:  obscureText,
      style: const TextStyle(
        color: Color(0xFF1A0A36),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF3C2864).withOpacity(0.45),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF50288C).withOpacity(0.6), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.25),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.55), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.55), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6BA1), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6BA1), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6BA1), fontSize: 11),
      ),
      validator: validator,
    );
  }

  // ─── LÓGICA DE REGISTRO ───────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final String cleanEmail = sanitizeInput(emailController.text);
      await auth.registerWithEmail(cleanEmail, passController.text);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Cuenta creada con éxito! 🎉'),
          backgroundColor: const Color(0xFF4ECB71),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6BA1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}

// ─── Modelos ──────────────────────────────────────────────────────────────────
class _FloatingEmoji {
  final String emoji;
  final double xFactor, yFactor, size, phase;
  const _FloatingEmoji({
    required this.emoji,
    required this.xFactor,
    required this.yFactor,
    required this.size,
    required this.phase,
  });
}

class _Dot {
  final Color  color;
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