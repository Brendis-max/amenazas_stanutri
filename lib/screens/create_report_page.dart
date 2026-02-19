import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// LIBRERIAS DE PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

class _CreateReportPageState extends State<CreateReportPage> {
  Map<String, bool> comidas = {
    "Desayuno": false,
    "Comida": false,
    "Cena": false,
  };
  int vasosAgua = 0;
  final TextEditingController _snacksController = TextEditingController();
  final TextEditingController _obsController = TextEditingController();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-seleccionar la comida si viene desde el Dashboard
    if (widget.comidaInicial != null &&
        comidas.containsKey(widget.comidaInicial)) {
      comidas[widget.comidaInicial!] = true;
    }
  }

  // --- FUNCIÓN PARA GENERAR EL PDF ---
  Future<void> _generarYDescargarPDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    "StarNutri - Reporte Nutricional",
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Información del Niño",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
         
                pw.Bullet(text: "Nombre: ${widget.childName}"), // Usa directamente el nombre del widget
                pw.Bullet(text: "Fecha: ${data['fecha_rango']}"),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Text(
                  "Comidas del Día:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Bullet(
                  text:"Desayuno: ${comidas['Desayuno']! ? 'Realizado' : 'No realizado'}",
                ),
                pw.Bullet(
                  text:"Comida: ${comidas['Comida']! ? 'Realizado' : 'No realizado'}",
                ),
                pw.Bullet(
                  text: "Cena: ${comidas['Cena']! ? 'Realizado' : 'No realizado'}",
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Hidratación:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text("${data['hidratacion']} vasos de agua consumidos."),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Snacks:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  data['snacks'].isEmpty ? "Ninguno registrado": data['snacks'],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Observaciones:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  data['observaciones'].isEmpty ? "Sin observaciones" : data['observaciones'],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "Generado por StarNutri App",
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Muestra el diálogo de impresión/guardado (Funciona en Android y Web)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Reporte_${widget.childName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _guardarReporteCompleto() async {
    setState(() => isSaving = true);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return; // Seguridad

    final childRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('children')
        .doc(widget.childId);

    final datosParaFirebase = {
      'childId': widget.childId,
      'childName': widget.childName, // <--- Asegúrate de que esto se guarde así
      'comidas': comidas,
      'hidratacion': vasosAgua,
      'snacks': _snacksController.text,
      'observaciones': _obsController.text,
      'timestamp': FieldValue.serverTimestamp(),
      'fecha_rango': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
};
    try {
      // CAMBIO AQUÍ: Guardamos en una subcolección del usuario para que sea privado y fácil de leer
      await FirebaseFirestore.instance.collection('users')
          .doc(userId)
          .collection('reports') // <--- Esta es la ruta que StatsPage debe leer
          .add(datosParaFirebase);

      // Actualizamos progreso del niño
      int comidasHechas = comidas.values.where((v) => v).length;
      double nuevoProgreso = (comidasHechas / 3) * 100;
      await childRef.update({'progreso_hoy': nuevoProgreso});

      await _generarYDescargarPDF(datosParaFirebase);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => isSaving = false);
      print("Error detallado: $e"); // Mira esto en la consola
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Crear reporte",
          style: GoogleFonts.alata(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isSaving
          ? const Center(child: CircularProgressIndicator())          
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(Icons.calendar_today, "Fecha"),
                  _buildDisabledInput(
                    "Hoy, ${DateTime.now().day}/${DateTime.now().month}",
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader(Icons.restaurant, "Comidas realizadas"),
                  _buildMealCheck("Desayuno", const Color(0xFFFFF1F2), "🌅"),
                  _buildMealCheck("Comida", const Color(0xFFFFF7ED), "🍱"),
                  _buildMealCheck("Cena", const Color(0xFFEFF6FF), "🌙"),
                  const SizedBox(height: 20),
                  _sectionHeader(Icons.opacity, "Hidratación"),
                  const SizedBox(height: 10),
                  _buildWaterGrid(),
                  const SizedBox(height: 20),
                  _sectionHeader(Icons.cookie, "Snacks"),
                  _buildTextField(_snacksController, "Escribe los snacks..."),
                  const SizedBox(height: 20),
                  _sectionHeader(Icons.visibility, "Observaciones"),
                  _buildTextField(_obsController, "Alguna nota adicional..."),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _guardarReporteCompleto,
                    child: const Text(
                      "Guardar Reporte y Descargar PDF",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS DE DISEÑO (Manteniendo tu estilo) ---
  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.teal.shade300),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.alata(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMealCheck(String title, Color color, String emoji) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: CheckboxListTile(
        title: Text("$emoji $title"),
        value: comidas[title],
        onChanged: (v) => setState(() => comidas[title] = v!),
        activeColor: Colors.brown.shade400,
      ),
    );
  }

  Widget _buildWaterGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        bool selected = (index + 1) <= vasosAgua;
        return GestureDetector(
          onTap: () => setState(() => vasosAgua = index + 1),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Colors.blue.shade100
                  : Colors.blue.shade50.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              "${index + 1}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.blue : Colors.blueGrey,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDisabledInput(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}
