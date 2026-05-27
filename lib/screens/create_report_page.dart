import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/nutrition_service.dart';
import 'child_profile_page.dart'; 
import 'stats_page.dart';

class CreateReportPage extends StatefulWidget {
  final String  childId;
  final String  childName;
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
  ];
  late final List<_Dot> _dots;

  // ─── Servicio ─────────────────────────────────────────────────────────────
  final _nutritionService = NutritionService();

  // ─── Catálogo de comidas ──────────────────────────────────────────────────
  static const _meals = [
    {'l': 'Desayuno', 'icon': Icons.wb_sunny_rounded,   'c': Color(0xFFFF8C42)},
    {'l': 'Comida',   'icon': Icons.restaurant_rounded,  'c': Color(0xFF5DCCFF)},
    {'l': 'Cena',     'icon': Icons.nightlight_round,    'c': Color(0xFF7C3AED)},
    {'l': 'Snack',    'icon': Icons.cookie_outlined,     'c': Color(0xFFFF6BA1)},
  ];

  // ─── Estado principal ─────────────────────────────────────────────────────
  late String selectedMeal;
  bool isSaving   = false;
  bool isSearching = false;

  final List<FoodItem>        _addedFoods    = [];
  List<FoodItem>              _searchResults = [];
  bool                        _showResults   = false;

  // ─── Controladores de texto ───────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _obsCtrl    = TextEditingController();

  // ─── Campos adicionales del niño ─────────────────────────────────────────
  String   _childSex      = 'niño';
  double   _childWeight   = 0;
  String   _activityLevel = 'moderado';
  int      _waterGlasses  = 0;
  final    _weightCtrl    = TextEditingController();

  // ─── Alergias ─────────────────────────────────────────────────────────────
  final List<String> _selectedAllergies = [];
  static const _allergyOptions = [
    'Gluten', 'Lactosa', 'Mariscos', 'Nueces', 'Huevo', 'Soya', 'Ninguna',
  ];

  // ─── Totales ──────────────────────────────────────────────────────────────
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
    _dots = List.generate(20, (i) {
      final r = Random(i * 13 + 7);
      return _Dot(
        color:   _dotColors[r.nextInt(_dotColors.length)],
        x: r.nextDouble(), y: r.nextDouble(),
        size:    3 + r.nextDouble() * 5,
        phase:   rnd.nextDouble() * 2 * pi,
        opacity: 0.15 + r.nextDouble() * 0.25,
      );
    });
  }

  @override
  void dispose() {
    _bgCtrl?.dispose();
    _floatCtrl?.dispose();
    _searchCtrl.dispose();
    _obsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ─── BÚSQUEDA ─────────────────────────────────────────────────────────────
  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      _snack('Escribe al menos 2 caracteres para buscar', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { isSearching = true; _showResults = false; });
    try {
      final results = await _nutritionService.searchFoods(q);
      setState(() { _searchResults = results; _showResults = true; });
      if (results.isEmpty) _snack('No se encontraron resultados para "$q"');
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
      _showResults   = false;
      _searchCtrl.clear();
    });
    _snack('${food.name} agregado ✓');
  }

  void _removeFood(int i) => setState(() => _addedFoods.removeAt(i));

  // ─── GUARDAR ──────────────────────────────────────────────────────────────
  Future<void> _guardarReporte() async {
    if (_addedFoods.isEmpty) {
      _snack('Agrega al menos un alimento antes de guardar', isError: true);
      return;
    }
    setState(() => isSaving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Leer edad guardada del niño
      final childDoc = await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('children').doc(widget.childId).get();
      final childData = childDoc.data() ?? {};
      final int age   = (childData['edad'] ?? childData['age'] ?? 7).toInt();

      _snack('Analizando nutrición con IA...');

     final recommendation = await _nutritionService.generateRecommendation(
  childName:     widget.childName,
  childAge:      age,
  totalCalories: _totalCalories,
  totalProtein:  _totalProtein,
  totalCarbs:    _totalCarbs,
  totalFat:      _totalFat,
  waterGlasses:  _waterGlasses,
  foodsEaten:    _addedFoods.map((f) => f.name).toList(),
);

      final now        = DateTime.now();
      final reportData = <String, dynamic>{
        'childId':        widget.childId,
        'childName':      widget.childName,
        'meal':           selectedMeal,
        'foods':          _addedFoods.map((f) => f.toMap()).toList(),
        'totalCalories':  _totalCalories,
        'totalProtein':   _totalProtein,
        'totalCarbs':     _totalCarbs,
        'totalFat':       _totalFat,
        'waterGlasses':   _waterGlasses,
        'observations':   _obsCtrl.text,
        'recommendation': recommendation,
        'childSex':       _childSex,
        'activityLevel':  _activityLevel,
        'allergies':      _selectedAllergies,
        'timestamp':      FieldValue.serverTimestamp(),
        'fecha_rango':    '${now.day}/${now.month}/${now.year}',
      };

      await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('reports').add(reportData);

      final w = {'Desayuno': 1, 'Comida': 2, 'Cena': 3}[selectedMeal] ?? 1;
      await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('children').doc(widget.childId)
          .update({'progreso_hoy': FieldValue.increment(w * 20.0)});

      await _generarPDF(reportData, recommendation, age);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StatsPage(childId: widget.childId, childName: widget.childName),
        ),
      );
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────
  Future<void> _generarPDF(Map<String, dynamic> data, String rec, int age) async {
    final pdf  = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.all(30),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.deepPurple100,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('StarNutri — Reporte Nutricional',
                    style: pw.TextStyle(font: bold, fontSize: 22, color: PdfColors.deepPurple800)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Paciente: ${widget.childName}  |  $age años  |  ${data['childSex']}  |  '
                  'Comida: ${data['meal']}  |  Fecha: ${data['fecha_rango']}',
                  style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.deepPurple600)),
              ]),
            ),
            pw.SizedBox(height: 18),
            // Alimentos
            pw.Text('Alimentos registrados',
                style: pw.TextStyle(font: bold, fontSize: 15, color: PdfColors.deepPurple700)),
            pw.SizedBox(height: 8),
            ...(data['foods'] as List).map((f) {
              final fm = f as Map<String, dynamic>;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(
                    '+ ${fm['name']}  —  ${(fm['calories'] as num?)?.toInt() ?? 0} kcal  |  '
                    'P: ${((fm['protein'] as num?) ?? 0).toStringAsFixed(1)} g  '
                    'C: ${((fm['carbs']   as num?) ?? 0).toStringAsFixed(1)} g  '
                    'G: ${((fm['fat']     as num?) ?? 0).toStringAsFixed(1)} g',
                    style: pw.TextStyle(font: font, fontSize: 12)),
                ),
              );
            }),
            pw.SizedBox(height: 14),
            // Resumen
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blue200)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Resumen Nutricional',
                    style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.blue800)),
                pw.SizedBox(height: 8),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                  _pdfBadge(font, bold, '${_totalCalories.toInt()}', 'kcal', PdfColors.pink400),
                  _pdfBadge(font, bold, '${_totalProtein.toStringAsFixed(1)} g', 'Proteína', PdfColors.deepPurple400),
                  _pdfBadge(font, bold, '${_totalCarbs.toStringAsFixed(1)} g', 'Carbos', PdfColors.lightBlue400),
                  _pdfBadge(font, bold, '${_totalFat.toStringAsFixed(1)} g', 'Grasas', PdfColors.orange400),
                ]),
                pw.SizedBox(height: 8),
                pw.Text('Vasos de agua: ${data['waterGlasses']}  |  Actividad: ${data['activityLevel']}',
                    style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.blue700)),
              ]),
            ),
            if ((data['observations'] as String).isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Observaciones:', style: pw.TextStyle(font: bold, fontSize: 13)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: PdfColors.yellow50, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text(data['observations'], style: pw.TextStyle(font: font, fontSize: 12)),
              ),
            ],
            pw.SizedBox(height: 14),
            // Recomendación IA
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green200)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Recomendación StarNutri IA:',
                    style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.green800)),
                pw.SizedBox(height: 6),
                pw.Text(rec, style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 3)),
              ]),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Generado por StarNutri App',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey500)),
            ),
          ],
        ),
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'StarNutri_${widget.childName}_${data['meal']}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _pdfBadge(pw.Font f, pw.Font b, String val, String lbl, PdfColor c) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(color: c, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(children: [
        pw.Text(val,  style: pw.TextStyle(font: b, fontSize: 13, color: PdfColors.white)),
        pw.Text(lbl,  style: pw.TextStyle(font: f, fontSize: 8,  color: PdfColors.white)),
      ]),
    );

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

  Widget _buildBg() => AnimatedBuilder(
    animation: _bgCtrl!,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: const [Color(0xFFD4F4DD), Color(0xFFFFF9E6), Color(0xFFFFD7A5), Color(0xFFE0F2E9)],
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
          left: d.x * size.width, top: d.y * size.height + dy,
          child: Opacity(opacity: d.opacity,
            child: Container(width: d.size, height: d.size,
              decoration: BoxDecoration(color: d.color, shape: BoxShape.circle))),
        );
      }).toList(),
    ),
  );

  // ─── APP BAR ──────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final meal  = _meals.firstWhere((m) => m['l'] == selectedMeal, orElse: () => _meals.first);
    final color = meal['c'] as Color;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.4))),
          ),
          child: Row(
            children: [
              _glassCircle(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: _dark),
              )),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('Registrar comida', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _dark)),
                  Text(widget.childName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark.withOpacity(0.55))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.40)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(meal['icon'] as IconData, color: color, size: 15),
                  const SizedBox(width: 5),
                  Text(selectedMeal, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── LOADING ──────────────────────────────────────────────────────────────
  Widget _buildLoading() => Center(
    child: _glass(radius: 24, pad: 32, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_purple), strokeWidth: 3),
        const SizedBox(height: 22),
        const Icon(Icons.auto_awesome_rounded, size: 40, color: _purple),
        const SizedBox(height: 12),
        Text('Analizando la nutrición\nde ${widget.childName}...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
        const SizedBox(height: 8),
        Text('Esto puede tomar unos segundos',
            style: TextStyle(fontSize: 14, color: _dark.withOpacity(0.5), fontWeight: FontWeight.w500)),
      ],
    )),
  );

  // ─── FORMULARIO ───────────────────────────────────────────────────────────
  Widget _buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // 1. TIPO DE COMIDA
      _sectionLabel('Tipo de comida', Icons.restaurant_menu_rounded),
      const SizedBox(height: 12),
      _buildMealSelector(),
      const SizedBox(height: 28),

      // 2. PERFIL DEL NIÑO
      _sectionLabel('Perfil del niño', Icons.child_care_rounded),
      const SizedBox(height: 12),
      _buildChildProfile(),
      const SizedBox(height: 28),

      // 3. ALERGIAS
      _sectionLabel('Alergias / Intolerancias', Icons.warning_amber_rounded),
      const SizedBox(height: 12),
      _buildAllergies(),
      const SizedBox(height: 28),

      // 4. BÚSQUEDA DE ALIMENTOS
      _sectionLabel('Buscar y agregar alimentos', Icons.search_rounded),
      const SizedBox(height: 12),
      _buildSearchSection(),
      const SizedBox(height: 20),

      // 5. ALIMENTOS AGREGADOS
      if (_addedFoods.isNotEmpty) ...[
        _sectionLabel('Alimentos registrados (${_addedFoods.length})', Icons.check_circle_outline_rounded),
        const SizedBox(height: 12),
        _buildAddedFoods(),
        const SizedBox(height: 14),
        _buildNutritionSummary(),
        const SizedBox(height: 28),
      ],

      // 6. HIDRATACIÓN
      _sectionLabel('Hidratación del día', Icons.water_drop_outlined),
      const SizedBox(height: 12),
      _buildWaterSelector(),
      const SizedBox(height: 28),

      // 7. OBSERVACIONES
      _sectionLabel('Observaciones del padre/madre', Icons.notes_rounded),
      const SizedBox(height: 12),
      _glassTextField(_obsCtrl,
        '¿Comió con apetito? ¿Tuvo alguna molestia? ¿Algo inusual...'),
      const SizedBox(height: 36),

      // 8. BOTÓN GUARDAR
      _buildSaveButton(),
    ],
  );

  // ─── SELECTOR DE COMIDA ───────────────────────────────────────────────────
  Widget _buildMealSelector() {
    final locked = widget.comidaInicial != null;
    return Row(
      children: _meals.map((m) {
        final label    = m['l'] as String;
        final icon     = m['icon'] as IconData;
        final accent   = m['c'] as Color;
        final sel      = selectedMeal == label;
        final disabled = locked && !sel;

        return Expanded(
          child: GestureDetector(
            onTap: locked ? null : () => setState(() => selectedMeal = label),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: disabled ? 0.3 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? accent.withOpacity(0.22) : Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel ? accent.withOpacity(0.65) : Colors.white.withOpacity(0.5),
                          width: sel ? 2 : 1),
                      ),
                      child: Column(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(sel ? 0.20 : 0.10),
                            borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, color: sel ? accent : _dark.withOpacity(0.4), size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(label, style: TextStyle(
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                            color: sel ? accent : _dark.withOpacity(0.6))),
                      ]),
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

  // ─── PERFIL DEL NIÑO ──────────────────────────────────────────────────────
// ─── PERFIL DEL NIÑO ──────────────────────────────────────────────────────
  Widget _buildChildProfile() => _glass(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Encabezado con título y botón de edición permanente
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Sexo del niño', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildProfilePage(
                    childId:   widget.childId,
                    childName: widget.childName,
                    isUpdate:  true, // Perfil ya existente, vamos a actualizar
                  ),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, size: 18, color: _purple),
                const SizedBox(width: 4),
                Text(
                  'Editar Perfil Fijo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _purple),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(children: [
        _sexOption('niño',  Icons.face_rounded,          _blue),
        const SizedBox(width: 12),
        _sexOption('niña',  Icons.face_2_rounded,         _pink),
      ]),
      const SizedBox(height: 18),
      // Peso
      const Text('Peso aproximado (kg)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
        ),
        child: TextField(
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _dark),
          decoration: InputDecoration(
            hintText: 'Ej: 25.5  (opcional)',
            hintStyle: TextStyle(color: _dark.withOpacity(0.35), fontSize: 13),
            prefixIcon: Icon(Icons.monitor_weight_outlined, color: _purple.withOpacity(0.6), size: 20),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: _dark.withOpacity(0.45), fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
      const SizedBox(height: 18),
      // Actividad
      const Text('Nivel de actividad física', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
      const SizedBox(height: 10),
      Row(children: [
        _activityOption('bajo',     'Poco activo',  Icons.airline_seat_recline_normal_rounded, _orange),
        const SizedBox(width: 8),
        _activityOption('moderado', 'Moderado',     Icons.directions_walk_rounded,             _green),
        const SizedBox(width: 8),
        _activityOption('alto',     'Muy activo',   Icons.directions_run_rounded,              _purple),
      ]),
    ]),
  );

  Widget _sexOption(String value, IconData icon, Color color) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _childSex = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _childSex == value ? color.withOpacity(0.18) : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _childSex == value ? color.withOpacity(0.60) : Colors.white.withOpacity(0.5),
            width: _childSex == value ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: _childSex == value ? color : _dark.withOpacity(0.35), size: 24),
          const SizedBox(height: 4),
          Text(value.capitalize(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _childSex == value ? color : _dark.withOpacity(0.55))),
        ]),
      ),
    ),
  );

  Widget _activityOption(String value, String label, IconData icon, Color color) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _activityLevel = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _activityLevel == value ? color.withOpacity(0.18) : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _activityLevel == value ? color.withOpacity(0.60) : Colors.white.withOpacity(0.5),
            width: _activityLevel == value ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: _activityLevel == value ? color : _dark.withOpacity(0.35), size: 20),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _activityLevel == value ? color : _dark.withOpacity(0.5))),
        ]),
      ),
    ),
  );

  // ─── ALERGIAS ─────────────────────────────────────────────────────────────
  Widget _buildAllergies() => _glass(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Selecciona si aplica',
          style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.55))),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _allergyOptions.map((a) {
          final sel = _selectedAllergies.contains(a);
          return GestureDetector(
            onTap: () => setState(() {
              if (a == 'Ninguna') {
                _selectedAllergies.clear();
              } else {
                _selectedAllergies.remove('Ninguna');
                sel ? _selectedAllergies.remove(a) : _selectedAllergies.add(a);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _pink.withOpacity(0.18) : Colors.white.withOpacity(0.30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? _pink.withOpacity(0.65) : Colors.white.withOpacity(0.6),
                  width: sel ? 2 : 1),
              ),
              child: Text(a, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: sel ? _pink : _dark.withOpacity(0.6))),
            ),
          );
        }).toList(),
      ),
    ]),
  );

  // ─── BÚSQUEDA CON BOTÓN ───────────────────────────────────────────────────
  Widget _buildSearchSection() => Column(
    children: [
      // Campo de búsqueda + botón
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.30),
                    border: Border.all(color: Colors.white.withOpacity(0.55)),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _doSearch(),
                    style: const TextStyle(color: _dark, fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Ej: manzana, pollo, arroz...',
                      hintStyle: TextStyle(color: _dark.withOpacity(0.38), fontSize: 14),
                      prefixIcon: Icon(Icons.restaurant_menu_rounded,
                          color: _mid.withOpacity(0.55), size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  color: _dark.withOpacity(0.4), size: 18),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _searchResults = [];
                                _showResults   = false;
                              }))
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ),
          ),
          // BOTÓN BUSCAR
          GestureDetector(
            onTap: isSearching ? null : _doSearch,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSearching ? _purple.withOpacity(0.5) : _purple,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: isSearching
                  ? const SizedBox(width: 20, height: 20,
                      child: Center(child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text('Buscar', style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    ]),
            ),
          ),
        ],
      ),
      // Hint informativo
      if (!_showResults && _addedFoods.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: _dark.withOpacity(0.40)),
            const SizedBox(width: 6),
            Text('Escribe el nombre del alimento y toca Buscar',
                style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.45))),
          ]),
        ),
      // Resultados
      if (_showResults) ...[
        const SizedBox(height: 10),
        if (_searchResults.isEmpty)
          _glass(child: Column(children: [
            Icon(Icons.search_off_rounded, size: 36, color: _dark.withOpacity(0.30)),
            const SizedBox(height: 8),
            Text('Sin resultados. Intenta con otro término.',
                style: TextStyle(fontSize: 14, color: _dark.withOpacity(0.55))),
          ]))
        else
          _buildSearchResults(),
      ],
    ],
  );

  Widget _buildSearchResults() => ClipRRect(
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: () => _addFood(food),
                  leading: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.set_meal_rounded, color: _purple, size: 22),
                  ),
                  title: Text(food.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _dark)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 2),
                    Text('${food.calories.toInt()} kcal  |  Prot: ${food.protein.toStringAsFixed(1)} g  Carbs: ${food.carbs.toStringAsFixed(1)} g  Grasas: ${food.fat.toStringAsFixed(1)} g',
                        style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.55))),
                    const SizedBox(height: 2),
                    Text(food.servingDescription,
                        style: TextStyle(fontSize: 11, color: _dark.withOpacity(0.40))),
                  ]),
                  trailing: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _green.withOpacity(0.40)),
                    ),
                    child: const Icon(Icons.add_rounded, color: _green, size: 22),
                  ),
                ),
                if (!isLast) Divider(height: 1, color: Colors.white.withOpacity(0.5), indent: 16, endIndent: 16),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  );

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
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: _green.withOpacity(0.20), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.check_circle_rounded, color: _green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(food.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _dark)),
                    const SizedBox(height: 3),
                    Text('${food.calories.toInt()} kcal  |  Prot: ${food.protein.toStringAsFixed(1)} g  Carbs: ${food.carbs.toStringAsFixed(1)} g',
                        style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.55))),
                  ]),
                ),
                GestureDetector(
                  onTap: () => _removeFood(entry.key),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: _pink.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.remove_circle_outline_rounded, color: _pink.withOpacity(0.8), size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }).toList(),
  );

  // ─── RESUMEN NUTRICIONAL ──────────────────────────────────────────────────
  Widget _buildNutritionSummary() => _glass(
    radius: 20,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.bar_chart_rounded, color: _purple, size: 20),
        const SizedBox(width: 8),
        const Text('Resumen nutricional',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _dark)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _nutriBadge('${_totalCalories.toInt()}', 'kcal', _pink),
        _nutriBadge('${_totalProtein.toStringAsFixed(1)} g', 'Proteína', _purple),
        _nutriBadge('${_totalCarbs.toStringAsFixed(1)} g', 'Carbos', _blue),
        _nutriBadge('${_totalFat.toStringAsFixed(1)} g', 'Grasas', _orange),
      ]),
    ]),
  );

  Widget _nutriBadge(String value, String label, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.75), fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  // ─── HIDRATACIÓN ──────────────────────────────────────────────────────────
  Widget _buildWaterSelector() => _glass(
    radius: 20,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.water_drop_rounded, color: _blue, size: 20),
        const SizedBox(width: 8),
        Text('$_waterGlasses vasos hoy',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _blue)),
        const Spacer(),
        if (_waterGlasses > 0)
          GestureDetector(
            onTap: () => setState(() => _waterGlasses = 0),
            child: Text('Reiniciar', style: TextStyle(fontSize: 12, color: _pink, fontWeight: FontWeight.w700)),
          ),
      ]),
      const SizedBox(height: 6),
      Text('Meta recomendada: ${_waterGoal()} vasos/día',
          style: TextStyle(fontSize: 11, color: _dark.withOpacity(0.45))),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(8, (i) {
          final sel = (i + 1) <= _waterGlasses;
          return GestureDetector(
            onTap: () => setState(() => _waterGlasses = i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36, height: 44,
              decoration: BoxDecoration(
                color: sel ? _blue.withOpacity(0.25) : Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sel ? _blue.withOpacity(0.65) : Colors.white.withOpacity(0.5),
                  width: sel ? 2 : 1),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.water_drop_rounded,
                    size: sel ? 20 : 15,
                    color: sel ? _blue : _dark.withOpacity(0.25)),
                const SizedBox(height: 2),
                Text('${i + 1}', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: sel ? _blue : _dark.withOpacity(0.35))),
              ]),
            ),
          );
        }),
      ),
    ]),
  );

  String _waterGoal() {
    // Meta hídrica OMS aproximada por edad
    return '6-8';
  }

  // ─── BOTÓN GUARDAR ────────────────────────────────────────────────────────
  Widget _buildSaveButton() => Column(
    children: [
      SizedBox(
        width: double.infinity, height: 58,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _addedFoods.isEmpty ? Colors.grey.shade400 : Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: isSaving || _addedFoods.isEmpty ? null : _guardarReporte,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              _addedFoods.isEmpty
                  ? 'AGREGA ALIMENTOS PRIMERO'
                  : 'GUARDAR Y OBTENER ANÁLISIS IA',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          ]),
        ),
      ),
      if (_addedFoods.isEmpty) ...[
        const SizedBox(height: 8),
        Text('Busca y agrega al menos un alimento para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _dark.withOpacity(0.45))),
      ],
    ],
  );

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, IconData icon) => Row(children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: _purple.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: _purple, size: 16),
    ),
    const SizedBox(width: 10),
    Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _dark)),
  ]);

  Widget _glass({required Widget child, double radius = 20, double pad = 18}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
          ),
          child: child,
        ),
      ),
    );

  Widget _glassCircle({required Widget child}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: Center(child: child),
        ),
      ),
    );

  Widget _glassTextField(TextEditingController ctrl, String hint) =>
    ClipRRect(
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
            controller: ctrl, maxLines: 3,
            style: const TextStyle(color: _dark, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _dark.withOpacity(0.38), fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
        ),
      ),
    );

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      backgroundColor: isError ? _pink : _purple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: isError ? 3 : 2),
    ));
  }
}

// ─── Extension helper ────────────────────────────────────────────────────────
extension StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

// ─── Modelo de punto flotante ─────────────────────────────────────────────────
class _Dot {
  final Color color;
  final double x, y, size, phase, opacity;
  const _Dot({required this.color, required this.x, required this.y,
      required this.size, required this.phase, required this.opacity});
}
