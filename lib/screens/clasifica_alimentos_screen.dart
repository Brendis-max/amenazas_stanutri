import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// MODELO DE DATOS
// ─────────────────────────────────────────────

enum FoodGroup {
  frutasVerduras,
  cerealesTuberculos,
  leguminosas,
  alimentosAnimal,
}

extension FoodGroupExt on FoodGroup {
  String get label {
    switch (this) {
      case FoodGroup.frutasVerduras:
        return 'Verduras\ny Frutas';
      case FoodGroup.cerealesTuberculos:
        return 'Cereales';
      case FoodGroup.leguminosas:
        return 'Legumi-\nnosas';
      case FoodGroup.alimentosAnimal:
        return 'Origen\nAnimal';
    }
  }

  String get sublabel {
    switch (this) {
      case FoodGroup.frutasVerduras:
        return '¡Come muchas!';
      case FoodGroup.cerealesTuberculos:
        return '¡Consume suficientes!';
      case FoodGroup.leguminosas:
        return '¡Combina y modera!';
      case FoodGroup.alimentosAnimal:
        return '¡Combina y modera!';
    }
  }

  // Color de relleno (claro, pastel) — el interior del cuadrante
  Color get color {
    switch (this) {
      case FoodGroup.frutasVerduras:
        return const Color(0xFFCDEAB8);
      case FoodGroup.cerealesTuberculos:
        return const Color(0xFFFFDCAE);
      case FoodGroup.leguminosas:
        return const Color(0xFFFFF1AE);
      case FoodGroup.alimentosAnimal:
        return const Color(0xFFFFC4C4);
    }
  }

  // Color sólido (saturado) — usado en bordes y etiquetas
  Color get bandColor {
    switch (this) {
      case FoodGroup.frutasVerduras:
        return const Color(0xFF4CAF3D);
      case FoodGroup.cerealesTuberculos:
        return const Color(0xFFF5970A);
      case FoodGroup.leguminosas:
        return const Color(0xFFE8C200);
      case FoodGroup.alimentosAnimal:
        return const Color(0xFFE6483C);
    }
  }

  Color get labelColor {
    switch (this) {
      case FoodGroup.frutasVerduras:
        return const Color(0xFF1F6B1A);
      case FoodGroup.cerealesTuberculos:
        return const Color(0xFFA85800);
      case FoodGroup.leguminosas:
        return const Color(0xFF8A6A00);
      case FoodGroup.alimentosAnimal:
        return const Color(0xFFA31E14);
    }
  }
}

class FoodItem {
  final String id;
  final String emoji;
  final String? imagePath;
  final String name;
  final FoodGroup group;

  const FoodItem({
    required this.id,
    required this.emoji,
    this.imagePath,
    required this.name,
    required this.group,
  });
}

// ─────────────────────────────────────────────
// DATOS
// ─────────────────────────────────────────────

const List<FoodItem> _allFoods = [
  FoodItem(id: 'manzana',   emoji: '🍎', name: 'Manzana',   group: FoodGroup.frutasVerduras),
  FoodItem(id: 'platano',   emoji: '🍌', name: 'Plátano',   group: FoodGroup.frutasVerduras),
  FoodItem(id: 'naranja',   emoji: '🍊', name: 'Naranja',   group: FoodGroup.frutasVerduras),
  FoodItem(id: 'zanahoria', emoji: '🥕', name: 'Zanahoria', group: FoodGroup.frutasVerduras),
  FoodItem(id: 'brocoli',   emoji: '🥦', name: 'Brócoli',   group: FoodGroup.frutasVerduras),
  FoodItem(id: 'sandia',    emoji: '🍉', name: 'Sandía',    group: FoodGroup.frutasVerduras),
  FoodItem(id: 'arroz',     emoji: '🍚', name: 'Arroz',     group: FoodGroup.cerealesTuberculos),
  FoodItem(id: 'pan',       emoji: '🍞', name: 'Pan',       group: FoodGroup.cerealesTuberculos),
  FoodItem(id: 'papa',      emoji: '🥔', name: 'Papa',      group: FoodGroup.cerealesTuberculos),
  FoodItem(id: 'maiz',      emoji: '🌽', name: 'Maíz',      group: FoodGroup.cerealesTuberculos),
  FoodItem(id: 'frijoles',  emoji: '🫘', name: 'Frijoles',  group: FoodGroup.leguminosas),
  FoodItem(id: 'lentejas',  emoji: '🟤', name: 'Lentejas',  group: FoodGroup.leguminosas),
  FoodItem(id: 'chicharo',  emoji: '🫛', name: 'Chícharo',  group: FoodGroup.leguminosas),
  FoodItem(id: 'pollo',     emoji: '🍗', name: 'Pollo',     group: FoodGroup.alimentosAnimal),
  FoodItem(id: 'pescado',   emoji: '🐟', name: 'Pescado',   group: FoodGroup.alimentosAnimal),
  FoodItem(id: 'huevo',     emoji: '🍳', name: 'Huevo',     group: FoodGroup.alimentosAnimal),
  FoodItem(id: 'leche',     emoji: '🥛', name: 'Leche',     group: FoodGroup.alimentosAnimal),
  FoodItem(id: 'queso',     emoji: '🧀', name: 'Queso',     group: FoodGroup.alimentosAnimal),
];

// ─────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────

class ClasificaAlimentosScreen extends StatefulWidget {
  const ClasificaAlimentosScreen({super.key});

  @override
  State<ClasificaAlimentosScreen> createState() => _ClasificaAlimentosScreenState();
}

class _ClasificaAlimentosScreenState extends State<ClasificaAlimentosScreen>
    with TickerProviderStateMixin {
  late List<FoodItem> _remaining;

  final Map<FoodGroup, List<FoodItem>> _placed = {
    for (final g in FoodGroup.values) g: [],
  };

  final Map<FoodGroup, bool?> _sectionFeedback = {
    for (final g in FoodGroup.values) g: null,
  };

  int _score = 0;
  int _errors = 0;
  bool _gameOver = false;

  // Cuadrante actualmente resaltado mientras se arrastra encima
  FoodGroup? _hoveringGroup;

  late AnimationController _starController;
  late Animation<double> _starAnim;

  late AnimationController _bgController;
  late AnimationController _floatController;
  late List<_BgDot> _bgDots;

  static const List<Color> _dotColors = [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF80ED99),
  ];

  @override
  void initState() {
    super.initState();
    _remaining = List.from(_allFoods)..shuffle(Random());

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _starAnim = CurvedAnimation(parent: _starController, curve: Curves.elasticOut);

    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();

    _floatController = AnimationController(
      vsync: this, duration: const Duration(seconds: 8),
    )..repeat();

    final rnd = Random();
    _bgDots = List.generate(25, (i) {
      final r = Random(i * 17 + 5);
      return _BgDot(
        color:   _dotColors[r.nextInt(_dotColors.length)],
        x: r.nextDouble(), y: r.nextDouble(),
        size:    3 + r.nextDouble() * 5,
        phase:   rnd.nextDouble() * 2 * pi,
        opacity: 0.35 + r.nextDouble() * 0.35,
      );
    });
  }

  @override
  void dispose() {
    _starController.dispose();
    _bgController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // Fondo degradado animado
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [
                    Color(0xFFD4F4DD), Color(0xFFFFF9E6),
                    Color(0xFFFFD7A5), Color(0xFFE0F2E9),
                  ],
                  transform: GradientRotation(_bgController.value * 2 * pi),
                ),
              ),
            ),
          ),
          // Puntos flotantes
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Stack(
              children: _bgDots.map((d) {
                final dy = sin(_floatController.value * 2 * pi + d.phase) * 10;
                return Positioned(
                  left: d.x * size.width,
                  top:  d.y * size.height + dy,
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
          ),
          // Contenido principal
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _gameOver ? _buildWinScreen() : _buildGameArea(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onDropped(FoodItem food, FoodGroup targetGroup) {
    final correct = food.group == targetGroup;

    setState(() {
      _hoveringGroup = null;
      if (correct) {
        _remaining.remove(food);
        _placed[targetGroup]!.add(food);
        _score += 20;
        _sectionFeedback[targetGroup] = true;
        if (_remaining.isEmpty) _gameOver = true;
        _starController.forward(from: 0);
      } else {
        _errors++;
        _sectionFeedback[targetGroup] = false;
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _sectionFeedback[targetGroup] = null);
      }
    });
  }

  void _restart() {
    setState(() {
      _remaining = List.from(_allFoods)..shuffle(Random());
      for (final g in FoodGroup.values) {
        _placed[g] = [];
        _sectionFeedback[g] = null;
      }
      _score = 0;
      _errors = 0;
      _gameOver = false;
    });
  }

  // ── HEADER ──────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4CAF3D).withOpacity(0.20),
                  const Color(0xFFE6483C).withOpacity(0.16),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: ClipRRect(
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
                        child: const Center(
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18, color: Color(0xFF1A0A36)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clasifica Alimentos',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: const Color(0xFF1A0A36))),
                      Text('Arrastra cada alimento al grupo correcto',
                          style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF3C2864).withOpacity(0.65))),
                    ],
                  ),
                ),
                ScaleTransition(
                  scale: _starAnim,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Text('$_score pts',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFFF6B9D),
                                    fontSize: 14)),
                          ],
                        ),
                      ),
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

  // ── ÁREA DE JUEGO ────────────────────────────
  Widget _buildGameArea() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_allFoods.length - _remaining.length) / _allFoods.length,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.6),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF3D)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_allFoods.length - _remaining.length}/${_allFoods.length}',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F6B1A),
                    fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(flex: 5, child: _buildPlate()),
        Expanded(flex: 3, child: _buildFoodBank()),
        const SizedBox(height: 8),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PLATO DEL BUEN COMER — FIX DEL BUG ORIGINAL
  // ════════════════════════════════════════════════════════════
  //
  // EL BUG: antes había 4 widgets DragTarget, cada uno con tamaño
  // size x size (el plato COMPLETO), apilados sin Positioned dentro
  // de un Stack. El ClipPath solo recortaba lo que se VEÍA, pero el
  // área que recibía el toque seguía siendo el cuadrado completo.
  // Resultado: el último cuadrante de la lista (Origen Animal) tapaba
  // a los otros 3 para efectos de hit-testing, así que casi ningún
  // alimento se quedaba en su grupo real.
  //
  // EL FIX: un solo DragTarget que cubre el plato completo. Al recibir
  // un drop, calculamos el ÁNGULO del punto respecto al centro real del
  // plato y así determinamos a qué cuadrante pertenece. Los 4 cuadrantes
  // visuales (ClipPath) ahora son puramente decorativos —usamos
  // IgnorePointer para que no interfieran con el hit-testing— y sus
  // límites angulares coinciden exactamente con _groupAtPosition.
  Widget _buildPlate() {
    return LayoutBuilder(builder: (context, constraints) {
      final plateSize = min(constraints.maxWidth, constraints.maxHeight) * 0.95;

      return Center(
        child: Builder(
          builder: (plateContext) {
            return DragTarget<FoodItem>(
              onWillAcceptWithDetails: (details) {
                final group = _groupAtPosition(details.offset, plateContext, plateSize);
                setState(() => _hoveringGroup = group);
                return true;
              },
              onLeave: (_) => setState(() => _hoveringGroup = null),
              onAcceptWithDetails: (details) {
                final group = _groupAtPosition(details.offset, plateContext, plateSize);
                if (group != null) _onDropped(details.data, group);
              },
              builder: (context, candidates, rejected) {
                return SizedBox(
                  width: plateSize,
                  height: plateSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Plato base
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.brown.withOpacity(0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                      ),

                      // Los 4 cuadrantes: SOLO visuales (IgnorePointer)
                      ..._buildQuadrantVisuals(plateSize),

                      // Borde grueso exterior por cuadrante (estilo referencia)
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(plateSize, plateSize),
                          painter: _OuterRingPainter(),
                        ),
                      ),

                      // Líneas divisorias blancas
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(plateSize, plateSize),
                          painter: _PlateDividerPainter(),
                        ),
                      ),

                      // Centro: gota de agua
                      Container(
                        width: plateSize * 0.16,
                        height: plateSize * 0.16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF5DCCFF), width: 2.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6),
                          ],
                        ),
                        child: Center(
                          child: Text('💧', style: TextStyle(fontSize: plateSize * 0.075)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }

  // Determina a qué grupo corresponde un punto de drop (coordenadas
  // globales) según su ángulo real respecto al centro del plato.
  FoodGroup? _groupAtPosition(Offset globalPos, BuildContext plateCtx, double plateSize) {
    final renderBox = plateCtx.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final local = renderBox.globalToLocal(globalPos);
    final center = Offset(plateSize / 2, plateSize / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;

    // Muy cerca del centro (zona del agua) -> no es un grupo válido
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < plateSize * 0.09) return null;

    // atan2 con eje Y hacia abajo (convención de pantalla en Flutter):
    //   0°   = derecha · 90° = abajo · 180° = izquierda · 270° = arriba
    double angle = atan2(dy, dx) * 180 / pi;
    if (angle < 0) angle += 360;

    // Estas regiones coinciden EXACTAMENTE con la geometría dibujada en
    // _buildQuadrantVisuals (mismos ángulos en los CustomClippers):
    //   • Mitad superior completa (180°–360°) -> Frutas y Verduras
    //   • Mitad inferior (0°–180°) dividida en 3:
    //       - Banda central angosta 65°–115° -> Leguminosas
    //       - 115°–180° (izquierda)           -> Cereales
    //       - 0°–65°   (derecha)               -> Origen Animal
    const legumStart = 65.0;
    const legumEnd = 115.0;

    if (angle >= 180) {
      return FoodGroup.frutasVerduras;
    } else if (angle >= legumStart && angle < legumEnd) {
      return FoodGroup.leguminosas;
    } else if (angle >= legumEnd) {
      return FoodGroup.cerealesTuberculos;
    }
    return FoodGroup.alimentosAnimal;
  }

  List<Widget> _buildQuadrantVisuals(double size) {
    final quadrants = [
      _QuadrantData(
        group: FoodGroup.frutasVerduras,
        clip: _TopClipper(),
        alignment: const Alignment(0, -0.55),
        labelAlign: const Alignment(0, -0.85),
      ),
      _QuadrantData(
        group: FoodGroup.alimentosAnimal,
        clip: _RightWedgeClipper(),
        alignment: const Alignment(0.55, 0.40),
        labelAlign: const Alignment(0.72, 0.62),
      ),
      _QuadrantData(
        group: FoodGroup.leguminosas,
        clip: _BottomWedgeClipper(),
        alignment: const Alignment(0, 0.58),
        labelAlign: const Alignment(0, 0.86),
      ),
      _QuadrantData(
        group: FoodGroup.cerealesTuberculos,
        clip: _LeftWedgeClipper(),
        alignment: const Alignment(-0.55, 0.40),
        labelAlign: const Alignment(-0.72, 0.62),
      ),
    ];

    return quadrants.map((q) {
      final feedback = _sectionFeedback[q.group];
      final placed = _placed[q.group]!;
      final hovering = _hoveringGroup == q.group;

      return IgnorePointer(
        child: ClipPath(
          clipper: q.clip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: feedback == true
                  ? const Color(0xFF4CAF3D).withOpacity(0.55)
                  : feedback == false
                      ? Colors.red.withOpacity(0.35)
                      : hovering
                          ? q.group.color.withOpacity(1.0)
                          : q.group.color.withOpacity(0.85),
            ),
            child: Stack(
              children: [
                // Etiqueta del grupo
                Align(
                  alignment: q.labelAlign,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      q.group.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: q.group.labelColor,
                        fontWeight: FontWeight.w900,
                        fontSize: size * 0.034,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),

                // Alimentos ya colocados
                if (placed.isNotEmpty)
                  Align(
                    alignment: q.alignment,
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      alignment: WrapAlignment.center,
                      children: placed.take(6).map((f) => _buildTinyFood(f)).toList(),
                    ),
                  ),

                // Feedback de acierto/error
                if (feedback != null)
                  Align(
                    alignment: q.alignment,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, v, child) => Transform.scale(scale: v, child: child),
                      child: Text(feedback! ? '✅' : '❌', style: const TextStyle(fontSize: 30)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTinyFood(FoodItem food) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 3)],
      ),
      child: _foodWidget(food, size: 19),
    );
  }

  // ── BANCO DE ALIMENTOS ───────────────────────
  Widget _buildFoodBank() {
    if (_remaining.isEmpty) {
      return Center(
        child: Text('¡Todos colocados! 🎉',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1F6B1A))),
      );
    }

    final visible = _remaining.take(8).toList();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166).withOpacity(0.30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: Text(
                '🧺 Arrastra al grupo correcto del plato  •  ${_remaining.length} restantes',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, fontSize: 11, color: const Color(0xFFA85800)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: visible
                  .map((food) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _DraggableFoodCard(food: food),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── PANTALLA DE VICTORIA ─────────────────────
  Widget _buildWinScreen() {
    final perfect = _errors == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(perfect ? '🏆' : '🎉', style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 10),
                  Text(
                    perfect ? '¡Perfecto!' : '¡Lo lograste!',
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900, fontSize: 28, color: const Color(0xFF1A0A36)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Clasificaste todos los alimentos correctamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: const Color(0xFF3C2864).withOpacity(0.6)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6BA1), Color(0xFF7C3AED)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text('⭐ Puntos ganados',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('$_score pts',
                            style: GoogleFonts.nunito(
                                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 34)),
                      ],
                    ),
                  ),
                  if (_errors > 0) ...[
                    const SizedBox(height: 10),
                    Text('Intentos extra: $_errors',
                        style: TextStyle(color: const Color(0xFF3C2864).withOpacity(0.5), fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        label: '🔁 Jugar de nuevo',
                        color: const Color(0xFF4ECB71),
                        onTap: _restart,
                      ),
                      const SizedBox(width: 12),
                      _ActionButton(
                        label: '🏠 Inicio',
                        color: const Color(0xFFFF6B9D),
                        onTap: () => Navigator.maybePop(context),
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

  Widget _foodWidget(FoodItem food, {double size = 32}) {
    if (food.imagePath != null) {
      return Image.asset(food.imagePath!, width: size, height: size, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(food.emoji, style: TextStyle(fontSize: size * 0.8)));
    }
    return Center(child: Text(food.emoji, style: TextStyle(fontSize: size * 0.8)));
  }
}

// ─────────────────────────────────────────────
// WIDGET TARJETA ARRASTRABLE
// ─────────────────────────────────────────────

class _DraggableFoodCard extends StatelessWidget {
  final FoodItem food;
  const _DraggableFoodCard({required this.food});

  Widget _foodWidget(FoodItem food, {double size = 38}) {
    if (food.imagePath != null) {
      return Image.asset(food.imagePath!, width: size, height: size, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(food.emoji, style: TextStyle(fontSize: size * 0.8)));
    }
    return Text(food.emoji, style: TextStyle(fontSize: size * 0.8));
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _foodWidget(food, size: 38),
          const SizedBox(height: 5),
          Text(
            food.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF444444)),
          ),
        ],
      ),
    );

    return Draggable<FoodItem>(
      data: food,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.15,
          child: Opacity(opacity: 0.95, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }
}

// ─────────────────────────────────────────────
// BOTÓN DE ACCIÓN
// ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Text(label,
            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLIPPERS PARA LOS CUADRANTES DEL PLATO
//
// IMPORTANTE: estos ángulos coinciden EXACTAMENTE con los usados en
// _groupAtPosition (mismo sistema: 0°=derecha, 90°=abajo, 180°=izq,
// 270°=arriba). Si cambias uno, cambia el otro.
// ─────────────────────────────────────────────

// Mitad superior completa (180°–360°) -> Frutas y Verduras
class _TopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), pi, pi, false)
      ..close();
  }
  @override
  bool shouldReclip(_) => false;
}

// Cuña central inferior, 65°–115° -> Leguminosas
class _BottomWedgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), 65 * pi / 180, 50 * pi / 180, false)
      ..close();
  }
  @override
  bool shouldReclip(_) => false;
}

// Cuña inferior izquierda, 115°–180° -> Cereales
class _LeftWedgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), 115 * pi / 180, 65 * pi / 180, false)
      ..close();
  }
  @override
  bool shouldReclip(_) => false;
}

// Cuña inferior derecha, 0°–65° -> Origen Animal
class _RightWedgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), 0, 65 * pi / 180, false)
      ..close();
  }
  @override
  bool shouldReclip(_) => false;
}

// ─────────────────────────────────────────────
// BORDE EXTERIOR GRUESO POR SECCIÓN (estilo "Plato del Bien Comer")
// ─────────────────────────────────────────────

class _OuterRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final strokeW = r * 0.075;
    final rect = Rect.fromLTWH(
      strokeW / 2, strokeW / 2,
      size.width - strokeW, size.height - strokeW,
    );

    void drawArc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startDeg * pi / 180, sweepDeg * pi / 180, false, paint);
    }

    // Mismos ángulos que los clippers de cuadrantes, con un pequeño
    // hueco (2°) entre secciones para separación visual tipo referencia.
    drawArc(181, 178, const Color(0xFF4CAF3D));   // Frutas y Verduras (arriba)
    drawArc(1, 63, const Color(0xFFE6483C));      // Origen Animal (der-abajo)
    drawArc(66, 48, const Color(0xFFE8C200));     // Leguminosas (centro-abajo)
    drawArc(116, 63, const Color(0xFFF5970A));    // Cereales (izq-abajo)
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// LÍNEAS DIVISORIAS BLANCAS ENTRE SECCIONES
// ─────────────────────────────────────────────

class _PlateDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Línea horizontal: separa la mitad superior de la inferior
    canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy), paint);

    // Dos líneas que delimitan la cuña central de leguminosas (65°/115°)
    Offset pointAt(double deg) {
      final rad = deg * pi / 180;
      return Offset(c.dx + r * cos(rad), c.dy + r * sin(rad));
    }

    canvas.drawLine(c, pointAt(65), paint);
    canvas.drawLine(c, pointAt(115), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// DATOS AUXILIARES
// ─────────────────────────────────────────────

class _QuadrantData {
  final FoodGroup group;
  final CustomClipper<Path> clip;
  final Alignment alignment;
  final Alignment labelAlign;

  const _QuadrantData({
    required this.group,
    required this.clip,
    required this.alignment,
    required this.labelAlign,
  });
}

class _BgDot {
  final Color color;
  final double x;
  final double y;
  final double size;
  final double phase;
  final double opacity;

  const _BgDot({
    required this.color,
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.opacity,
  });
}
