import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KidsHomePage extends StatelessWidget {
  final String kidName;

  const KidsHomePage({super.key, required this.kidName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "  ",
          style: GoogleFonts.bangers( // O una fuente similar "cartoon"
            color: Colors.black,
            fontSize: 28,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PERSONAJE Y TARJETA "¿SABÍAS QUÉ?" ---
            Center(
              child: Column(
                children: [
                  Image.asset('assets/starnutrikids.png', height: 120,
                  errorBuilder: (context, error, stackTrace) {
    // Si la imagen falla, muestra este icono en su lugar
    return const Icon(Icons.stars, size: 100, color: Colors.orange);
  },), // Tu imagen de la estrella
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF176), // Amarillo brillante
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "¿Sabías que?",
                          style: GoogleFonts.alata(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Comer sano te da más energía y ayuda a que tu cuerpo y mente crezcan fuertes cada día 🥦 💪",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.alata(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- SECCIÓN CATEGORÍAS ---
            Text("Categorías de juegos", 
              style: GoogleFonts.alata(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.85,
              children: [
                _buildCategoryCard("Frutas y Verduras", "8 juegos disponibles", "+15 puntos", const Color(0xFFDCFCE7), Icons.apple, true),
                _buildCategoryCard("Grupos Alimenticios", "6 juegos disponibles", "+20 puntos", Colors.white, Icons.layers, false),
                _buildCategoryCard("Porciones", "5 juegos disponibles", "+25 puntos", Colors.white, Icons.restaurant, false),
                _buildCategoryCard("Hidratación", "4 juegos disponibles", "+10 puntos", Colors.white, Icons.water_drop, false),
              ],
            ),
            const SizedBox(height: 25),

            // --- SECCIÓN DESTACADO ---
            Text("Destacado", 
              style: GoogleFonts.alata(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  const Icon(Icons.extension, size: 40, color: Colors.white),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("¡Clasifica los alimentos!", 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text("Arrastra y clasifica", 
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.yellow, size: 16),
                            const Text(" +50 puntos", style: TextStyle(color: Colors.white, fontSize: 12)),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text("Jugar ahora", style: TextStyle(fontSize: 12)),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- SECCIÓN JUEGOS RÁPIDOS ---
            Text("Juegos rápidos", 
              style: GoogleFonts.alata(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildQuickGame("Memoria Nutricional", "Encuentra las parejas", "3 min", "+15", Icons.eco),
            _buildQuickGame("Jardín Saludable", "Cultiva tus vegetales", "8 min", "+30", Icons.eco),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget para las tarjetas de categorías (Cuadrícula)
  Widget _buildCategoryCard(String title, String subtitle, String points, Color bgColor, IconData icon, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isUnlocked ? Colors.white : Colors.grey.shade100,
            child: Icon(icon, color: isUnlocked ? Colors.green : Colors.grey),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orangeAccent, size: 14),
              Text(" $points", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const Spacer(),
              Icon(isUnlocked ? Icons.check_circle : Icons.lock, 
                   color: isUnlocked ? Colors.green : Colors.grey.shade400, size: 18),
            ],
          )
        ],
      ),
    );
  }

  // Widget para la lista de juegos rápidos
  Widget _buildQuickGame(String title, String desc, String time, String points, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    Text(" $time", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 10),
                    const Icon(Icons.star, size: 12, color: Colors.orangeAccent),
                    Text(" $points", style: const TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}