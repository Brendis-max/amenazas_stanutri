import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; // Asegúrate de tenerlo en pubspec.yaml
import 'package:starnutri/screens/profile_selection_page.dart';
import 'login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isPinEnabled = true;

  @override
  void initState() {
    super.initState();
    // Inicializamos el nombre con el del usuario actual
    _nameController.text =
        user?.displayName ??
        user?.email?.split('@')[0].toUpperCase() ??
        "PADRE/MAMÁ";
  }

  // --- FUNCIÓN PARA AGREGAR HIJO A FIRESTORE ---
  void _showAddChildDialog() {
    TextEditingController kidNameController = TextEditingController();
    TextEditingController kidAgeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Agregar Nuevo Hijo",
          style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kidNameController,
              decoration: const InputDecoration(labelText: "Nombre del niño/a"),
            ),
            TextField(
              controller: kidAgeController,
              decoration: const InputDecoration(labelText: "Edad"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (kidNameController.text.isNotEmpty &&
                  kidAgeController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('children')
                    .add({
                      'name': kidNameController.text,
                      'age': int.parse(kidAgeController.text),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Column(
        children: [
          // --- HEADER CURVO MEJORADO (CON EDICIÓN) ---
          Stack(
            children: [
              Container(
                height: 170,
                decoration: const BoxDecoration(
                
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF9C4), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.menu, color: Color(0xFF2D3142)),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              color: Color(0xFF2D3142),
                            ),
                            onPressed: () async {
                              // Invalida el token actual en los servidores de Firebase
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // FOTO DEL PADRE CON BOTÓN DE EDITAR
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 255, 209, 60),
                                  shape: BoxShape.circle,
                                ),
                                child: const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  backgroundImage: AssetImage(
                                    'assets/splash.png',
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.white,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      size: 18,
                                      color: Colors.pinkAccent,
                                    ),
                                    onPressed: () => print("Cambiar foto..."),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // NOMBRE EDITABLE
                                TextField(
                                  controller: _nameController,
                                  style: GoogleFonts.quicksand(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2D3142),
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    hintText: "Tu Nombre",
                                    suffixIcon: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),
                                // Línea 149: Identificación del perfil con privilegios de edición
                                const Text(
                                  "Perfil de Administrador",
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- CONTENIDO ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              children: [
                const Text(
                  "Estadísticas Generales",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                _buildTaskTile(
                  Icons.star_rounded,
                  const Color(0xFFFFE9A1),
                  "Nivel de Nutrición",
                  "Excelente progreso semanal",
                ),

                const SizedBox(height: 25),

                // --- SECCIÓN HIJOS CON BOTÓN AGREGAR ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Mis Hijos",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _showAddChildDialog,
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .collection('children')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No hay hijos registrados."),
                      );
                    }

                    final kids = snapshot.data!.docs;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 0.9,
                          ),
                      itemCount: kids.length,
                      itemBuilder: (context, index) {
                        var kid = kids[index].data() as Map<String, dynamic>;
                        List<Color> cardColors = [
                          const Color(0xFFFFE57F),
                          const Color(0xFFB2EBF2),
                          const Color(0xFFBBDEFB),
                          const Color(0xFFE1BEE7),
                          const Color(0xFFF4FF81),
                        ];

                        return _buildKidCard(
                          docId: kids[index].id,
                          name: kid['name'] ?? "Sin nombre",
                          age: (kid['age'] ?? 0).toString(),
                          color: cardColors[index % cardColors.length],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 30),
                const Divider(),
                const Text(
                  "Seguridad Parental",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                // --- SWITCH PARA QUITAR/PONER PIN ---
                SwitchListTile(
                  title: const Text(
                    "Usar PIN de seguridad",
                    style: TextStyle(fontSize: 15),
                  ),
                  value: _isPinEnabled,
                  activeColor: Colors.orange,
                  onChanged: (val) => setState(() => _isPinEnabled = val),
                ),

                if (_isPinEnabled)
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: "Cambiar PIN",
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),

                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  // Dentro del onPressed del botón GUARDAR CAMBIOS:
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .update({
                          'parentName': _nameController.text,
                          'pinEnabled': _isPinEnabled,
                          'parentPin': _pinController
                              .text, // Solo se usará si pinEnabled es true
                        });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Configuración guardada correctamente"),
                        ),
                      );
                      // Después de guardar, lo mandamos a la selección de perfiles
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileSelectionPage(),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "GUARDAR CAMBIOS",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileSelectionPage(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.people_outline,
                    color: Colors.blueGrey,
                  ),
                  label: Text(
                    "Ver perfiles",
                    style: GoogleFonts.alata(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      55,
                    ), // Mismo tamaño que el de guardar
                    side: const BorderSide(color: Colors.blueGrey, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidCard({
    required String docId,
    required String name,
    required String age,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('children')
                    .doc(docId)
                    .delete(),
                child: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const Icon(Icons.child_care, color: Colors.white, size: 30),
          const SizedBox(height: 5),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            "$age años",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
