import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
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
    with SingleTickerProviderStateMixin {

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

  // ─── Preguntas ────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _allQuestions = [
    {
      'question': '¿Qué vitamina tienen las zanahorias que ayuda a tus ojos?',
      'options':  ['Vitamina A', 'Vitamina C', 'Vitamina D', 'Vitamina B'],
      'correct':  0,
      'emoji':    '🥕',
    },
    {
      'question': '¿Cuántos vasos de agua debes tomar al día?',
      'options':  ['2 vasos', '4 vasos', '8 vasos', '1 vaso'],
      'correct':  2,
      'emoji':    '💧',
    },
    {
      'question': '¿Qué alimento tiene más proteínas?',
      'options':  ['Manzana', 'Arroz', 'Pollo', 'Lechuga'],
      'correct':  2,
      'emoji':    '🍗',
    },
    {
      'question': '¿Qué fruta tiene mucha vitamina C?',
      'options':  ['Plátano', 'Naranja', 'Uva', 'Pera'],
      'correct':  1,
      'emoji':    '🍊',
    },
    {
      'question': '¿Por qué es importante desayunar?',
      'options':  ['Para dormir más', 'Para tener energía', 'Para crecer menos', 'Para nada'],
      'correct':  1,
      'emoji':    '🌅',
    },
    {
      'question': '¿Cuál es una verdura?',
      'options':  ['Manzana', 'Plátano', 'Brócoli', 'Uva'],
      'correct':  2,
      'emoji':    '🥦',
    },
    {
      'question': '¿El calcio en los lácteos ayuda a fortalecer?',
      'options':  ['El cabello', 'Los huesos', 'Las uñas', 'Los dientes de leche'],
      'correct':  1,
      'emoji':    '🥛',
    },
    {
      'question': '¿Qué grupo alimenticio da más energía rápida?',
      'options':  ['Proteínas', 'Grasas', 'Carbohidratos', 'Vitaminas'],
      'correct':  2,
      'emoji':    '⚡',
    },
    {
      'question': '¿Cuál NO es una fruta?',
      'options':  ['Fresa', 'Tomate', 'Zanahoria', 'Mango'],
      'correct':  2,
      'emoji':    '🤔',
    },
    {
      'question': '¿Qué pasa si comes muchos dulces?',
      'options':  ['Creces más', 'Puedes tener caries', 'Eres más listo', 'Nada malo'],
      'correct':  1,
      'emoji':    '🍭',
    },
  ];

  late List<Map<String, dynamic>> _questions;
  int  _current       = 0;
  int  _score         = 0;
  int? _selectedAnswer;
  bool _answered      = false;
  bool _gameFinished  = false;

  @override
  void initState() {
    super.initState();
    _initBg();
    _initGame();
  }

  void _initGame() {
    final q = List<Map<String, dynamic>>.from(_allQuestions)..shuffle(Random());
    setState(() {
      _questions      = q.take(7).toList();
      _current        = 0;
      _score          = 0;
      _selectedAnswer = null;
      _answered       = false;
      _gameFinished   = false;
    });
  }

  void _onAnswer(int index) {
    if (_answered) return;
    final isCorrect = index == _questions[_current]['correct'];
    setState(() {
      _selectedAnswer = index;
      _answered       = true;
      if (isCorrect) _score++;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_current + 1 >= _questions.length) {
        final pts = _score * 4; // 4 pts por respuesta correcta
        _savePoints(pts);
        setState(() => _gameFinished = true);
      } else {
        setState(() {
          _current++;
          _selectedAnswer = null;
          _answered       = false;
        });
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
        'points':      FieldValue.increment(pts),
        'quiz_best':   _score,
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
              child: _gameFinished ? _buildResults() : _buildQuestion(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q       = _questions[_current];
    final options = q['options'] as List<String>;
    final correct = q['correct'] as int;

    final optionColors = [
      const Color(0xFFFF6BA1),
      const Color(0xFF7C3AED),
      const Color(0xFF5DCCFF),
      const Color(0xFF4ECB71),
    ];

    return Column(
      children: [
        // Progreso
        Row(
          children: List.generate(_questions.length, (i) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 6,
              decoration: BoxDecoration(
                color: i < _current
                    ? const Color(0xFF7C3AED).withOpacity(0.6)
                    : i == _current
                        ? const Color(0xFF7C3AED).withOpacity(0.9)
                        : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          )),
        ),
        const SizedBox(height: 8),
        Text('${_current + 1} / ${_questions.length}',
            style: TextStyle(
              fontSize: 12, color: const Color(0xFF3C2864).withOpacity(0.55))),
        const SizedBox(height: 20),

        // Pregunta
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(q['emoji'] as String,
                      style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    q['question'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A0A36), height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Opciones
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            shrinkWrap: true,
            children: List.generate(options.length, (i) {
              Color color = optionColors[i];
              Color bgColor = color.withOpacity(0.15);
              Color borderColor = color.withOpacity(0.35);

              if (_answered && _selectedAnswer == i) {
                bgColor     = i == correct
                    ? const Color(0xFF4ECB71).withOpacity(0.35)
                    : const Color(0xFFFF6BA1).withOpacity(0.35);
                borderColor = i == correct
                    ? const Color(0xFF4ECB71).withOpacity(0.8)
                    : const Color(0xFFFF6BA1).withOpacity(0.8);
              } else if (_answered && i == correct) {
                bgColor     = const Color(0xFF4ECB71).withOpacity(0.25);
                borderColor = const Color(0xFF4ECB71).withOpacity(0.6);
              }

              return GestureDetector(
                onTap: () => _onAnswer(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      options[i],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A0A36),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Score actual
        Text('⭐ $_score correctas',
            style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: const Color(0xFFFF8C42))),
      ],
    );
  }

  Widget _buildResults() {
    final pts  = _score * 4;
    final pct  = _score / _questions.length;
    String msg = pct >= 0.8
        ? '¡Eres un experto en nutrición! 🏆'
        : pct >= 0.5
            ? '¡Muy bien! Sigue aprendiendo 🌟'
            : '¡Sigue practicando! 💪';

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pct >= 0.8 ? '🏆' : pct >= 0.5 ? '🌟' : '💪',
                    style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A0A36))),
                const SizedBox(height: 8),
                Text('$_score de ${_questions.length} correctas',
                    style: TextStyle(
                      fontSize: 14, color: const Color(0xFF3C2864).withOpacity(0.65))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('⭐ +$pts puntos',
                      style: GoogleFonts.nunito(
                        fontSize: 22, fontWeight: FontWeight.w900,
                        color: const Color(0xFFFF8C42))),
                ),
                const SizedBox(height: 20),
                Row(children: [
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
                        child: Center(child: Text('🔄 Otra vez',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800, fontSize: 13,
                              color: const Color(0xFF1A0A36)))),
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
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800, fontSize: 13,
                              color: Colors.white))),
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
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded,
                              size: 16, color: Color(0xFF1A0A36))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('❓ Quiz Nutricional',
                      style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: const Color(0xFF1A0A36))),
                ]),
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
}
