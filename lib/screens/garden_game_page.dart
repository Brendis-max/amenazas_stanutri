import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  late AnimationController _bgController;
  late List<AnimationController> _plantControllers; // scale bounce per plant
  late List<AnimationController> _waterControllers; // water drop animation per plant
  bool _bgInit = false;

  void _initBg() {
    if (_bgInit) return;
    _bgInit = true;
    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();
  }

  // ─── Plants data ──────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _plants = [
    {'name': 'Manzana',   'stages': ['🌱','🌿','🌳','🍎'], 'color': const Color(0xFFFF6BA1), 'bg': const Color(0xFFFFE8EF), 'fact': '🍎 La manzana tiene fibra que ayuda a tu digestión'},
    {'name': 'Zanahoria', 'stages': ['🌱','🌿','🌾','🥕'], 'color': const Color(0xFFFF8C42), 'bg': const Color(0xFFFFF0E0), 'fact': '🥕 La zanahoria tiene vitamina A para tus ojos'},
    {'name': 'Brócoli',   'stages': ['🌱','🌿','🥦','🥦'], 'color': const Color(0xFF10B981), 'bg': const Color(0xFFE8FDF5), 'fact': '🥦 El brócoli fortalece tus huesos con calcio'},
    {'name': 'Fresa',     'stages': ['🌱','🌿','🌺','🍓'], 'color': const Color(0xFFEC4899), 'bg': const Color(0xFFFCE8F3), 'fact': '🍓 La fresa tiene vitamina C para defenderte'},
    {'name': 'Plátano',   'stages': ['🌱','🌿','🌴','🍌'], 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFFF8E0), 'fact': '🍌 El plátano te da energía para jugar todo el día'},
    {'name': 'Tomate',    'stages': ['🌱','🌿','🌱','🍅'], 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEECEC), 'fact': '🍅 El tomate tiene licopeno que protege tu corazón'},
  ];

  late List<int>  _stages;
  late List<int>  _water;
  late List<bool> _harvested;
  late List<bool> _showWaterDrop;
  int  _totalHarvested = 0;
  int  _waterDrops     = 20;
  bool _gameWon        = false;
  String? _currentFact;

  @override
  void initState() {
    super.initState();
    _initBg();
    _plantControllers = List.generate(_plants.length, (_) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350)));
    _waterControllers = List.generate(_plants.length, (_) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _initGame();
  }

  @override
  void dispose() {
    _bgController.dispose();
    for (final c in _plantControllers) { c.dispose(); }
    for (final c in _waterControllers) { c.dispose(); }
    super.dispose();
  }

  void _initGame() {
    setState(() {
      _stages          = List.filled(_plants.length, 0);
      _water           = List.filled(_plants.length, 0);
      _harvested       = List.filled(_plants.length, false);
      _showWaterDrop   = List.filled(_plants.length, false);
      _totalHarvested  = 0;
      _waterDrops      = 20;
      _gameWon         = false;
      _currentFact     = null;
    });
  }

  void _waterPlant(int index) {
    if (_waterDrops <= 0 || _harvested[index] || _stages[index] >= 3) return;
    HapticFeedback.selectionClick();

    setState(() {
      _waterDrops--;
      _water[index]++;
      _showWaterDrop[index] = true;
    });

    // Water drop animation
    _waterControllers[index].forward(from: 0);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showWaterDrop[index] = false);
    });

    // Level up every 3 waters
    if (_water[index] % 3 == 0) {
      setState(() {
        _stages[index] = min(_stages[index] + 1, 3);
        if (_stages[index] == 3) {
          _currentFact = _plants[index]['fact'] as String;
          HapticFeedback.mediumImpact();
        }
      });
    }

    // Bounce animation
    _plantControllers[index].forward(from: 0).then((_) =>
        _plantControllers[index].reverse());
  }

  void _harvest(int index) {
    if (_stages[index] < 3 || _harvested[index]) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _harvested[index] = true;
      _totalHarvested++;
      _currentFact      = _plants[index]['fact'] as String;

      if (_totalHarvested >= _plants.length) {
        _gameWon = true;
        _savePoints(30);
        Future.delayed(const Duration(milliseconds: 400), _showWin);
      }
    });

    _plantControllers[index].forward(from: 0).then((_) =>
        _plantControllers[index].reverse());
  }

  Future<void> _savePoints(int pts) async {
    if (widget.userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('kids_points').doc(widget.kidName)
          .set({
        'points': FieldValue.increment(pts),
        'garden_harvests': _totalHarvested,
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
        harvested: _totalHarvested,
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
      body: Stack(children: [
        _buildBg(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 70, 14, 14),
            child: Column(children: [
              _buildStats(),
              const SizedBox(height: 10),
              _buildTip(),
              const SizedBox(height: 12),
              Expanded(child: _buildGrid()),
              if (_waterDrops == 0 && !_gameWon) _buildRefillBtn(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildStats() {
    return Row(children: [
      _badge('💧 $_waterDrops gotas', const Color(0xFF5DCCFF)),
      const SizedBox(width: 8),
      _badge('🌾 $_totalHarvested / ${_plants.length}', const Color(0xFF10B981)),
      const Spacer(),
      // Mini progress
      SizedBox(
        width: 80,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            Container(height: 8, color: Colors.white.withOpacity(0.30)),
            FractionallySizedBox(
              widthFactor: _totalHarvested / _plants.length,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(colors: [Color(0xFF4ECB71), Color(0xFF10B981)]),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildTip() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: ClipRRect(
        key: ValueKey(_currentFact),
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _currentFact != null
                  ? const Color(0xFF4ECB71).withOpacity(0.18)
                  : Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _currentFact != null
                    ? const Color(0xFF4ECB71).withOpacity(0.45)
                    : Colors.white.withOpacity(0.45)),
            ),
            child: Text(
              _currentFact ?? '💡 Toca 💧 para regar · Toca la planta madura para cosechar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12, height: 1.45,
                fontWeight: _currentFact != null ? FontWeight.w700 : FontWeight.w500,
                color: _currentFact != null
                    ? const Color(0xFF065F46)
                    : const Color(0xFF3C2864).withOpacity(0.70)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: List.generate(_plants.length, (i) => _buildPlantCard(i)),
    );
  }

  Widget _buildPlantCard(int i) {
    final plant    = _plants[i];
    final stage    = _stages[i];
    final harvested = _harvested[i];
    final color    = plant['color'] as Color;
    final bg       = plant['bg'] as Color;
    final stages   = plant['stages'] as List<String>;
    final isReady  = stage >= 3 && !harvested;
    final waterNeeded = 3 - (_water[i] % 3);
    final dotsFilled  = 3 - waterNeeded;

    return GestureDetector(
      onTap: () => isReady ? _harvest(i) : _waterPlant(i),
      child: AnimatedBuilder(
        animation: _plantControllers[i],
        builder: (_, child) {
          final scale = 1.0 + (_plantControllers[i].value * 0.08);
          return Transform.scale(scale: scale, child: child);
        },
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: harvested
                    ? Colors.white.withOpacity(0.12)
                    : isReady
                        ? bg.withOpacity(0.75)
                        : bg.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: harvested
                      ? Colors.white.withOpacity(0.25)
                      : isReady
                          ? color.withOpacity(0.75)
                          : color.withOpacity(0.35),
                  width: isReady ? 2.0 : 1.2,
                ),
                boxShadow: isReady
                    ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0,4))]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Plant emoji
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Text(
                            harvested ? '✅' : stages[stage],
                            key: ValueKey('$i-$stage-$harvested'),
                            style: TextStyle(fontSize: isReady || harvested ? 36 : 28),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(plant['name'] as String,
                            style: GoogleFonts.nunito(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: harvested
                                  ? const Color(0xFF3C2864).withOpacity(0.35)
                                  : const Color(0xFF1A0A36))),
                        const SizedBox(height: 4),
                        // Progress dots
                        if (!harvested && stage < 3) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (j) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 8, height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: j < dotsFilled
                                    ? const Color(0xFF5DCCFF)
                                    : Colors.white.withOpacity(0.35),
                                border: Border.all(
                                  color: j < dotsFilled
                                      ? const Color(0xFF5DCCFF).withOpacity(0.6)
                                      : Colors.white.withOpacity(0.3),
                                ),
                              ),
                            )),
                          ),
                          const SizedBox(height: 2),
                          Text('💧 $waterNeeded más',
                              style: TextStyle(
                                fontSize: 9,
                                color: const Color(0xFF3C2864).withOpacity(0.45))),
                        ],
                        if (isReady)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('¡Cosechar!',
                                style: GoogleFonts.nunito(
                                  fontSize: 9, fontWeight: FontWeight.w900, color: color)),
                          ),
                        if (harvested)
                          Text('¡Lista! 🌟',
                              style: TextStyle(
                                fontSize: 9,
                                color: const Color(0xFF10B981).withOpacity(0.8))),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Water drop animation overlay
            if (_showWaterDrop[i])
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _waterControllers[i],
                  builder: (_, __) {
                    final t = _waterControllers[i].value;
                    return Opacity(
                      opacity: (1 - t).clamp(0, 1),
                      child: Transform.translate(
                        offset: Offset(0, -30 * t),
                        child: const Center(
                          child: Text('💧', style: TextStyle(fontSize: 28)),
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

  Widget _buildRefillBtn() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: _initGame,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF5DCCFF).withOpacity(0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF5DCCFF).withOpacity(0.5)),
          ),
          child: Center(
            child: Text('💧 Recargar y jugar de nuevo',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1A0A36))),
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
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A0A36))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('🌱 Jardín Saludable',
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
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ),
    );
  }
}

// ─── Win Dialog ───────────────────────────────────────────────────────────────
class _WinDialog extends StatelessWidget {
  final int harvested;
  final VoidCallback onReplay, onHome;
  const _WinDialog({required this.harvested, required this.onReplay, required this.onHome});

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
                  const Text('🌈', style: TextStyle(fontSize: 70)),
                  const SizedBox(height: 12),
                  Text('¡Jardín completo!',
                      style: GoogleFonts.nunito(
                        fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF1A0A36))),
                  const SizedBox(height: 8),
                  Text('Cosechaste $harvested plantas saludables 🌟',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: const Color(0xFF3C2864).withOpacity(0.65))),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withOpacity(0.28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('⭐ +30 puntos',
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
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
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
