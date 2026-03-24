import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'stats_page.dart';
import 'create_report_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

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
  AnimationController? _bgCtrl;
  AnimationController? _floatCtrl;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
    Color(0xFFEF476F), Color(0xFF06D6A0), Color(0xFF118AB2),
  ];
  late final List<_Dot> _dots;

  String? selectedChildId;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    final rnd = Random();
    _dots = List.generate(30, (i) {
      final r = Random(i * 17 + 3);
      return _Dot(
        color:   _dotColors[r.nextInt(_dotColors.length)],
        x: r.nextDouble(), y: r.nextDouble(),
        size:    3 + r.nextDouble() * 5,
        phase:   rnd.nextDouble() * 2 * pi,
        opacity: 0.25 + r.nextDouble() * 0.35,
      );
    });
  }

  @override
  void dispose() {
    _bgCtrl?.dispose();
    _floatCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bgCtrl == null || _floatCtrl == null) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _buildBg(),
          _buildDots(size),
          _buildBody(),
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
      );

  // ─── BODY ─────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(userId).collection('children').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar datos'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(_purple)));
          }

          final children = snapshot.data!.docs;
          if (children.isEmpty) {
            return const Center(child: Text('No hay hijos registrados'));
          }

          QueryDocumentSnapshot? curr;
          if (selectedChildId == null) {
            curr = children.first;
          } else {
            try {
              curr = children.firstWhere((d) => d.id == selectedChildId);
            } catch (_) {
              curr = children.first;
            }
          }

          final data  = curr.data() as Map<String, dynamic>;
          final name  = data['name']  ?? data['nombre'] ?? 'Mi pequeño';
          final cId   = curr.id;
          final prog  = (data['progreso_hoy'] ?? 0).toDouble().clamp(0.0, 100.0) / 100;

          return Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      _sectionLabel('Seleccionar niño'),
                      const SizedBox(height: 12),
                      _buildChildSelector(children, cId),
                      const SizedBox(height: 24),
                      _buildProgressCard(name, prog),
                      const SizedBox(height: 24),
                      _sectionLabel('Registrar comidas de hoy'),
                      const SizedBox(height: 12),
                      _buildFoodGrid(cId, name),
                      const SizedBox(height: 24),
                      _sectionLabel('Balance nutricional'),
                      const SizedBox(height: 12),
                      // ← Balance calculado desde reportes reales de Firestore
                      _buildBalanceFromFirestore(cId),
                      const SizedBox(height: 24),
                      _sectionLabel('Acciones rápidas'),
                      const SizedBox(height: 12),
                      _buildQuickActions(cId, name),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── APP BAR ──────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final user    = FirebaseAuth.instance.currentUser;
    final initial = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName![0].toUpperCase()
        : 'M';

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
              SizedBox(
                height: 36,
                child: Image.asset('assets/starnutri2.png', fit: BoxFit.contain),
              ),
              const Spacer(),
              _glassCircle(
                child: Stack(
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 22, color: _dark.withOpacity(0.75)),
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: _pink, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.22),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.55)),
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: _dark)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BIENVENIDA ───────────────────────────────────────────────────────────
  Widget _buildWelcomeCard() {
    final user  = FirebaseAuth.instance.currentUser;
    final name  = user?.displayName ?? 'Mamá';
    final h     = DateTime.now().hour;
    final greet = h < 12
        ? '¡Buenos días'
        : h < 19
            ? '¡Buenas tardes'
            : '¡Buenas noches';

    return _glass(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greet, $name! 👋',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: _dark)),
          const SizedBox(height: 8),
          Text('Cuida la alimentación de tu pequeñ@ hoy 🌟',
              style: TextStyle(
                  fontSize: 15,
                  color: _dark.withOpacity(0.70),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purple.withOpacity(0.28)),
            ),
            child: Text('⭐ StarNutri — Nutrición inteligente',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _mid)),
          ),
        ],
      ),
    );
  }

  // ─── SELECTOR NIÑOS ───────────────────────────────────────────────────────
  Widget _buildChildSelector(
      List<QueryDocumentSnapshot> children, String cId) {
    final colors = [_purple, _pink, _green, _blue, _orange];
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        itemBuilder: (context, i) {
          final d      = children[i].data() as Map<String, dynamic>;
          final id     = children[i].id;
          final nombre = d['name'] ?? d['nombre'] ?? 'Hijo';
          final sel    = id == cId;
          final Color c = colors[i % colors.length];

          return GestureDetector(
            onTap: () => setState(() => selectedChildId = id),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? c.withOpacity(0.20)
                          : Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? c.withOpacity(0.65)
                            : Colors.white.withOpacity(0.5),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: c.withOpacity(0.18),
                          child: Icon(Icons.child_care_rounded,
                              color: c, size: 19),
                        ),
                        const SizedBox(width: 10),
                        Text(nombre,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: sel
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: sel ? c : _dark,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── PROGRESO ─────────────────────────────────────────────────────────────
  Widget _buildProgressCard(String name, double progress) {
    final int   pct = (progress * 100).toInt();
    final Color bar = pct >= 75 ? _green : pct >= 40 ? _orange : _pink;

    return _glass(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Progreso de $name hoy',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _dark)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: bar.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bar.withOpacity(0.35)),
                ),
                child: Text('$pct%',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: bar)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 13,
              backgroundColor: Colors.white.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation(bar),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pct >= 75
                ? '¡Excelente día nutricional! 🎉'
                : pct >= 40
                    ? 'Van bien, sigan así 💪'
                    : 'Registra más comidas del día 📝',
            style: TextStyle(
                fontSize: 13,
                color: _dark.withOpacity(0.6),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ─── GRID COMIDAS ─────────────────────────────────────────────────────────
  Widget _buildFoodGrid(String cId, String cName) {
    final meals = [
      {'t': 'Desayuno', 'icon': Icons.wb_sunny_rounded,   'c': _orange},
      {'t': 'Comida',   'icon': Icons.restaurant_rounded,  'c': _blue},
      {'t': 'Cena',     'icon': Icons.nightlight_round,    'c': _purple},
      {'t': 'Snacks',   'icon': Icons.cookie_outlined,     'c': _pink},
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: meals.map((m) {
        final Color accent = m['c'] as Color;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateReportPage(
                childId:      cId,
                childName:    cName,
                comidaInicial: m['t'] as String,
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: accent.withOpacity(0.32), width: 1.2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(m['icon'] as IconData, color: accent, size: 26),
                    ),
                    const SizedBox(height: 8),
                    
                    const SizedBox(height: 4),
                    Text(m['t'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _dark)),
                    const SizedBox(height: 2),
                    Text('Registrar +',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── BALANCE NUTRICIONAL — calculado desde reportes reales ───────────────
  // Lee los últimos 7 reportes del niño seleccionado y calcula el % real
  // de proteínas, carbohidratos, grasas y agua vs. los objetivos diarios.
  Widget _buildBalanceFromFirestore(String cId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reports')
          .where('childId', isEqualTo: cId)
          .orderBy('timestamp', descending: true)
          .limit(7)
          .snapshots(),
      builder: (context, snapshot) {
        // ── Mientras carga ─────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _glass(
            radius: 24,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(_purple)),
              ),
            ),
          );
        }

        // ── Sin datos todavía ──────────────────────────────────────────────
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _glass(
            radius: 24,
            child: Column(
              children: [
                const Text('📊', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text('Registra comidas para ver\nel balance nutricional',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: _dark.withOpacity(0.55),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        // ── Calcular totales de los reportes ──────────────────────────────
        double totalProt  = 0;
        double totalCarbs = 0;
        double totalFat   = 0;
        double totalCal   = 0;
        int    totalWater = 0;
        int    count      = snapshot.data!.docs.length;

        for (final doc in snapshot.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          totalProt  += (d['totalProtein']  ?? 0).toDouble();
          totalCarbs += (d['totalCarbs']    ?? 0).toDouble();
          totalFat   += (d['totalFat']      ?? 0).toDouble();
          totalCal   += (d['totalCalories'] ?? 0).toDouble();
          totalWater += (d['waterGlasses']  ?? 0) as int;
        }

        // Promedios diarios
        final avgProt  = totalProt  / count;
        final avgCarbs = totalCarbs / count;
        final avgFat   = totalFat   / count;
        final avgCal   = totalCal   / count;
        final avgWater = totalWater / count;

        // Referencias diarias para un niño promedio (7-10 años)
        // Proteínas: ~50 g/día, Carbs: ~130 g/día, Grasas: ~65 g/día
        // Agua: 6-8 vasos/día, Calorías: ~1600 kcal/día
        const double refProt  = 50.0;
        const double refCarbs = 130.0;
        const double refFat   = 65.0;
        const double refWater = 8.0;
        const double refCal   = 1600.0;

        final protPct  = (avgProt  / refProt ).clamp(0.0, 1.0);
        final carbsPct = (avgCarbs / refCarbs).clamp(0.0, 1.0);
        final fatPct   = (avgFat   / refFat  ).clamp(0.0, 1.0);
        final waterPct = (avgWater / refWater).clamp(0.0, 1.0);
        final calPct   = (avgCal   / refCal  ).clamp(0.0, 1.0);

        return _glass(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Promedio últimos $count días',
                      style: TextStyle(
                          fontSize: 13,
                          color: _dark.withOpacity(0.50),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _green.withOpacity(0.35)),
                    ),
                    child: Text('${avgCal.toInt()} kcal/día',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _green)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Círculos indicadores
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _circleIndicator('Proteínas', protPct,  _purple,
                      '${avgProt.toStringAsFixed(0)}g'),
                  _circleIndicator('Carbs',     carbsPct, _blue,
                      '${avgCarbs.toStringAsFixed(0)}g'),
                  _circleIndicator('Agua',      waterPct, _blue,
                      '${avgWater.toStringAsFixed(0)} v.'),
                ],
              ),
              const SizedBox(height: 18),
              // Barras
              _barItem('Calorías',  calPct,  _orange,
                  '${avgCal.toInt()} / ${refCal.toInt()} kcal'),
              _barItem('Grasas',    fatPct,  _pink,
                  '${avgFat.toStringAsFixed(1)} / ${refFat.toStringAsFixed(0)} g'),
            ],
          ),
        );
      },
    );
  }

  Widget _circleIndicator(
      String label, double val, Color color, String centerText) {
    return Column(
      children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            height: 64, width: 64,
            child: CircularProgressIndicator(
              value: val,
              strokeWidth: 6,
              backgroundColor: Colors.white.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(centerText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ]),
        const SizedBox(height: 7),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _dark.withOpacity(0.65))),
      ],
    );
  }

  Widget _barItem(String label, double val, Color color, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark)),
              const Spacer(),
              Text(detail,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: val,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACCIONES RÁPIDAS ─────────────────────────────────────────────────────
  Widget _buildQuickActions(String cId, String cName) => Column(
        children: [
          _actionCard(
            Icons.lightbulb_outline_rounded,
            'Aumentar frutas',
            '$cName necesita más porciones de fruta hoy',
            _orange,
          ),
          const SizedBox(height: 12),
          _actionCard(
            Icons.bar_chart_rounded,
            'Ver reportes y estadísticas',
            'Analiza el progreso semanal de $cName',
            _purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StatsPage(childId: cId, childName: cName),
              ),
            ),
          ),
        ],
      );

  Widget _actionCard(
    IconData icon,
    String title,
    String sub,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withOpacity(0.28), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _dark)),
                      const SizedBox(height: 3),
                      Text(sub,
                          style: TextStyle(
                              fontSize: 13,
                              color: _dark.withOpacity(0.60),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 15, color: color.withOpacity(0.70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 19, fontWeight: FontWeight.w900, color: _dark),
      );

  Widget _glass({required Widget child, double radius = 20, double pad = 20}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(radius),
            border:
                Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
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
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
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
