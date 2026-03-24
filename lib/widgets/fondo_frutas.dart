import 'dart:math';
import 'package:flutter/material.dart';

class FondoFrutasEmoji extends StatefulWidget {
  const FondoFrutasEmoji({super.key});

  @override
  State<FondoFrutasEmoji> createState() => _FondoFrutasEmojiState();
}

class _FondoFrutasEmojiState extends State<FondoFrutasEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo crema/amarillo suave
        Container(color: const Color(0xFFFFF9E5)),
        
        // Generamos las frutas en órbitas circulares
        ..._buildOrbitasRadiales(),
      ],
    );
  }

  List<Widget> _buildOrbitasRadiales() {
    const List<String> emojis = ["🍓", "🍌", "🍉", "🍊", "🍍", "🥝", "🍒", "🍑"];
    List<Widget> frutas = [];
    
    // Definimos 3 anillos de frutas
    // Anillo 1 (cerca del logo), Anillo 2 (medio), Anillo 3 (bordes)
    final List<Map<String, dynamic>> anillos = [
      {'radio': 0.45, 'cantidad': 6}, 
      {'radio': 0.75, 'cantidad': 10},
      {'radio': 1.10, 'cantidad': 14},
    ];

    for (var anillo in anillos) {
      double radioBase = anillo['radio'];
      int cantidad = anillo['cantidad'];

      for (int i = 0; i < cantidad; i++) {
        // Calculamos el ángulo para distribuir las frutas en el círculo
        double anguloBase = (i * 2 * pi) / cantidad;
        
        // Convertimos coordenadas polares a cartesianas (Alignment x, y)
        double posX = cos(anguloBase) * radioBase;
        double posY = sin(anguloBase) * radioBase;

        final int seed = (radioBase * 100).toInt() + i;
        final random = Random(seed);
        final String emoji = emojis[random.nextInt(emojis.length)];

        frutas.add(
          _FrutaEspiral(
            controller: _controller,
            baseAlignment: Alignment(posX, posY),
            emoji: emoji,
            size: 28.0,
            phase: random.nextDouble() * 2 * pi,
          ),
        );
      }
    }
    return frutas;
  }
}

class _FrutaEspiral extends StatelessWidget {
  final AnimationController controller;
  final Alignment baseAlignment;
  final String emoji;
  final double size;
  final double phase;

  const _FrutaEspiral({
    required this.controller,
    required this.baseAlignment,
    required this.emoji,
    required this.size,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;

        // Movimiento orbital sutil
        final double orbitX = cos(t * 2 * pi + phase) * 0.04;
        final double orbitY = sin(t * 2 * pi + phase) * 0.04;

        // Rotación de la fruta sobre su eje
        final double rotation = t * 4 * pi + phase;

        return Align(
          alignment: Alignment(
            baseAlignment.x + orbitX,
            baseAlignment.y + orbitY,
          ),
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: 0.7,
              child: Text(
                emoji,
                style: TextStyle(fontSize: size, height: 1.0),
              ),
            ),
          ),
        );
      },
    );
  }
}