import 'package:flutter/material.dart';

class AvailabilityPage extends StatelessWidget {
  final int roomPrice;
  final String checkInDate;
  final String checkOutDate;

  const AvailabilityPage({
    super.key,
    required this.roomPrice,
    required this.checkInDate,
    required this.checkOutDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Disponibilité"),
        backgroundColor: const Color.fromARGB(255, 42, 56, 145),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Prix de la chambre : $roomPrice FCFA", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text("Date d'arrivée : $checkInDate", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Date de départ : $checkOutDate", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            const Center(
              child: Text("Ici vous pouvez vérifier la disponibilité..."),
            ),
          ],
        ),
      ),
    );
  }
}
