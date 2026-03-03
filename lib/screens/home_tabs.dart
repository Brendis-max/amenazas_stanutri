import 'package:flutter/material.dart';
import 'dashboard_page.dart'; 
import 'stats_page.dart';     
import 'notifications_page.dart'; 
import 'profile_page.dart'; 

class HomeTabs extends StatefulWidget {
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    DashboardPage(),      
    StatsPage(childId: "default", childName: "Selecciona un hijo"),       
    NotificationsPage(),   
    ProfilePage(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // IMPORTANTE: Permite que el cuerpo se vea detrás de la barra si es transparente
      body: IndexedStack( 
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildFloatingBar(),
    );
  }

  Widget _buildFloatingBar() {
    return Container(
      // Espaciado externo para que "flote"
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blueAccent, // Color destacado para el ícono activo
          unselectedItemColor: Colors.black38,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0, // Quitamos la sombra nativa para usar la del Container
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Inicio"),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: "Stats"),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_none_rounded), label: "Avisos"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: "Perfil"),
          ],
        ),
      ),
    );
  }
}