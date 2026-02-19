import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_profile_page.dart';
import 'home_tabs.dart';
import 'kids_home_page.dart'; // Asegúrate de tener este archivo creado

class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({super.key});

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage> {
  final user = FirebaseAuth.instance.currentUser;

  // 1. LÓGICA DE ACCESO PARA EL PADRE
  void _handleParentAccess(BuildContext context, String? savedPin, bool pinEnabled) {
    if (!pinEnabled) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>  HomeTabs()));
      return;
    }

    if (savedPin == null || savedPin.isEmpty) {
      _showCreatePinDialog(context);
    } else {
      _showLoginPinDialog(context, savedPin);
    }
  }

  // 2. FUNCIÓN DEFINIDA: CREAR PIN
  void _showCreatePinDialog(BuildContext context) {
    String newPin = "";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Configura tu PIN de Padre", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Este código protegerá tu acceso a los ajustes."),
            const SizedBox(height: 20),
            TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              decoration: const InputDecoration(hintText: "****", border: OutlineInputBorder()),
              onChanged: (value) => newPin = value,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (newPin.length == 4) {
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
                  'parentPin': newPin,
                  'pinEnabled': true,
                }, SetOptions(merge: true));
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>  HomeTabs()));
              }
            },
            child: const Text("Guardar PIN"),
          ),
        ],
      ),
    );
  }

  // 3. FUNCIÓN DEFINIDA: LOGIN CON PIN
  void _showLoginPinDialog(BuildContext context, String savedPin) {
    String inputPin = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Perfil Protegido", textAlign: TextAlign.center),
        content: TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 10),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (value) => inputPin = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (inputPin == savedPin) {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>  HomeTabs()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN Incorrecto")));
              }
            },
            child: const Text("Entrar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF6A3), Color(0xFFFFD194)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            String? savedPin = userData?['parentPin'];
            bool pinEnabled = userData?['pinEnabled'] ?? false;
            String parentName = userData?['parentName'] ?? "Papá / Mamá";

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/splash.png', height: 100),
                      const SizedBox(height: 10),
                      const Text("Selecciona tu Perfil", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 25),
                      
                      // PERFIL PADRE
                      _profileItem(
                        label: parentName,
                        color: const Color(0xFFFFE577),
                        icon: pinEnabled ? Icons.lock_outline : Icons.lock_open,
                        onTap: () => _handleParentAccess(context, savedPin, pinEnabled),
                      ),
                      
                      const SizedBox(height: 15),

                      // LISTA DE HIJOS (Botón exclusivo para niños)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user?.uid)
                            .collection('children')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, kidsSnapshot) {
                          if (!kidsSnapshot.hasData) return const SizedBox();
                          
                          final kids = kidsSnapshot.data!.docs;
                          return Column(
                            children: kids.map((kidDoc) {
                              var kidData = kidDoc.data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: _profileItem(
                                  label: kidData['name'] ?? "Niño",
                                  color: const Color(0xFFB4F8C8),
                                  icon: Icons.face,
                                  onTap: () {
                                    // Navega a la pantalla de juegos del niño
                                    Navigator.pushReplacement(
                                      context, 
                                      MaterialPageRoute(
                                        builder: (_) => KidsHomePage(kidName: kidData['name'] ?? "Niño")
                                      )
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProfilePage())),
                        icon: const Icon(Icons.add_circle_outline, color: Colors.black45),
                        label: const Text("Agregar otro perfil", style: TextStyle(color: Colors.black45)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _profileItem({required String label, required Color color, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.white30, child: Icon(Icons.person, color: Colors.black)),
            const SizedBox(width: 15),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
            Icon(icon, size: 20, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}