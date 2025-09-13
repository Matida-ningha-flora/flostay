import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReservationsAdminList extends StatelessWidget {
  const ReservationsAdminList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
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
            final totalPrice = data['totalPrice']?.toString() ?? '0';
            final nights = data['nights']?.toString() ?? '1';

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
                    _buildInfoRow("Nuits:", nights),
                    _buildInfoRow("Prix total:", "$totalPrice FCFA"),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'en attente') ...[
                          OutlinedButton(
                            onPressed: () {
                              firestore
                                  .collection('reservations')
                                  .doc(reservationId)
                                  .update({'status': 'annulée'});
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text("Annuler"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              firestore
                                  .collection('reservations')
                                  .doc(reservationId)
                                  .update({'status': 'confirmée'});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Confirmer"),
                          ),
                        ],
                        if (status == 'confirmée')
                          OutlinedButton(
                            onPressed: () {
                              firestore
                                  .collection('reservations')
                                  .doc(reservationId)
                                  .update({'status': 'annulée'});
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text("Annuler"),
                          ),
                        if (status == 'annulée')
                          Text(
                            "Réservation annulée",
                            style: TextStyle(
                              color: Colors.red,
                              fontStyle: FontStyle.italic,
                            ),
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