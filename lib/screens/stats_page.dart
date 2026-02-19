import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _StatsPageState extends State<StatsPage> {
  // ESTADOS
  late String selectedChildId;
  late String selectedChildName;
  bool mostrarTodos = false; // true = Todos, false = Recientes
  String searchText = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedChildId = widget.childId;
    selectedChildName = widget.childName;
  }

  // --- FUNCIÓN PDF (Con fuentes unicode para evitar errores) ---
  Future<void> _abrirPDF(Map<String, dynamic> reportData) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    final Map<String, dynamic> comidasRaw = reportData['comidas'] ?? {};
    final Map<String, bool> comidas = Map<String, bool>.from(comidasRaw);
    final String nombreFinal = reportData['childName'] ?? reportData['name'] ?? selectedChildName;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("StarNutri - Reporte Diario", style: pw.TextStyle(font: boldFont, fontSize: 26)),
                pw.SizedBox(height: 10),
                pw.Text("Niño: $nombreFinal", style: pw.TextStyle(font: font, fontSize: 18)),
                pw.Text("Fecha: ${reportData['fecha_rango'] ?? 'No especificada'}", style: pw.TextStyle(font: font)),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text("Resumen de Comidas:", style: pw.TextStyle(font: boldFont, fontSize: 18)),
                pw.Bullet(text: "Desayuno: ${comidas['Desayuno'] == true ? 'Completado' : 'No marcado'}", style: pw.TextStyle(font: font)),
                pw.Bullet(text: "Comida: ${comidas['Comida'] == true ? 'Completado' : 'No marcado'}", style: pw.TextStyle(font: font)),
                pw.Bullet(text: "Cena: ${comidas['Cena'] == true ? 'Completado' : 'No marcado'}", style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 20),
                pw.Text("Hidratación: ${reportData['hidratacion'] ?? 0} vasos de agua", style: pw.TextStyle(font: font)),
                pw.Text("Snacks: ${reportData['snacks'] ?? 'Sin registro'}", style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 20),
                pw.Text("Observaciones:", style: pw.TextStyle(font: boldFont)),
                pw.Text(reportData['observaciones'] ?? "Sin notas adicionales", style: pw.TextStyle(font: font)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_$nombreFinal',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Reportes",
          style: GoogleFonts.alata(color: Colors.black, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          // 1. Selector de Niños
          _buildChildrenSelector(currentUserId),
          // 2. Filtros "Recientes/Todos" (Tu diseño original)
          _buildFilters(),
          // 3. Lista de Reportes
          Expanded(
            child: _buildReportsStream(currentUserId),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

// NUEVO: Selector de niños más pequeño y redondeado
  Widget _buildChildrenSelector(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('children')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60);
        final kids = snapshot.data!.docs;

        return Container(
          height: 50, // Altura reducida
          margin: const EdgeInsets.only(top: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: kids.length,
            itemBuilder: (context, index) {
              final kid = kids[index].data() as Map<String, dynamic>;
              final kidId = kids[index].id;
              final name = kid['name'] ?? "Hijo";
              bool isSelected = selectedChildId == kidId;

              return GestureDetector(
                onTap: () => setState(() {
                  selectedChildId = kidId;
                  selectedChildName = name;
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2), // Más compacto
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(30), // Totalmente redondo
                    border: Border.all(
                      color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13, // Texto un poco más pequeño
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // TUS FILTROS ORIGINALES
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _filterChip("Recientes", !mostrarTodos, () => setState(() => mostrarTodos = false)),
          const SizedBox(width: 10),
          _filterChip("Todos", mostrarTodos, () => setState(() => mostrarTodos = true)),
        ],
      ),
    );
  }

  Widget _filterChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(text,
            style: TextStyle(
                color: selected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  // STREAM ACTUALIZADO CON FILTRO DE NIÑO
  Widget _buildReportsStream(String userId) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reports');

    // SI NO ES "TODOS", FILTRAMOS POR EL NIÑO SELECCIONADO
    if (!mostrarTodos) {
      query = query.where('childId', isEqualTo: selectedChildId);
    }

    query = query.orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;

        // Filtrado por búsqueda local
        if (searchText.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final n = (data['childName'] ?? "").toString().toLowerCase();
            return n.contains(searchText.toLowerCase());
          }).toList();
        }

        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final report = docs[index].data() as Map<String, dynamic>;
            return _buildReportCard(context, report, index);
          },
        );
      },
    );
  }

  // --- WIDGETS DE APOYO (Tus estilos originales) ---

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => searchText = val),
        decoration: InputDecoration(
          hintText: "Buscar por nombre...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchText = "");
                  })
              : null,
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> report, int index) {
    final colors = [const Color(0xFFDCFCE7), const Color(0xFFDBEAFE), const Color(0xFFFEF3C7)];
    final textColors = [const Color(0xFF166534), const Color(0xFF1E40AF), const Color(0xFF92400E)];

    return GestureDetector(
      onTap: () => _abrirPDF(report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: colors[index % 3],
              child: Icon(Icons.analytics_outlined, color: textColors[index % 3]),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reporte - ${report['childName'] ?? selectedChildName}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(report['fecha_rango'] ?? "Hoy",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.file_download_outlined, color: textColors[index % 3]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.note_add_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 10),
          Text("No hay reportes", style: GoogleFonts.alata(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(child: Text("Error: $error", style: const TextStyle(color: Colors.red)));
  }
}