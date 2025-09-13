import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoomSelection extends StatefulWidget {
  final DateTime arrivalDate;
  final DateTime departureDate;
  final int numberOfGuests;

  const RoomSelection({
    Key? key,
    required this.arrivalDate,
    required this.departureDate,
    required this.numberOfGuests,
  }) : super(key: key);

  @override
  _RoomSelectionState createState() => _RoomSelectionState();
}

class _RoomSelectionState extends State<RoomSelection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedRoom = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélection de Chambre'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('rooms').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final rooms = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chambres disponibles',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Du ${DateFormat('dd/MM/yyyy').format(widget.arrivalDate)} au ${DateFormat('dd/MM/yyyy').format(widget.departureDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('${widget.numberOfGuests} personne(s)'),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index].data() as Map<String, dynamic>;
                      final roomId = rooms[index].id;
                      final roomNumber = room['number'] ?? 'Inconnu';
                      final roomType = room['type'] ?? 'Standard';
                      final roomPrice = room['price'] ?? 0;
                      final roomCapacity = room['capacity'] ?? 1;
                      final isAvailable = room['available'] ?? true;

                      if (roomCapacity < widget.numberOfGuests) {
                        return const SizedBox.shrink();
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: isAvailable ? Colors.white : Colors.grey[200],
                        child: ListTile(
                          title: Text('Chambre $roomNumber - $roomType'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Capacité: $roomCapacity personne(s)'),
                              Text('Prix: $roomPrice FCFA/nuit'),
                              if (!isAvailable)
                                const Text(
                                  'Non disponible',
                                  style: TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                          trailing: _selectedRoom == roomId
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: isAvailable
                              ? () {
                                  setState(() {
                                    _selectedRoom = roomId;
                                  });
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _selectedRoom.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context, _selectedRoom);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B4610),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmer la sélection'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}