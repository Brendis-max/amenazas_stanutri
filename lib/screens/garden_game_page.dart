import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GardenGamePage extends StatefulWidget {
  final String kidName;
  final String userId;
  const GardenGamePage({super.key, required this.kidName, required this.userId});

  @override
  State<GardenGamePage> createState() => _GardenGamePageState();
}

class _GardenGamePageState extends State<GardenGamePage>
    with TickerProviderStateMixin {

  AnimationController? _bgController;
  AnimationController? _bounceController;
  bool _bgInit = false;

  void _initBg() {
    if (_bgInit) return;
    _bgInit = true;
    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();
    _bounceController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _bgController?.dispose();
    _bounceController?.dispose();
    super.dispose();
  }

  // ─── Plantas ──────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _plants = [
    {'name': 'Manzana',   'emoji': ['🌱','🌿','🌳','🍎'], 'color': const Color(0xFFFF6BA1), 'fact': 'La manzana tiene fibra que ayuda a tu digestión'},
    {'name': 'Zanahoria', 'emoji': ['🌱','🌿','🌾','🥕'], 'color': const Color(0xFFFF8C42), 'fact': 'La zanahoria tiene vitamina A para tus ojos'},
    {'name': 'Brócoli',   'emoji': ['🌱','🌿','🥦','🥦'], 'color': const Color(0xFF4ECB71), 'fact': 'El brócoli fortalece tus huesos con calcio'},
    {'name': 'Fresa',     'emoji': ['🌱','🌿','🌺','🍓'], 'color': const Color(0xFFFF6BA1), 'fact': 'La fresa tiene vitamina C para defenderte de enfermedades'},
    {'name': 'Plátano',   'emoji': ['🌱','🌿','🌴','🍌'], 'color': const Color(0xFFFFD166), 'fact': 'El plátano te da energía para jugar todo el día'},
    {'name': 'Tomate',    'emoji': ['🌱','🌿','🌱','🍅'], 'color': const Color(0xFFEF476F), 'fact': 'El tomate tiene licopeno que protege tu corazón'},
  ];

  // Estado de cada planta: 0=semilla, 1=brote, 2=planta, 3=cosecha
  late List<int>  _stages;
  late List<int>  _water;     // agua acumulada por planta
  late List<bool> _harvested;
  int  _totalHarvested = 0;
  int  _waterDrops     = 20;  // gotas disponibles
  bool _gameWon        = false;
  String? _currentFact;

  @override
  void initState() {
    super.initState();
    _initBg();
    _initGame();
  }

  void _initGame() {
    setState(() {
      _stages          = List.filled(_plants.length, 0);
      _water           = List.filled(_plants.length, 0);
      _harvested       = List.filled(_plants.length, false);
      _totalHarvested  = 0;
      _waterDrops      = 20;
      _gameWon         = false;
      _currentFact     = null;
    });
  }

  void _waterPlant(int index) {
    if (_waterDrops <= 0) return;
    if (_harvested[index]) return;
    if (_stages[index] >= 3) return;

    setState(() {
      _waterDrops--;
      _water[index]++;
      // Sube de etapa cada 3 riegos
      if (_water[index] % 3 == 0) {
        _stages[index] = min(_stages[index] + 1, 3);
        if (_stages[index] == 3) {
          _currentFact = _plants[index]['fact'] as String;
        }
      }
    });
    _bounceController?.forward(from: 0);
  }

  void _harvest(int index) {
    if (_stages[index] < 3) return;
    if (_harvested[index]) return;

    setState(() {
      _harvested[index]   = true;
      _totalHarvested++;
      _currentFact        = _plants[index]['fact'] as String;

      if (_totalHarvested >= _plants.length) {
        _gameWon = true;
        _savePoints(30);
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
        'points':          FieldValue.increment(pts),
        'garden_harvests': _totalHarvested,
        'last_played':     FieldValue.serverTimestamp(),
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
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
              child: Column(
                children: [
                  // Stats row
                  Row(
                    children: [
                      _badge('💧 $_waterDrops gotas', const Color(0xFF5DCCFF)),
                      const SizedBox(width: 8),
                      _badge('🌾 $_totalHarvested cosechadas', const Color(0xFF4ECB71)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Instrucción
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.45)),
                        ),
                        child: Text(
                          _currentFact ??
                              '💡 Toca 💧 para regar · Toca la planta madura para cosechar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12, height: 1.4,
                            color: const Color(0xFF3C2864).withOpacity(0.75)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Grid de plantas
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: List.generate(_plants.length, (i) {
                        final plant    = _plants[i];
                        final stage    = _stages[i];
                        final harvested = _harvested[i];
                        final color    = plant['color'] as Color;
                        final emojis   = plant['emoji'] as List<String>;
                        final waterNeeded = 3 - (_water[i] % 3);
                        final isReady  = stage >= 3 && !harvested;

                        return GestureDetector(
                          onTap: () => isReady ? _harvest(i) : _waterPlant(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: harvested
                                  ? Colors.white.withOpacity(0.10)
                                  : isReady
                                      ? color.withOpacity(0.30)
                                      : color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: harvested
                                    ? Colors.white.withOpacity(0.20)
                                    : isReady
                                        ? color.withOpacity(0.70)
                                        : color.withOpacity(0.35),
                                width: isReady ? 2 : 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Emoji de etapa
                                Text(
                                  harvested ? '✅' : emojis[stage],
                                  style: TextStyle(
                                    fontSize: stage == 3 ? 36 : 28),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plant['name'] as String,
                                  style: GoogleFonts.nunito(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: harvested
                                        ? const Color(0xFF3C2864).withOpacity(0.35)
                                        : const Color(0xFF1A0A36)),
                                ),
                                const SizedBox(height: 4),
                                // Progreso de agua
                                if (!harvested && stage < 3) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(3, (j) => Container(
                                      width: 6, height: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: j < (3 - waterNeeded)
                                            ? const Color(0xFF5DCCFF)
                                            : Colors.white.withOpacity(0.3),
                                      ),
                                    )),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('💧 $waterNeeded más',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: const Color(0xFF3C2864).withOpacity(0.5))),
                                ],
                                if (isReady)
                                  Text('¡Cosecha!',
                                      style: GoogleFonts.nunito(
                                        fontSize: 10, fontWeight: FontWeight.w800,
                                        color: color)),
                                if (harvested)
                                  Text('¡Lista! 🌟',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: const Color(0xFF4ECB71).withOpacity(0.7))),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Botón reiniciar si se acabó agua
                  if (_waterDrops == 0 && !_gameWon)
                    GestureDetector(
                      onTap: _initGame,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5DCCFF).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF5DCCFF).withOpacity(0.5)),
                        ),
                        child: Center(
                          child: Text('💧 Recargar y jugar de nuevo',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800, fontSize: 14,
                                color: const Color(0xFF1A0A36))),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_gameWon) _buildWinOverlay(),
        ],
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
                  const Text('🌈', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text('¡Jardín completo!',
                      style: GoogleFonts.nunito(
                        fontSize: 26, fontWeight: FontWeight.w900,
                        color: const Color(0xFF1A0A36))),
                  const SizedBox(height: 8),
                  Text('Cosechaste $_totalHarvested plantas saludables',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13, color: const Color(0xFF3C2864).withOpacity(0.65))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('⭐ +30 puntos',
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
                  Text('🌱 Jardín Saludable',
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

  Widget _badge(String text, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(text,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
    );
  }
}
