import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Logo de la app en la parte superior izquierda como en el PDF
        title: const Text(
          "starnutri",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la sección
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              "Notificaciones",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Lista de notificaciones
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildNotificationItem(
                  "No lo olvides !!",
                  "Agrega el nuevo alimento de tu pequeño.",
                  "1d",
                  isNew: true, // Indica si tiene el punto azul de "nueva"
                ),
                _buildNotificationItem(
                  "Sigue así",
                  "Racha de 2 días !!",
                  "2d",
                  isNew: true,
                ),
                _buildNotificationItem(
                  "Felicidades !!!",
                  "Has logrado que tu pequeño coma sano hoy.",
                  "1d",
                  isNew: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para cada tarjeta de notificación
  Widget _buildNotificationItem(String title, String description, String time, {bool isNew = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50], // Fondo sutil como en el PDF
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El punto indicador de notificación nueva
          if (isNew)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue, // Punto azul de notificación
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            const SizedBox(width: 18), // Espacio equilibrado si no hay punto

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}