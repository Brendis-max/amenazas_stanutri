import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassifyGamePage extends StatefulWidget {
  final String kidName;
  final String userId;
  const ClassifyGamePage({super.key, required this.kidName, required this.userId});

  @override
  State<ClassifyGamePage> createState() => _ClassifyGamePageState();
}

class _ClassifyGamePageState extends State<ClassifyGamePage> {
  late List<Map<String, String>> _remaining;
  final Map<String, List<Map<String, String>>> _categories = {
    'Frutas 🍎': [],
    'Verduras 🥦': [],
    'Proteínas 🥩': [],
    'Lácteos 🥛': [],
  };

  final List<Map<String, String>> _allFoods = [
    {'name': '🍎 Manzana', 'category': 'Frutas 🍎'},
    {'name': '🍌 Plátano', 'category': 'Frutas 🍎'},
    {'name': '🍓 Fresa', 'category': 'Frutas 🍎'},
    {'name': '🍊 Naranja', 'category': 'Frutas 🍎'},
    {'name': '🥦 Brócoli', 'category': 'Verduras 🥦'},
    {'name': '🥕 Zanahoria', 'category': 'Verduras 🥦'},
    {'name': '🌽 Elote', 'category': 'Verduras 🥦'},
    {'name': '🍅 Tomate', 'category': 'Verduras 🥦'},
    {'name': '🥚 Huevo', 'category': 'Proteínas 🥩'},
    {'name': '🍗 Pollo', 'category': 'Proteínas 🥩'},
    {'name': '🐟 Pescado', 'category': 'Proteínas 🥩'},
    {'name': '🫘 Frijoles', 'category': 'Proteínas 🥩'},
    {'name': '🥛 Leche', 'category': 'Lácteos 🥛'},
    {'name': '🧀 Queso', 'category': 'Lácteos 🥛'},
    {'name': '🍦 Yogurt', 'category': 'Lácteos 🥛'},
    {'name': '🧈 Mantequilla', 'category': 'Lácteos 🥛'},
  ];

  int _correct = 0;
  int _wrong = 0;
  bool _gameWon = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final list = List<Map<String, String>>.from(_allFoods)..shuffle();
    setState(() {
      _remaining = list;
      _correct = 0;
      _wrong = 0;
      _gameWon = false;
      _categories.forEach((key, value) => value.clear());
    });
  }

  void _onDrop(String category, Map<String, String> food) {
    if (food['category'] == category) {
      setState(() {
        _remaining.remove(food);
        _categories[category]!.add(food);
        _correct++;
        if (_remaining.isEmpty) _gameWon = true;
      });
    } else {
      setState(() {
        _wrong++;
        _remaining.shuffle();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold con color de fondo sólido para evitar problemas de renderizado
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text('Clasifica los Alimentos', 
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.black)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: _gameWon ? _buildWinView() : _buildGameView(),
      ),
    );
  }

  Widget _buildGameView() {
    return Column(
      children: [
        // Marcador simple
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _infoText('✅ $_correct', Colors.green),
              _infoText('❌ $_wrong', Colors.red),
              _infoText('📦 ${_remaining.length}', Colors.blue),
            ],
          ),
        ),

        // Alimento actual
        if (_remaining.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildDraggable(_remaining.first),
        ],

        const SizedBox(height: 30),

        // Grid de categorías con pesos fijos
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: _categories.keys.map((cat) => _buildDropTarget(cat)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoText(String text, Color color) {
    return Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18));
  }

  Widget _buildDraggable(Map<String, String> food) {
    return Draggable<Map<String, String>>(
      data: food,
      feedback: Material(
        color: Colors.transparent,
        child: _foodBox(food['name']!, true),
      ),
      childWhenDragging: Opacity(opacity: 0.2, child: _foodBox(food['name']!, false)),
      child: _foodBox(food['name']!, false),
    );
  }

  Widget _foodBox(String name, bool shadow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF7C3AED), width: 2),
        boxShadow: shadow ? [const BoxShadow(color: Colors.black26, blurRadius: 10)] : null,
      ),
      child: Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
    );
  }

  Widget _buildDropTarget(String category) {
    return DragTarget<Map<String, String>>(
      onAccept: (data) => _onDrop(category, data),
      builder: (context, candidateData, _) {
        return Container(
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty ? Colors.white : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                children: _categories[category]!
                    .map((f) => Text(f['name']!.split(' ').first, style: const TextStyle(fontSize: 20)))
                    .toList(),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildWinView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 80)),
          const Text('¡GANASTE!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initGame,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            child: const Text('Reiniciar', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }
}