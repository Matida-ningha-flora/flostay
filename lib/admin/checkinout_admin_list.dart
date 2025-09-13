import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CheckInOutAdminList extends StatefulWidget {
  const CheckInOutAdminList({Key? key}) : super(key: key);

  @override
  State<CheckInOutAdminList> createState() => _CheckInOutAdminListState();
}

class _CheckInOutAdminListState extends State<CheckInOutAdminList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _roomNumberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reservations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final reservations = snapshot.data!.docs;

        if (reservations.isEmpty) {
          return const Center(child: Text("Aucune réservation trouvée"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final data = reservations[index].data() as Map<String, dynamic>;
            final reservationId = reservations[index].id;
            final clientName = data['clientName'] ?? 'Client inconnu';
            final room = data['room'] ?? 'Chambre inconnue';
            final status = data['status'] ?? 'en attente';
            final arrival = data['arrival'] != null
                ? DateFormat('dd/MM/yyyy')
                    .format((data['arrival'] as Timestamp).toDate())
                : 'Date inconnue';
            final departure = data['departure'] != null
                ? DateFormat('dd/MM/yyyy')
                    .format((data['departure'] as Timestamp).toDate())
                : 'Date inconnue';

            bool checkInStatus = false;
            bool checkOutStatus = false;

            if (data['checkIn'] != null) {
              if (data['checkIn'] is bool) {
                checkInStatus = data['checkIn'];
              } else if (data['checkIn'] is String) {
                checkInStatus = data['checkIn'] == 'true';
              }
            }

            if (data['checkOut'] != null) {
              if (data['checkOut'] is bool) {
                checkOutStatus = data['checkOut'];
              } else if (data['checkOut'] is String) {
                checkOutStatus = data['checkOut'] == 'true';
              }
            }

            Color statusColor;
            switch (status) {
              case 'confirmée':
                statusColor = const Color(0xFF9B4610);
                break;
              case 'annulée':
                statusColor = Colors.red;
                break;
              default:
                statusColor = Colors.orange;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Réservation #${index + 1}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildInfoRow("Client:", clientName),
                    _buildInfoRow("Chambre:", room),
                    _buildInfoRow("Arrivée:", arrival),
                    _buildInfoRow("Départ:", departure),
                    _buildInfoRow(
                      "Check-in:",
                      checkInStatus ? "Effectué" : "En attente",
                    ),
                    _buildInfoRow(
                      "Check-out:",
                      checkOutStatus ? "Effectué" : "En attente",
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'confirmée' && !checkInStatus)
                          ElevatedButton(
                            onPressed: () {
                              _showCheckInDialog(context, reservationId, room);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Check-in"),
                          ),
                        const SizedBox(width: 10),
                        if (status == 'confirmée' &&
                            checkInStatus &&
                            !checkOutStatus)
                          ElevatedButton(
                            onPressed: () {
                              _showCheckOutDialog(context, reservationId, room);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Check-out"),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCheckInDialog(
      BuildContext context, String reservationId, String currentRoom) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Effectuer le check-in"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  "Confirmer le check-in et attribuer un numéro de chambre:"),
              const SizedBox(height: 16),
              TextField(
                controller: _roomNumberController,
                decoration: InputDecoration(
                  labelText: "Numéro de chambre",
                  hintText: currentRoom.isNotEmpty ? currentRoom : "Ex: 101",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                final roomNumber = _roomNumberController.text.isNotEmpty
                    ? _roomNumberController.text
                    : currentRoom;

                _firestore.collection('reservations').doc(reservationId).update({
                  'checkIn': true,
                  'checkInTime': FieldValue.serverTimestamp(),
                  'room': roomNumber,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Check-in effectué avec succès"),
                  ),
                );
              },
              child: const Text("Confirmer"),
            ),
          ],
        );
      },
    );
  }

  void _showCheckOutDialog(
      BuildContext context, String reservationId, String currentRoom) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Effectuer le check-out"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Confirmer le check-out:"),
              const SizedBox(height: 16),
              Text("Chambre: $currentRoom"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                _firestore.collection('reservations').doc(reservationId).update({
                  'checkOut': true,
                  'checkOutTime': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Check-out effectué avec succès"),
                  ),
                );
              },
              child: const Text("Confirmer"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}