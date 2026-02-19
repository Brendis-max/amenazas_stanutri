import 'package:flutter/material.dart';
import 'dashboard_page.dart'; 
import 'stats_page.dart';     
import 'notifications_page.dart'; 
import 'profile_page.dart'; // <--- ASEGÚRATE QUE ESTE ARCHIVO TIENE EL CÓDIGO NUEVO

class HomeTabs extends StatefulWidget {
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _selectedIndex = 0;

  // Lista de las páginas
  final List<Widget> _pages = [
    DashboardPage(),      
   StatsPage(childId: "default", childName: "Selecciona un hijo"),       
    NotificationsPage(),   
    ProfilePage(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usar IndexedStack es correcto para no perder el scroll
      body: IndexedStack( 
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black38,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: "Stats"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none_rounded), label: "Avisos"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: "Perfil"),
        ],
      ),
    );
  }
}