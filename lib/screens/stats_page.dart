import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StatsPage extends StatefulWidget {
  final String childId;
  final String childName;

  const StatsPage({super.key, required this.childId, required this.childName});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with TickerProviderStateMixin {

  // ─── Paleta ───────────────────────────────────────────────────────────────
  static const Color _dark   = Color(0xFF1A0A36);
  static const Color _mid    = Color(0xFF50288C);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _pink   = Color(0xFFFF6BA1);
  static const Color _blue   = Color(0xFF5DCCFF);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _green  = Color(0xFF4ECB71);
  static const Color _yellow = Color(0xFFFFD166);

  // ─── Animaciones ──────────────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late AnimationController _floatCtrl;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF118AB2),
  ];
  late final List<_Dot> _dots;

  // ─── Estado ───────────────────────────────────────────────────────────────
  late String selectedChildId   = widget.childId;
  late String selectedChildName = widget.childName;
  bool   mostrarTodos = false;
  String searchText   = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    final rnd = Random();
    _dots = List.generate(25, (i) {
      final r = Random(i * 11 + 3);
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
    _bgCtrl.dispose();
    _floatCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── PDF (sin emojis — usa texto plano para evitar "Unable to find font") ─
  Future<void> _abrirPDF(Map<String, dynamic> report) async {
    final pdf  = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();

    final List   foods  = report['foods']          ?? [];
    final String child  = report['childName']      ?? selectedChildName;
    final String meal   = report['meal']           ?? '';
    final String fecha  = report['fecha_rango']    ?? 'Hoy';
    final String reco   = report['recommendation'] ?? '';
    final double totalCal   = (report['totalCalories'] ?? 0).toDouble();
    final double totalProt  = (report['totalProtein']  ?? 0).toDouble();
    final double totalCarbs = (report['totalCarbs']    ?? 0).toDouble();
    final double totalFat   = (report['totalFat']      ?? 0).toDouble();
    final int    water  = (report['waterGlasses']  ?? 0) as int;
    final String obs    = (report['observations']  ?? '').toString();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ── Header ──────────────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.deepPurple100,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('StarNutri — Reporte Nutricional',
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 24,
                            color: PdfColors.deepPurple800)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Nino: $child  |  Fecha: $fecha  |  Comida: $meal',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.deepPurple500),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 22),

              // ── Alimentos ───────────────────────────────────────────────
              pw.Text('Alimentos registrados:',
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 17,
                      color: PdfColors.deepPurple700)),
              pw.SizedBox(height: 10),

              if (foods.isEmpty)
                pw.Text('No se registraron alimentos.',
                    style: pw.TextStyle(
                        font: font, fontSize: 13, color: PdfColors.grey600))
              else
                ...foods.map((f) {
                  final fm = f as Map<String, dynamic>;
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 7),
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Text(
                      '+ ${fm['name'] ?? ''}  -  '
                      '${(fm['calories'] as num?)?.toInt() ?? 0} kcal  |  '
                      'Prot: ${((fm['protein'] as num?) ?? 0).toStringAsFixed(1)} g  '
                      'Carb: ${((fm['carbs']   as num?) ?? 0).toStringAsFixed(1)} g  '
                      'Gras: ${((fm['fat']     as num?) ?? 0).toStringAsFixed(1)} g',
                      style: pw.TextStyle(font: font, fontSize: 13),
                    ),
                  );
                }),

              pw.SizedBox(height: 20),

              // ── Resumen Nutricional ──────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Resumen Nutricional Total',
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 16,
                            color: PdfColors.blue800)),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _pdfBadge(font, bold,
                            '${totalCal.toInt()}', 'kcal', PdfColors.pink400),
                        _pdfBadge(font, bold,
                            '${totalProt.toStringAsFixed(1)} g', 'Proteinas',
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
                    pw.Text('Vasos de agua: $water',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 13,
                            color: PdfColors.blue700)),
                  ],
                ),
              ),

              // ── Observaciones ────────────────────────────────────────────
              if (obs.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text('Observaciones:',
                    style: pw.TextStyle(font: bold, fontSize: 15)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.yellow50,
                      borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text(obs,
                      style: pw.TextStyle(font: font, fontSize: 13)),
                ),
              ],

              // ── Recomendacion IA ─────────────────────────────────────────
              if (reco.isNotEmpty) ...[
                pw.SizedBox(height: 18),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.green200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Recomendacion StarNutri IA:',
                          style: pw.TextStyle(
                              font: bold,
                              fontSize: 16,
                              color: PdfColors.green800)),
                      pw.SizedBox(height: 10),
                      pw.Text(reco,
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
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Reporte_$child',
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
            style: pw.TextStyle(font: bold, fontSize: 14, color: PdfColors.white)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
      ]),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: Stack(
        children: [
          _buildBg(),
          _buildDots(size),
          SafeArea(
            child: Column(
  children: [
    _buildAppBar(),

    ///  TODO lo demás dentro de UN SOLO SCROLL
    Expanded(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildSearchBar(),
          const SizedBox(height: 8),

          _buildChildrenSelector(userId),
          const SizedBox(height: 8),

          _buildFilters(),

          /// ✅ YA NO EMPUJA
          _buildWeeklySummary(userId),

          const SizedBox(height: 10),

          /// ✅ TODAS las cards quedan alineadas
          _buildReportsList(userId),
        ],
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
        animation: _bgCtrl,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFD4F4DD), Color(0xFFFFF9E6),
                Color(0xFFFFD7A5), Color(0xFFE0F2E9),
              ],
              transform: GradientRotation(_bgCtrl.value * 2 * pi),
            ),
          ),
        ),
      );

  Widget _buildDots(Size size) => AnimatedBuilder(
        animation: _floatCtrl,
        builder: (_, __) => Stack(
          children: _dots.map((d) {
            final dy = sin(_floatCtrl.value * 2 * pi + d.phase) * 10;
            return Positioned(
              left: d.x * size.width,
              top:  d.y * size.height + dy,
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
             
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Reportes y estadísticas',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: _dark)),
                    Text(selectedChildName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _dark.withOpacity(0.55))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _purple.withOpacity(0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 13, color: _mid),
                    const SizedBox(width: 5),
                    Text('IA',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _mid)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BUSCADOR ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: ClipRRect(
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
                onChanged: (v) => setState(() => searchText = v),
                style: const TextStyle(
                    color: _dark, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Buscar reporte por nombre...',
                  hintStyle: TextStyle(
                      color: _dark.withOpacity(0.40), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: _mid.withOpacity(0.60), size: 22),
                  suffixIcon: searchText.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: _dark.withOpacity(0.4), size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => searchText = '');
                          })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
        ),
      );

  // ─── SELECTOR NIÑOS ───────────────────────────────────────────────────────
  Widget _buildChildrenSelector(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('children')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 46);
        final kids   = snapshot.data!.docs;
        final colors = [_purple, _pink, _green, _blue, _orange];

        return SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: kids.length,
            itemBuilder: (context, i) {
              final kid  = kids[i].data() as Map<String, dynamic>;
              final id   = kids[i].id;
              final name = kid['name'] ?? kid['nombre'] ?? 'Hijo';
              final sel  = selectedChildId == id;
              final Color c = colors[i % colors.length];

              return GestureDetector(
                onTap: () => setState(() {
                  selectedChildId   = id;
                  selectedChildName = name;
                  // Resetear filtro al cambiar de niño
                  mostrarTodos = false;
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? c.withOpacity(0.20)
                        : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: sel
                          ? c.withOpacity(0.65)
                          : Colors.white.withOpacity(0.5),
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Text(name,
                      style: TextStyle(
                        color:
                            sel ? c : _dark.withOpacity(0.7),
                        fontWeight: sel
                            ? FontWeight.w900
                            : FontWeight.w600,
                        fontSize: 14,
                      )),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── FILTROS ──────────────────────────────────────────────────────────────
  Widget _buildFilters() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _filterChip('Recientes', !mostrarTodos,
                () => setState(() => mostrarTodos = false)),
            const SizedBox(width: 12),
            _filterChip('Todos los niños', mostrarTodos,
                () => setState(() => mostrarTodos = true)),
          ],
        ),
      );

  Widget _filterChip(String text, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
            decoration: BoxDecoration(
              color: sel
                  ? _purple.withOpacity(0.20)
                  : Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: sel
                    ? _purple.withOpacity(0.55)
                    : Colors.white.withOpacity(0.45),
                width: sel ? 2 : 1,
              ),
            ),
            child: Text(text,
                style: TextStyle(
                    color: sel ? _purple : _dark.withOpacity(0.6),
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
        ),
      ),
    );
  }

  // ─── RESUMEN SEMANAL — SIEMPRE filtrado por niño seleccionado ────────────
  Widget _buildWeeklySummary(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reports')
          .where('childId', isEqualTo: selectedChildId) // ← siempre por niño
          .orderBy('timestamp', descending: true)
          .limit(14)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(height: 8);
        }

        double cal = 0, prot = 0, carbs = 0, fat = 0;
        int    water   = 0;
        String lastReco = '';

        for (final doc in snapshot.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          cal   += (d['totalCalories'] ?? 0).toDouble();
          prot  += (d['totalProtein']  ?? 0).toDouble();
          carbs += (d['totalCarbs']    ?? 0).toDouble();
          fat   += (d['totalFat']      ?? 0).toDouble();
          water += (d['waterGlasses']  ?? 0) as int;
          if (lastReco.isEmpty &&
              (d['recommendation'] ?? '').toString().isNotEmpty) {
            lastReco = d['recommendation'];
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _glass(
                radius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resumen semanal — $selectedChildName',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _dark)),
                    const SizedBox(height: 16),
                    _buildBarChart(cal, prot, carbs, fat),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statBadge('${cal.toInt()}', 'kcal', _pink),
                        _statBadge(
                            '${prot.toStringAsFixed(0)}g', 'Prot', _purple),
                        _statBadge(
                            '${carbs.toStringAsFixed(0)}g', 'Carb', _blue),
                        _statBadge('$water', 'Agua', _green),
                      ],
                    ),
                  ],
                ),
              ),
              if (lastReco.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildRecoCard(lastReco),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

Widget _buildBarChart(
    double cal, double prot, double carbs, double fat) {

  final double maxVal =
      [cal / 10, prot, carbs, fat].reduce((a, b) => a > b ? a : b);

  if (maxVal == 0) return const SizedBox(height: 100);

  final bars = [
    {'l': 'Kcal/10', 'v': cal / 10, 'c': _pink},
    {'l': 'Prot(g)', 'v': prot,     'c': _purple},
    {'l': 'Carb(g)', 'v': carbs,    'c': _blue},
    {'l': 'Gras(g)', 'v': fat,      'c': _orange},
  ];

  return SizedBox(
    height: 120, // ✅ MÁS ESPACIO (clave)
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((b) {
        final double ratio =
            ((b['v'] as double) / maxVal).clamp(0.0, 1.0);
        final Color color = b['c'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [

                /// 🔹 VALOR
                FittedBox(
                  child: Text(
                    '${(b['v'] as double).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                /// 🔹 BARRA
                Expanded( // ✅ ESTO ELIMINA EL OVERFLOW
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      width: 16,
                      height: (70 * ratio).clamp(6.0, 70.0),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                /// 🔹 LABEL
                FittedBox(
                  child: Text(
                    b['l'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _dark.withOpacity(0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
}

  Widget _buildRecoCard(String reco) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _purple.withOpacity(0.30), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 13, color: _mid),
                        const SizedBox(width: 5),
                        Text('StarNutri IA',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: _mid)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Última recomendación',
                      style: TextStyle(
                          fontSize: 13,
                          color: _dark.withOpacity(0.50),
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 12),
              Text(reco,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: _dark.withOpacity(0.82),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── LISTA REPORTES ───────────────────────────────────────────────────────
  // "Recientes" → solo del niño seleccionado
  // "Todos los niños" → sin filtro de childId
  Widget _buildReportsList(String userId) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reports');

    if (!mostrarTodos) {
      // Filtrar SIEMPRE por el niño seleccionado en el tab "Recientes"
      query = query.where('childId', isEqualTo: selectedChildId);
    }

    query = query.orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: _pink)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(_purple)));
        }

        var docs = snapshot.data!.docs;

        // Búsqueda por nombre si hay texto
        if (searchText.isNotEmpty) {
          docs = docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return (d['childName'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchText.toLowerCase());
          }).toList();
        }

        if (docs.isEmpty) return _buildEmptyState();
return Padding(
  padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
  child: Column(
    children: List.generate(docs.length, (i) {
      final report = docs[i].data() as Map<String, dynamic>;
      return _buildReportCard(report, i);
    }),
  ),
);
      },
    );
  }

  // ─── TARJETA REPORTE ──────────────────────────────────────────────────────
  Widget _buildReportCard(Map<String, dynamic> report, int index) {
    final List   foods  = report['foods']          ?? [];
    final String meal   = report['meal']           ?? 'Comida';
    final double cal    = (report['totalCalories'] ?? 0).toDouble();
    final double prot   = (report['totalProtein']  ?? 0).toDouble();
    final double carbs  = (report['totalCarbs']    ?? 0).toDouble();
    final String reco   = report['recommendation'] ?? '';
    final int    water  = (report['waterGlasses']  ?? 0) as int;

    // Usar IconData en lugar de emoji para evitar advertencias de fuente
    final mealIcon = {
      'Desayuno': Icons.wb_sunny_rounded,
      'Comida':   Icons.restaurant_rounded,
      'Cena':     Icons.nightlight_round,
      'Snack':    Icons.apple_rounded,
    }[meal] ?? Icons.fastfood_rounded;

    final cardColors = [_pink, _purple, _blue, _orange, _green];
    final Color color = cardColors[index % cardColors.length];

    return GestureDetector(
      onTap: () => _abrirPDF(report),
      child: Container(
        width: double.infinity, 
        margin: const EdgeInsets.only(bottom: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: color.withOpacity(0.28), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(mealIcon, color: color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$meal — ${report['childName'] ?? selectedChildName}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: _dark),
                            ),
                            const SizedBox(height: 3),
                            Text(report['fecha_rango'] ?? 'Hoy',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _dark.withOpacity(0.50),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      // Botón PDF
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: color.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded,
                                color: color, size: 15),
                            const SizedBox(width: 4),
                            Text('PDF',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Macros
                  Wrap(
                    spacing: 7, runSpacing: 6,
                    children: [
                      _miniBadge('${cal.toInt()} kcal', _pink),
                      _miniBadge('P: ${prot.toStringAsFixed(1)}g', _purple),
                      _miniBadge('C: ${carbs.toStringAsFixed(1)}g', _blue),
                      if (water > 0) _miniBadge('Agua: $water', _blue),
                    ],
                  ),

                  // Chips alimentos
                  if (foods.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7, runSpacing: 6,
                      children: foods.take(4).map((f) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.38),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.55)),
                            ),
                            child: Text(f['name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _dark)),
                          )).toList(),
                    ),
                  ],

                  // Preview recomendación
                  if (reco.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _purple.withOpacity(0.20)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 16, color: _mid),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reco.length > 100
                                  ? '${reco.substring(0, 100)}...'
                                  : reco,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: _dark.withOpacity(0.75),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 13, color: color.withOpacity(0.60)),
                      const SizedBox(width: 4),
                      Text('Toca para ver PDF completo',
                          style: TextStyle(
                              fontSize: 11,
                              color: color.withOpacity(0.70),
                              fontWeight: FontWeight.w700)),
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

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _glass(
            radius: 24, pad: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 52, color: _purple.withOpacity(0.5)),
                const SizedBox(height: 14),
                const Text('No hay reportes aún',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        color: _dark)),
                const SizedBox(height: 8),
                Text('Registra la primera comida\ndesde el dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: _dark.withOpacity(0.55),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  Widget _statBadge(String value, String label, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Column(children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: color)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _miniBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _glass(
      {required Widget child, double radius = 20, double pad = 18}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
