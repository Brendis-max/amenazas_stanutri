import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with TickerProviderStateMixin {
  static const Color _dark   = Color(0xFF1A0A36);
  static const Color _mid    = Color(0xFF50288C);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _pink   = Color(0xFFFF6BA1);
  static const Color _blue   = Color(0xFF5DCCFF);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _green  = Color(0xFF4ECB71);

  late AnimationController _bgCtrl;
  late AnimationController _floatCtrl;

  final List<Color> _dotColors = const [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
  ];
  late final List<_Dot> _dots;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    final rnd = Random();
    _dots = List.generate(22, (i) {
      final r = Random(i * 13 + 5);
      return _Dot(color: _dotColors[r.nextInt(_dotColors.length)], x: r.nextDouble(), y: r.nextDouble(),
          size: 3 + r.nextDouble() * 5, phase: rnd.nextDouble() * 2 * pi, opacity: 0.18 + r.nextDouble() * 0.28);
    });
    _generateFromReports();
  }

  @override
  void dispose() { _bgCtrl.dispose(); _floatCtrl.dispose(); super.dispose(); }

  Future<void> _generateFromReports() async {
    final notifRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications');
    final existing = await notifRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final reports = await FirebaseFirestore.instance
        .collection('users').doc(userId).collection('reports')
        .orderBy('timestamp', descending: true).limit(5).get();

    final batch = FirebaseFirestore.instance.batch();
    final now   = DateTime.now();

    batch.set(notifRef.doc(), {
      'title': 'Bienvenido a StarNutri',
      'body':  'Comienza a registrar la alimentación de tu pequeño hoy.',
      'type':  'welcome', 'read': false,
      'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
    });

    for (final doc in reports.docs) {
      final d = doc.data();
      final childName = d['childName'] ?? 'tu hijo';
      final meal      = d['meal']      ?? 'comida';
      final cal       = (d['totalCalories'] ?? 0).toInt();
      final reco      = (d['recommendation'] ?? '').toString();
      batch.set(notifRef.doc(), {
        'title':     'Reporte de $meal — $childName',
        'body':      reco.isNotEmpty ? (reco.length > 100 ? '${reco.substring(0, 100)}...' : reco) : 'Se registraron $cal kcal en $meal.',
        'type':      'report', 'childName': childName, 'read': false,
        'timestamp': d['timestamp'] ?? Timestamp.now(),
      });
    }
    await batch.commit();
  }

  Future<void> _markRead(String docId) async =>
      FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').doc(docId).update({'read': true});

  Future<void> _markAllRead() async {
    final all = await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in all.docs) batch.update(doc.reference, {'read': true});
    await batch.commit();
  }

  Future<void> _delete(String docId) async =>
      FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').doc(docId).delete();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        _buildBg(),
        _buildDots(size),
        SafeArea(child: Column(children: [_buildAppBar(), Expanded(child: _buildList())])),
      ]),
    );
  }

  Widget _buildBg() => AnimatedBuilder(
    animation: _bgCtrl,
    builder: (_, __) => Container(decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: const [Color(0xFFD4F4DD), Color(0xFFFFF9E6), Color(0xFFFFD7A5), Color(0xFFE0F2E9)],
      transform: GradientRotation(_bgCtrl.value * 2 * pi),
    ))),
  );

  Widget _buildDots(Size size) => AnimatedBuilder(
    animation: _floatCtrl,
    builder: (_, __) => Stack(children: _dots.map((d) {
      final dy = sin(_floatCtrl.value * 2 * pi + d.phase) * 10;
      return Positioned(left: d.x * size.width, top: d.y * size.height + dy,
        child: Opacity(opacity: d.opacity, child: Container(width: d.size, height: d.size, decoration: BoxDecoration(color: d.color, shape: BoxShape.circle))));
    }).toList()),
  );

  Widget _buildAppBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').where('read', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        final unread = snapshot.data?.docs.length ?? 0;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.4))),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('Notificaciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _dark)),
                  if (unread > 0)
                    Text('$unread sin leer', style: const TextStyle(fontSize: 13, color: _purple, fontWeight: FontWeight.w700)),
                ])),
                if (unread > 0)
                  GestureDetector(
                    onTap: _markAllRead,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _purple.withOpacity(0.30)),
                      ),
                      child: const Text('Marcar todas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _mid)),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_purple)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _buildCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildCard(String docId, Map<String, dynamic> data) {
    final bool     read    = data['read'] == true;
    final String   title   = data['title']    ?? 'Notificación';
    final String   body    = data['body']     ?? '';
    final String   type    = data['type']     ?? 'info';
    final Timestamp? ts    = data['timestamp'] as Timestamp?;
    final String timeStr   = ts != null ? _formatTime(ts.toDate()) : '';
    final Map<String, dynamic> cfg = _typeConfig(type);
    final Color    color   = cfg['color'] as Color;
    final IconData icon    = cfg['icon']  as IconData;

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: _pink.withOpacity(0.20), borderRadius: BorderRadius.circular(22)),
        child: const Icon(Icons.delete_outline_rounded, color: _pink, size: 26),
      ),
      onDismissed: (_) => _delete(docId),
      child: GestureDetector(
        onTap: () => _markRead(docId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: read ? Colors.white.withOpacity(0.14) : color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: read ? Colors.white.withOpacity(0.35) : color.withOpacity(0.35), width: read ? 1 : 1.5),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: read ? FontWeight.w600 : FontWeight.w900, color: _dark))),
                      if (!read) Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    ]),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(body, style: TextStyle(fontSize: 13, height: 1.5, color: _dark.withOpacity(0.65), fontWeight: FontWeight.w500)),
                    ],
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(timeStr, style: TextStyle(fontSize: 11, color: _dark.withOpacity(0.40), fontWeight: FontWeight.w600)),
                    ],
                  ])),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.55))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: _purple.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.notifications_none_rounded, size: 36, color: _purple.withOpacity(0.6))),
            const SizedBox(height: 16),
            const Text('Sin notificaciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _dark)),
            const SizedBox(height: 8),
            Text('Aquí aparecerán alertas\ny recomendaciones de tus reportes',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: _dark.withOpacity(0.55), fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    ),
  ));

  Map<String, dynamic> _typeConfig(String type) {
    switch (type) {
      case 'report':  return {'color': _purple, 'icon': Icons.receipt_long_rounded};
      case 'welcome': return {'color': _green,  'icon': Icons.waving_hand_rounded};
      case 'alert':   return {'color': _pink,   'icon': Icons.warning_amber_rounded};
      case 'tip':     return {'color': _orange, 'icon': Icons.lightbulb_outline_rounded};
      default:        return {'color': _blue,   'icon': Icons.info_outline_rounded};
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays    < 7)  return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Dot {
  final Color color; final double x, y, size, phase, opacity;
  const _Dot({required this.color, required this.x, required this.y, required this.size, required this.phase, required this.opacity});
}
