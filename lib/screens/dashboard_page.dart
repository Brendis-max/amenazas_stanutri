import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'stats_page.dart';
import 'create_report_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? selectedChildId;
  String? selectedChildName;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            SizedBox(
              height: 40,
              child: Image.asset('assets/starnutri2.png', fit: BoxFit.contain),
            ),
            const Spacer(),
            _buildAppBarAction(Icons.notifications_none_rounded, hasBadge: true),
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/splash.png'),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // USAMOS LA COLECCIÓN DE NIÑOS PARA EL DASHBOARD
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('children')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = snapshot.data!.docs;
          if (children.isEmpty) return const Center(child: Text("No hay hijos registrados"));

          // --- LÓGICA DE SELECCIÓN ---
          QueryDocumentSnapshot? currentDoc;
          if (selectedChildId == null) {
            currentDoc = children.first;
          } else {
            try {
              currentDoc = children.firstWhere((doc) => doc.id == selectedChildId);
            } catch (e) {
              currentDoc = children.first;
            }
          }

          final data = currentDoc.data() as Map<String, dynamic>;
          
          // Sincronizamos con el nombre real de Firebase
          final String currentName = data['name'] ?? data['nombre'] ?? "Mi pequeño";
          final String currentId = currentDoc.id;
          final double progresoHoy = (data['progreso_hoy'] ?? 0).toDouble() / 100;
          final Map<String, dynamic> metrics = data['metricas'] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 25),
                Text(
                  "Seleccionar niño",
                  style: GoogleFonts.alata(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                
                _buildChildrenSelector(children, currentId),

                const SizedBox(height: 25),
                _buildProgressCard(currentName, progresoHoy, isSelected: true),

                const SizedBox(height: 25),
                Text(
                  "Registrar comidas de hoy",
                  style: GoogleFonts.alata(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 1.2,
                  children: [
                    _buildFoodCard(context, "Desayuno", Icons.wb_sunny_rounded, const Color(0xFFFFE57F), currentId, currentName),
                    _buildFoodCard(context, "Comida", Icons.restaurant_rounded, const Color(0xFFBBDEFB), currentId, currentName),
                    _buildFoodCard(context, "Cena", Icons.nightlight_round, const Color(0xFFB2EBF2), currentId, currentName),
                    _buildFoodCard(context, "Snacks", Icons.cookie_outlined, const Color(0xFFE1BEE7), currentId, currentName),
                  ],
                ),

                const SizedBox(height: 30),
                _buildNutritionalBalance(metrics),

                const SizedBox(height: 30),
                _buildRecommendationItem(
                  "Aumentar frutas",
                  "$currentName necesita más porciones de fruta hoy",
                  const Color(0xFFFEF3C7),
                  Icons.lightbulb_outline,
                ),
                _buildRecommendationItem(
                  "Ver reportes",
                  "Analiza el progreso semanal de $currentName",
                  const Color(0xFFF4FF81),
                  Icons.bar_chart_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatsPage(childId: currentId, childName: currentName),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- COMPONENTES DEL DASHBOARD (MÉTODOS PRIVADOS) ---

  Widget _buildWelcomeCard() {
    final user = FirebaseAuth.instance.currentUser;
    String nombreMama = user?.displayName ?? "Mamá";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF9C4), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("¡Hola, $nombreMama!", style: GoogleFonts.alata(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Hoy es un día para cuidar la alimentación de tu pequeñ@", style: TextStyle(fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildChildrenSelector(List<QueryDocumentSnapshot> children, String currentId) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        itemBuilder: (context, index) {
          final childData = children[index].data() as Map<String, dynamic>;
          final String id = children[index].id;
          final String nombre = childData['name'] ?? childData['nombre'] ?? "Hijo";
          bool isSelected = id == currentId;

          return GestureDetector(
            onTap: () => setState(() { selectedChildId = id; selectedChildName = nombre; }),
            child: Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isSelected ? Colors.orange : Colors.grey.shade200,
                    child: Icon(Icons.person, color: isSelected ? Colors.white : Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(nombre, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard(String name, double progress, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration().copyWith(border: Border.all(color: isSelected ? Colors.blue.shade200 : Colors.transparent)),
      child: Column(
        children: [
          Row(
            children: [
              Text("Progreso de $name", style: GoogleFonts.alata(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: Colors.grey.shade100, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context, String title, IconData icon, Color color, String cId, String cName) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateReportPage(childId: cId, childName: cName, comidaInicial: title))),
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(25)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: Colors.white60, child: Icon(icon, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.alata(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionalBalance(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularIndicator("Frutas", (metrics['frutas'] ?? 0).toDouble() / 100, Colors.yellow.shade200),
              _buildCircularIndicator("Verduras", (metrics['verduras'] ?? 0).toDouble() / 100, Colors.teal.shade100),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressBarItem("Proteínas", (metrics['proteinas'] ?? 0).toDouble() / 100, Colors.blue.shade200),
          _buildProgressBarItem("Lácteos", (metrics['lacteos'] ?? 0).toDouble() / 100, Colors.indigo.shade100),
          _buildProgressBarItem("Azúcares", (metrics['azucares'] ?? 0).toDouble() / 100, Colors.orange.shade200),
        ],
      ),
    );
  }

  Widget _buildCircularIndicator(String label, double value, Color color) {
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(height: 60, width: 60, child: CircularProgressIndicator(value: value, strokeWidth: 6, backgroundColor: Colors.grey.shade100, color: color)),
        Text("${(value * 100).toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }

  Widget _buildProgressBarItem(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(child: LinearProgressIndicator(value: value, backgroundColor: Colors.grey.shade100, color: color, minHeight: 6)),
      ]),
    );
  }

  Widget _buildRecommendationItem(String title, String subtitle, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54))])),
        ]),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]);

  Widget _buildAppBarAction(IconData icon, {bool hasBadge = false}) {
    return Stack(children: [
      Icon(icon, size: 30, color: Colors.black87),
      if (hasBadge) Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Text("5", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
    ]);
  }
}