import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';
import 'stats_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> with TickerProviderStateMixin {

  static const Color _dark   = Color(0xFF1A0A36);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _pink   = Color(0xFFFF6BA1);

  int _selectedIndex = 0;

  late List<AnimationController> _iconCtrl;
  late List<Animation<double>>   _iconScale;

  @override
  void initState() {
    super.initState();
    _iconCtrl = List.generate(4, (i) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220),
    ));
    _iconScale = _iconCtrl.map((c) =>
      Tween<double>(begin: 1.0, end: 1.22).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut))).toList();
    _iconCtrl[0].forward();
  }

  @override
  void dispose() {
    for (final c in _iconCtrl) { c.dispose(); }
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _selectedIndex) return;
    _iconCtrl[_selectedIndex].reverse();
    _iconCtrl[index].forward();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      extendBody: true,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(userId).collection('children')
            .limit(1).snapshots(),
        builder: (context, snapshot) {
          final String firstChildId   = snapshot.data?.docs.isNotEmpty == true
              ? snapshot.data!.docs.first.id : 'default';
          final String firstChildName = snapshot.data?.docs.isNotEmpty == true
              ? ((snapshot.data!.docs.first.data() as Map<String, dynamic>)['name'] ?? 'Selecciona un hijo')
              : 'Selecciona un hijo';

          final pages = [
            const DashboardPage(),
            StatsPage(childId: firstChildId, childName: firstChildName),
            const NotificationsPage(),
            const ProfilePage(),
          ];

          return IndexedStack(index: _selectedIndex, children: pages);
        },
      ),
      bottomNavigationBar: _buildFloatingBar(userId),
    );
  }

  Widget _buildFloatingBar(String userId) {
    final items = [
      {'icon': Icons.home_rounded,          'label': 'Inicio'},
      {'icon': Icons.bar_chart_rounded,     'label': 'Stats'},
      {'icon': Icons.notifications_rounded, 'label': 'Avisos'},
      {'icon': Icons.person_rounded,        'label': 'Perfil'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.30),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.60), width: 1.5),
              boxShadow: [
                BoxShadow(color: _purple.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12)),
                BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final bool     sel         = _selectedIndex == i;
                final Color    activeColor = i == 2 ? _pink : _purple;
                final IconData icon        = items[i]['icon'] as IconData;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTabTap(i),
                    child: AnimatedBuilder(
                      animation: _iconCtrl[i],
                      builder: (_, __) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                width:  sel ? 46 : 36,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: sel ? activeColor.withOpacity(0.18) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: ScaleTransition(
                                    scale: _iconScale[i],
                                    child: Icon(icon, size: 22,
                                        color: sel ? activeColor : _dark.withOpacity(0.40)),
                                  ),
                                ),
                              ),
                              // Badge de notificaciones no leídas (sólo tab 2)
                              if (i == 2)
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                                      .collection('notifications')
                                      .where('leida', isEqualTo: false)
                                      .snapshots(),
                                  builder: (ctx, snap) {
                                    final count = snap.data?.docs.length ?? 0;
                                    if (count == 0) return const SizedBox.shrink();
                                    return Positioned(
                                      right: 2, top: 2,
                                      child: Container(
                                        width: 14, height: 14,
                                        decoration: const BoxDecoration(color: _pink, shape: BoxShape.circle),
                                        child: Center(
                                          child: Text(count > 9 ? '9+' : '$count',
                                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: sel ? 10 : 9,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                              color: sel ? activeColor : _dark.withOpacity(0.38),
                            ),
                            child: Text(items[i]['label'] as String),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
