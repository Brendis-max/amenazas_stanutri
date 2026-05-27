import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizGamePage extends StatefulWidget {
  final String kidName;
  final String userId;
  const QuizGamePage({super.key, required this.kidName, required this.userId});

  @override
  State<QuizGamePage> createState() => _QuizGamePageState();
}

class _QuizGamePageState extends State<QuizGamePage>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _timerController;
  late AnimationController _questionController;
  bool _bgInit = false;

  void _initBg() {
    if (_bgInit) return;
    _bgInit = true;
    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();
  }

  // ─── Questions ────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _allQuestions = [
    {'q': '¿Qué vitamina tienen las zanahorias para tus ojos?',         'opts': ['Vitamina A','Vitamina C','Vitamina D','Vitamina B'], 'ans': 0, 'emoji': '🥕', 'fact': '¡La vitamina A mejora tu visión nocturna!'},
    {'q': '¿Cuántos vasos de agua se recomiendan al día?',              'opts': ['2 vasos','4 vasos','8 vasos','1 vaso'],             'ans': 2, 'emoji': '💧', 'fact': 'El agua regula tu temperatura corporal.'},
    {'q': '¿Qué alimento tiene más proteínas para los músculos?',       'opts': ['Manzana','Arroz','Pollo','Lechuga'],               'ans': 2, 'emoji': '🍗', 'fact': '¡El pollo es una proteína completa y magra!'},
    {'q': '¿Qué fruta tiene más vitamina C?',                          'opts': ['Plátano','Naranja','Uva','Pera'],                   'ans': 1, 'emoji': '🍊', 'fact': 'Una naranja cubre tu vitamina C del día.'},
    {'q': '¿Por qué es importante desayunar?',                         'opts': ['Para dormir más','Para tener energía','Para nada','Para crecer menos'], 'ans': 1, 'emoji': '🌅', 'fact': 'El desayuno activa tu cerebro y metabolismo.'},
    {'q': '¿Cuál de estos es una verdura?',                            'opts': ['Manzana','Plátano','Brócoli','Uva'],               'ans': 2, 'emoji': '🥦', 'fact': 'El brócoli tiene vitamina K, C y mucho calcio.'},
    {'q': '¿El calcio en los lácteos fortalece qué?',                  'opts': ['El cabello','Los huesos','Las uñas','La piel'],    'ans': 1, 'emoji': '🥛', 'fact': 'Los huesos almacenan el 99% del calcio.'},
    {'q': '¿Qué grupo da energía rápida al cuerpo?',                   'opts': ['Proteínas','Grasas','Carbohidratos','Vitaminas'],  'ans': 2, 'emoji': '⚡', 'fact': 'El cerebro usa glucosa (carbohidratos) como combustible.'},
    {'q': '¿Cuál NO es una fruta?',                                    'opts': ['Fresa','Tomate','Zanahoria','Mango'],              'ans': 2, 'emoji': '🤔', 'fact': 'La zanahoria es una raíz, no una fruta.'},
    {'q': '¿Qué puede pasar si comes muchos dulces?',                  'opts': ['Creces más','Caries en los dientes','Eres más listo','Ves mejor'], 'ans': 1, 'emoji': '🍭', 'fact': 'El azúcar crea bacterias que dañan el esmalte.'},
    {'q': '¿Qué mineral hace fuertes tus huesos y dientes?',           'opts': ['Hierro','Zinc','Calcio','Sodio'],                  'ans': 2, 'emoji': '🦷', 'fact': '¡Los dientes son el tejido más duro del cuerpo!'},
    {'q': '¿Qué color tienen los alimentos con mucha vitamina C?',     'opts': ['Azul','Naranja y rojo','Gris','Morado oscuro'],    'ans': 1, 'emoji': '🌈', 'fact': 'Los pigmentos naranja y rojo indican betacarotenos.'},
    {'q': '¿Cuántas veces al día debes lavarte los dientes?',          'opts': ['1 vez','2-3 veces','Solo en la noche','No es necesario'], 'ans': 1, 'emoji': '🪥', 'fact': 'Lavarse tras cada comida evita caries.'},
    {'q': '¿Qué alimento viene del mar y es rico en omega-3?',         'opts': ['Pollo','Arroz','Pescado','Aguacate'],              'ans': 2, 'emoji': '🐟', 'fact': 'El omega-3 del pescado cuida tu corazón y cerebro.'},
    {'q': '¿Qué fruta tiene más potasio para tu corazón?',             'opts': ['Manzana','Fresa','Uva','Plátano'],                'ans': 3, 'emoji': '🍌', 'fact': 'El plátano tiene más potasio que muchas bebidas deportivas.'},
  ];

  late List<Map<String, dynamic>> _questions;
  int    _current        = 0;
  int    _score          = 0;
  int?   _selectedAnswer;
  bool   _answered       = false;
  bool   _gameFinished   = false;
  String? _currentFact;

  static const int _timerSecs = 15;

  @override
  void initState() {
    super.initState();
    _initBg();

    _timerController = AnimationController(
      vsync: this, duration: const Duration(seconds: _timerSecs),
    );
    _questionController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );

    _initGame();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _timerController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  void _initGame() {
    final q = List<Map<String, dynamic>>.from(_allQuestions)..shuffle(Random());
    setState(() {
      _questions      = q.take(8).toList();
      _current        = 0;
      _score          = 0;
      _selectedAnswer = null;
      _answered       = false;
      _gameFinished   = false;
      _currentFact    = null;
    });
    _startTimer();
    _questionController.forward(from: 0);
  }

  void _startTimer() {
    _timerController.reverse(from: 1.0);
    _timerController.addStatusListener(_onTimerFinish);
  }

  void _onTimerFinish(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_answered && !_gameFinished) {
      _onAnswer(-1); // time up = wrong
    }
  }

  void _onAnswer(int index) {
    if (_answered) return;
    _timerController.stop();
    _timerController.removeStatusListener(_onTimerFinish);

    final isCorrect = index == _questions[_current]['ans'];
    if (isCorrect) HapticFeedback.mediumImpact();
    else           HapticFeedback.heavyImpact();

    setState(() {
      _selectedAnswer = index;
      _answered       = true;
      _currentFact    = _questions[_current]['fact'] as String?;
      if (isCorrect) _score++;
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_current + 1 >= _questions.length) {
        final pts = _score * 4;
        _savePoints(pts);
        setState(() => _gameFinished = true);
      } else {
        setState(() {
          _current++;
          _selectedAnswer = null;
          _answered       = false;
          _currentFact    = null;
        });
        _timerController.addStatusListener(_onTimerFinish);
        _timerController.reverse(from: 1.0);
        _questionController.forward(from: 0);
      }
    });
  }

  Future<void> _savePoints(int pts) async {
    if (widget.userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('kids_points').doc(widget.kidName)
          .set({
        'points': FieldValue.increment(pts),
        'quiz_best': _score,
        'last_played': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Color per option
  static const _optColors = [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF), Color(0xFF4ECB71),
  ];

  @override
  Widget build(BuildContext context) {
    _initBg();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
              child: _gameFinished ? _buildResults() : _buildQuestion(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q       = _questions[_current];
    final options = q['opts'] as List<String>;
    final correct = q['ans'] as int;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _questionController, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: _questionController,
        child: Column(children: [
          // Progress segments
          Row(children: List.generate(_questions.length, (i) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 6,
              decoration: BoxDecoration(
                color: i < _current
                    ? const Color(0xFF7C3AED).withOpacity(0.65)
                    : i == _current
                        ? const Color(0xFF7C3AED).withOpacity(0.90)
                        : Colors.white.withOpacity(0.30),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_current + 1} / ${_questions.length}',
                style: TextStyle(fontSize: 12, color: const Color(0xFF3C2864).withOpacity(0.5), fontWeight: FontWeight.w700)),
            Text('⭐ $_score correctas',
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFFF8C42))),
          ]),
          const SizedBox(height: 12),

          // ── Timer bar
          AnimatedBuilder(
            animation: _timerController,
            builder: (_, __) {
              final value = _timerController.value;
              final timerColor = value > 0.5 ? const Color(0xFF4ECB71) :
                                  value > 0.25 ? const Color(0xFFFFD166) : const Color(0xFFFF6BA1);
              return Column(children: [
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.30),
                        valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(_timerSecs * value).ceil()}s',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: timerColor),
                  ),
                ]),
              ]);
            },
          ),
          const SizedBox(height: 16),

          // ── Question card
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.60), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
                ),
                child: Column(children: [
                  Text(q['emoji'] as String, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 12),
                  Text(q['q'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A0A36), height: 1.35)),
                  // Fact on answer
                  if (_answered && _currentFact != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECB71).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('💡 $_currentFact',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12, color: const Color(0xFF065F46), fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Options grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10, crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              shrinkWrap: true,
              children: List.generate(options.length, (i) {
                final color = _optColors[i];
                Color bgColor     = color.withOpacity(0.14);
                Color borderColor = color.withOpacity(0.32);

                if (_answered) {
                  if (i == correct) {
                    bgColor     = const Color(0xFF4ECB71).withOpacity(0.30);
                    borderColor = const Color(0xFF4ECB71).withOpacity(0.75);
                  } else if (_selectedAnswer == i) {
                    bgColor     = const Color(0xFFFF6BA1).withOpacity(0.30);
                    borderColor = const Color(0xFFFF6BA1).withOpacity(0.75);
                  }
                }

                return GestureDetector(
                  onTap: () => _onAnswer(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(options[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A0A36))),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildResults() {
    final pts = _score * 4;
    final pct = _score / _questions.length;
    final emoji = pct >= 0.75 ? '🏆' : pct >= 0.5 ? '🌟' : '💪';
    final title = pct >= 0.75 ? '¡Experto en nutrición!' : pct >= 0.5 ? '¡Muy bien!' : '¡Sigue practicando!';

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.60), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 70)),
                const SizedBox(height: 14),
                Text(title, textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
                const SizedBox(height: 8),
                Text('$_score de ${_questions.length} correctas',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF3C2864).withOpacity(0.6))),
                const SizedBox(height: 8),
                // Score gauge
                _buildScoreGauge(_score, _questions.length),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166).withOpacity(0.28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('⭐ +$pts puntos',
                      style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFFFF8C42))),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _initGame,
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
                      onTap: () => Navigator.pop(context),
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
    );
  }

  Widget _buildScoreGauge(int score, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 22, height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < score
              ? const Color(0xFF4ECB71).withOpacity(0.85)
              : Colors.white.withOpacity(0.25),
          border: Border.all(
            color: i < score
                ? const Color(0xFF4ECB71).withOpacity(0.6)
                : Colors.white.withOpacity(0.4),
          ),
        ),
        child: i < score
            ? const Center(child: Text('✓', style: TextStyle(fontSize: 12, color: Colors.white)))
            : null,
      )),
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
                  Text('❓ Quiz Nutricional',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
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
