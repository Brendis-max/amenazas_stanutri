import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/nutrition_service.dart';
import 'stats_page.dart'; // ← IMPORTANTE: importa StatsPage

class CreateReportPage extends StatefulWidget {
  final String childId;
  final String childName;
  final String? comidaInicial;

  const CreateReportPage({
    super.key,
    required this.childId,
    required this.childName,
    this.comidaInicial,
  });

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage>
    with TickerProviderStateMixin {

  // ─── Paleta ───────────────────────────────────────────────────────────────
  static const Color _dark   = Color(0xFF1A0A36);
  static const Color _mid    = Color(0xFF50288C);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _pink   = Color(0xFFFF6BA1);
  static const Color _blue   = Color(0xFF5DCCFF);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _green  = Color(0xFF4ECB71);

  // ─── Animaciones ──────────────────────────────────────────────────────────
  AnimationController? _bgCtrl;
  AnimationController? _floatCtrl;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0),
  ];
  late final List<_Dot> _dots;

  // ─── Servicios ────────────────────────────────────────────────────────────
  final NutritionService _nutritionService = NutritionService();

  // ─── Estado ───────────────────────────────────────────────────────────────
  String selectedMeal = 'Desayuno';
  int    vasosAgua    = 0;
  bool   isSaving     = false;
  bool   isSearching  = false;

  final List<FoodItem>        _addedFoods    = [];
  final TextEditingController _searchCtrl    = TextEditingController();
  final TextEditingController _obsCtrl       = TextEditingController();
  List<FoodItem>              _searchResults = [];

  double get _totalCalories => _addedFoods.fold(0, (s, f) => s + f.calories);
  double get _totalProtein  => _addedFoods.fold(0, (s, f) => s + f.protein);
  double get _totalCarbs    => _addedFoods.fold(0, (s, f) => s + f.carbs);
  double get _totalFat      => _addedFoods.fold(0, (s, f) => s + f.fat);

  @override
  void initState() {
    super.initState();
    selectedMeal = widget.comidaInicial ?? 'Desayuno';
    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    final rnd = Random();
    _dots = List.generate(25, (i) {
      final r = Random(i * 13 + 7);
      return _Dot(
        color:   _dotColors[r.nextInt(_dotColors.length)],
        x: r.nextDouble(), y: r.nextDouble(),
        size:    3 + r.nextDouble() * 5,
        phase:   rnd.nextDouble() * 2 * pi,
        opacity: 0.20 + r.nextDouble() * 0.30,
      );
    });
  }

  @override
  void dispose() {
    _bgCtrl?.dispose();
    _floatCtrl?.dispose();
    _searchCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  // ─── BUSCAR ───────────────────────────────────────────────────────────────
  Future<void> _searchFood(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => isSearching = true);
    try {
      final results = await _nutritionService.searchFoods(query);
      setState(() => _searchResults = results);
    } catch (e) {
      _snack('Error al buscar: $e', isError: true);
    } finally {
      setState(() => isSearching = false);
    }
  }

  void _addFood(FoodItem food) {
    setState(() {
      _addedFoods.add(food);
      _searchResults = [];
      _searchCtrl.clear();
    });
    _snack('✅ ${food.name} agregado');
  }

  void _removeFood(int i) => setState(() => _addedFoods.removeAt(i));

  // ─── GUARDAR ──────────────────────────────────────────────────────────────
  Future<void> _guardarReporte() async {
    if (_addedFoods.isEmpty) {
      _snack('Agrega al menos un alimento', isError: true);
      return;
    }
    setState(() => isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Obtener edad del niño
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('children')
          .doc(widget.childId)
          .get();
      final childData = childDoc.data() ?? {};
      final int age = (childData['edad'] ?? childData['age'] ?? 7).toInt();

      _snack('Analizando la nutrición...');

      // 1) Generar recomendación de Claude
      final recommendation = await _nutritionService.generateRecommendation(
        childName:      widget.childName,
        childAge:       age,
        totalCalories:  _totalCalories,
        totalProtein:   _totalProtein,
        totalCarbs:     _totalCarbs,
        totalFat:       _totalFat,
        waterGlasses:   vasosAgua,
        foodsEaten:     _addedFoods.map((f) => f.name).toList(),
      );

      // 2) Construir mapa completo del reporte
      final now = DateTime.now();
      final reportData = <String, dynamic>{
        'childId':        widget.childId,
        'childName':      widget.childName,
        'meal':           selectedMeal,
        'foods':          _addedFoods.map((f) => f.toMap()).toList(),
        'totalCalories':  _totalCalories,
        'totalProtein':   _totalProtein,
        'totalCarbs':     _totalCarbs,
        'totalFat':       _totalFat,
        'waterGlasses':   vasosAgua,
        'observations':   _obsCtrl.text,
        'recommendation': recommendation,
        'timestamp':      FieldValue.serverTimestamp(),
        'fecha_rango':    '${now.day}/${now.month}/${now.year}',
      };

      // 3) Guardar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reports')
          .add(reportData);

      // 4) Actualizar progreso del niño
      final w = {'Desayuno': 1, 'Comida': 2, 'Cena': 3}[selectedMeal] ?? 1;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('children')
          .doc(widget.childId)
          .update({'progreso_hoy': FieldValue.increment(w * 20.0)});

      // 5) Mostrar PDF con TODOS los datos correctos (incluye recomendación)
      await _generarPDF(reportData, recommendation);

      if (!mounted) return;

      // 6) Navegar a StatsPage para ver el reporte guardado
      //    Reemplaza la pantalla actual para que el usuario vea sus reportes
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StatsPage(
            childId:   widget.childId,
            childName: widget.childName,
          ),
        ),
      );
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ─── PDF — con datos CORRECTOS ───────────────────────────────────────────
  Future<void> _generarPDF(
    Map<String, dynamic> data,
    String recommendation,
  ) async {
    final pdf  = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();

    // Extraer alimentos con tipos correctos desde el mapa guardado
    final List<dynamic> foods      = data['foods']          as List<dynamic>? ?? [];
    final double        totalCal   = (data['totalCalories'] ?? 0).toDouble();
    final double        totalProt  = (data['totalProtein']  ?? 0).toDouble();
    final double        totalCarbs = (data['totalCarbs']    ?? 0).toDouble();
    final double        totalFat   = (data['totalFat']      ?? 0).toDouble();
    final int           water      = (data['waterGlasses']  ?? 0) as int;
    final String        obs        = data['observations']   as String? ?? '';
    final String        fechaR     = data['fecha_rango']    as String? ?? '';
    final String        meal       = data['meal']           as String? ?? '';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.deepPurple100,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('⭐ StarNutri — Reporte Nutricional',
                      style: pw.TextStyle(
                          font: bold, fontSize: 24, color: PdfColors.deepPurple800)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Niño: ${widget.childName}  |  Fecha: $fechaR  |  Comida: $meal',
                    style: pw.TextStyle(
                        font: font, fontSize: 12, color: PdfColors.deepPurple600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 22),

            // ── Alimentos ───────────────────────────────────────────────────
            pw.Text('🍽️ Alimentos registrados:',
                style: pw.TextStyle(
                    font: bold, fontSize: 17, color: PdfColors.deepPurple700)),
            pw.SizedBox(height: 10),
            if (foods.isEmpty)
              pw.Text('No se registraron alimentos.',
                  style: pw.TextStyle(font: font, fontSize: 13, color: PdfColors.grey600))
            else
              ...foods.map((f) {
                final fm = f as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      '• ${fm['name'] ?? ''}  —  ${(fm['calories'] as num?)?.toInt() ?? 0} kcal  |  '
                      'P: ${((fm['protein'] as num?) ?? 0).toStringAsFixed(1)} g  '
                      'C: ${((fm['carbs']   as num?) ?? 0).toStringAsFixed(1)} g  '
                      'G: ${((fm['fat']     as num?) ?? 0).toStringAsFixed(1)} g',
                      style: pw.TextStyle(font: font, fontSize: 13),
                    ),
                  ),
                );
              }),

            pw.SizedBox(height: 18),

            // ── Totales ─────────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('📊 Resumen Nutricional Total',
                      style: pw.TextStyle(
                          font: bold, fontSize: 16, color: PdfColors.blue800)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _pdfBadge(font, bold, '${totalCal.toInt()}',
                          'kcal', PdfColors.pink400),
                      _pdfBadge(font, bold,
                          '${totalProt.toStringAsFixed(1)} g', 'Proteínas',
                          PdfColors.deepPurple400),
                      _pdfBadge(font, bold,
                          '${totalCarbs.toStringAsFixed(1)} g', 'Carbohidratos',
                          PdfColors.lightBlue400),
                      _pdfBadge(font, bold,
                          '${totalFat.toStringAsFixed(1)} g', 'Grasas',
                          PdfColors.orange400),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('💧 Vasos de agua: $water',
                      style: pw.TextStyle(
                          font: font, fontSize: 13, color: PdfColors.blue700)),
                ],
              ),
            ),

            // ── Observaciones ───────────────────────────────────────────────
            if (obs.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('📝 Observaciones:',
                  style: pw.TextStyle(font: bold, fontSize: 15)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.yellow50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(obs,
                    style: pw.TextStyle(font: font, fontSize: 13)),
              ),
            ],

            // ── Recomendación Claude ─────────────────────────────────────────
            if (recommendation.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.green200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('🤖 Recomendación StarNutri AI:',
                        style: pw.TextStyle(
                            font: bold, fontSize: 16, color: PdfColors.green800)),
                    pw.SizedBox(height: 8),
                    pw.Text(recommendation,
                        style: pw.TextStyle(
                            font: font, fontSize: 13, lineSpacing: 4)),
                  ],
                ),
              ),
            ],

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 5),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Generado por StarNutri App',
                  style: pw.TextStyle(
                      font: font, fontSize: 10, color: PdfColors.grey500)),
            ),
          ],
        ),
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
          'Reporte_${widget.childName}_${data['meal']}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _pdfBadge(
    pw.Font font,
    pw.Font bold,
    String value,
    String label,
    PdfColor color,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
          color: color, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Column(children: [
        pw.Text(value,
            style: pw.TextStyle(font: bold, fontSize: 15, color: PdfColors.white)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
      ]),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_bgCtrl == null || _floatCtrl == null) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          _buildBg(),
          _buildDots(size),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: isSaving
                      ? _buildLoading()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                          child: _buildForm(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FONDO ────────────────────────────────────────────────────────────────
  Widget _buildBg() => AnimatedBuilder(
        animation: _bgCtrl!,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFD4F4DD), Color(0xFFFFF9E6),
                Color(0xFFFFD7A5), Color(0xFFE0F2E9),
              ],
              transform: GradientRotation(_bgCtrl!.value * 2 * pi),
            ),
          ),
        ),
      );

  Widget _buildDots(Size size) => AnimatedBuilder(
        animation: _floatCtrl!,
        builder: (_, __) => Stack(
          children: _dots.map((d) {
            final dy = sin(_floatCtrl!.value * 2 * pi + d.phase) * 10;
            return Positioned(
              left: d.x * size.width,
              top: d.y * size.height + dy,
              child: Opacity(
                opacity: d.opacity,
                child: Container(
                    width: d.size,
                    height: d.size,
                    decoration: BoxDecoration(
                        color: d.color, shape: BoxShape.circle)),
              ),
            );
          }).toList(),
        ),
      );

  // ─── APP BAR ──────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.4))),
          ),
          child: Row(
            children: [
              _glassCircle(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 17, color: _dark),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Registrar comida',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: _dark)),
                    Text(widget.childName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _dark.withOpacity(0.55))),
                  ],
                ),
              ),
              if (_addedFoods.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _green.withOpacity(0.40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text('${_addedFoods.length}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _green)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── LOADING ──────────────────────────────────────────────────────────────
  Widget _buildLoading() => Center(
        child: _glass(
          radius: 24,
          pad: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(_purple), strokeWidth: 3),
              const SizedBox(height: 22),
              const Text('🤖', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                'Claude está analizando\nla nutrición de ${widget.childName}...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _dark),
              ),
              const SizedBox(height: 8),
              Text('Esto puede tomar unos segundos',
                  style: TextStyle(
                      fontSize: 14,
                      color: _dark.withOpacity(0.5),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );

  // ─── FORMULARIO ───────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🍽️ Tipo de comida'),
        const SizedBox(height: 12),
        _buildMealSelector(),
        const SizedBox(height: 24),

        _sectionLabel('🔍 Buscar alimento'),
        const SizedBox(height: 12),
        _buildSearchField(),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSearchResults(),
        ],
        const SizedBox(height: 20),

        if (_addedFoods.isNotEmpty) ...[
          _sectionLabel('✅ Alimentos registrados'),
          const SizedBox(height: 12),
          _buildAddedFoods(),
          const SizedBox(height: 14),
          _buildNutritionSummary(),
          const SizedBox(height: 24),
        ],

        _sectionLabel('💧 Hidratación del día'),
        const SizedBox(height: 12),
        _buildWaterSelector(),
        const SizedBox(height: 24),

        _sectionLabel('📝 Observaciones'),
        const SizedBox(height: 12),
        _glassTextField(_obsCtrl, 'Alguna nota adicional sobre la comida...'),
        const SizedBox(height: 32),

        _buildSaveButton(),
      ],
    );
  }

  // ─── SELECTOR COMIDA ──────────────────────────────────────────────────────
  Widget _buildMealSelector() {
    final meals = [
      {'l': 'Desayuno', 'e': '🌅', 'c': _orange},
      {'l': 'Comida',   'e': '🍽️', 'c': _blue},
      {'l': 'Cena',     'e': '🌙',  'c': _purple},
      {'l': 'Snack',    'e': '🍎',  'c': _pink},
    ];

    return Row(
      children: meals.map((m) {
        final bool sel     = selectedMeal == m['l'];
        final Color accent = m['c'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedMeal = m['l'] as String),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel
                          ? accent.withOpacity(0.22)
                          : Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: sel
                            ? accent.withOpacity(0.65)
                            : Colors.white.withOpacity(0.5),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(m['e'] as String,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 5),
                        Text(m['l'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color:
                                  sel ? accent : _dark.withOpacity(0.6),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── CAMPO BUSCAR ─────────────────────────────────────────────────────────
  Widget _buildSearchField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _searchFood,
            style: const TextStyle(
                color: _dark, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Ej: manzana, pollo, arroz...',
              hintStyle: TextStyle(
                  color: _dark.withOpacity(0.40), fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: _mid.withOpacity(0.65), size: 22),
              suffixIcon: isSearching
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(_purple)),
                      ),
                    )
                  : _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: _dark.withOpacity(0.4), size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchResults = []);
                          })
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.60)),
          ),
          child: Column(
            children: _searchResults.asMap().entries.map((entry) {
              final food   = entry.value;
              final isLast = entry.key == _searchResults.length - 1;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    onTap: () => _addFood(food),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Center(
                          child:
                              Text('🍴', style: TextStyle(fontSize: 20))),
                    ),
                    title: Text(food.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _dark)),
                    subtitle: Text(
                      '${food.calories.toInt()} kcal  |  P: ${food.protein.toStringAsFixed(1)} g  C: ${food.carbs.toStringAsFixed(1)} g  G: ${food.fat.toStringAsFixed(1)} g',
                      style: TextStyle(
                          fontSize: 13,
                          color: _dark.withOpacity(0.55),
                          fontWeight: FontWeight.w500),
                    ),
                    trailing: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: _green.withOpacity(0.35)),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: _green, size: 20),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.5),
                        indent: 16,
                        endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─── ALIMENTOS AGREGADOS ──────────────────────────────────────────────────
  Widget _buildAddedFoods() => Column(
        children: _addedFoods.asMap().entries.map((entry) {
          final food = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _green.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                            child: Text('✅',
                                style: TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(food.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: _dark)),
                            const SizedBox(height: 3),
                            Text(
                              '${food.calories.toInt()} kcal  |  Prot: ${food.protein.toStringAsFixed(1)} g',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _dark.withOpacity(0.60),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeFood(entry.key),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _pink.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: _pink.withOpacity(0.8),
                              size: 18),
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

  // ─── RESUMEN NUTRICIONAL ──────────────────────────────────────────────────
  Widget _buildNutritionSummary() => _glass(
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 Resumen nutricional',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16, color: _dark)),
            const SizedBox(height: 14),
            Row(
              children: [
                _nutriBadge('${_totalCalories.toInt()}', 'kcal', _pink),
                _nutriBadge(
                    '${_totalProtein.toStringAsFixed(1)} g', 'Prot', _purple),
                _nutriBadge(
                    '${_totalCarbs.toStringAsFixed(1)} g', 'Carb', _blue),
                _nutriBadge(
                    '${_totalFat.toStringAsFixed(1)} g', 'Gras', _orange),
              ],
            ),
          ],
        ),
      );

  Widget _nutriBadge(String value, String label, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.30)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  // ─── AGUA ─────────────────────────────────────────────────────────────────
  Widget _buildWaterSelector() => _glass(
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$vasosAgua vasos de agua',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _blue)),
                const Spacer(),
                if (vasosAgua > 0)
                  GestureDetector(
                    onTap: () => setState(() => vasosAgua = 0),
                    child: Text('Limpiar',
                        style: TextStyle(
                            fontSize: 13,
                            color: _pink,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(8, (i) {
                final bool sel = (i + 1) <= vasosAgua;
                return GestureDetector(
                  onTap: () => setState(() => vasosAgua = i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 42,
                    decoration: BoxDecoration(
                      color: sel
                          ? _blue.withOpacity(0.25)
                          : Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? _blue.withOpacity(0.65)
                            : Colors.white.withOpacity(0.5),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text('💧',
                          style:
                              TextStyle(fontSize: sel ? 18 : 14)),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      );

  // ─── CAMPO TEXTO ──────────────────────────────────────────────────────────
  Widget _glassTextField(TextEditingController ctrl, String hint) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: 3,
            style: const TextStyle(
                color: _dark, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: _dark.withOpacity(0.40), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
        ),
      ),
    );
  }

  // ─── BOTÓN GUARDAR ────────────────────────────────────────────────────────
  Widget _buildSaveButton() => SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: isSaving ? null : _guardarReporte,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('🤖', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Text('GUARDAR Y OBTENER RECOMENDACIÓN',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4)),
            ],
          ),
        ),
      );

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: _dark),
      );

  Widget _glass({required Widget child, double radius = 20, double pad = 18}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
                color: Colors.white.withOpacity(0.55), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassCircle({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      backgroundColor: isError ? _pink : _purple,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

class _Dot {
  final Color  color;
  final double x, y, size, phase, opacity;
  const _Dot({
    required this.color,
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.opacity,
  });
}
