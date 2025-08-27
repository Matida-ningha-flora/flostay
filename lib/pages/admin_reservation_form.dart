import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({Key? key}) : super(key: key);

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes Réservations',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F0E5),
              Color(0xFFFDF8F3),
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('reservations')
              .where('userId', isEqualTo: user?.uid)
              .orderBy('dateCreation', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Erreur: ${snapshot.error}',
                  style: GoogleFonts.poppins(),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune réservation',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vos réservations apparaîtront ici',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            final reservations = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reservations.length,
              itemBuilder: (context, index) {
                final reservation = reservations[index].data() as Map<String, dynamic>;
                final arrivalDate = (reservation['dateArrivee'] as Timestamp).toDate();
                final departureDate = (reservation['dateDepart'] as Timestamp).toDate();
                final status = reservation['statut'] ?? 'en_attente';
                final createdAt = (reservation['dateCreation'] as Timestamp).toDate();

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                reservation['chambre'] ?? 'Chambre inconnue',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4A2A10),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getStatusText(status),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Réservé le ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildReservationInfo('Arrivée', DateFormat('dd/MM/yyyy').format(arrivalDate)),
                        _buildReservationInfo('Départ', DateFormat('dd/MM/yyyy').format(departureDate)),
                        _buildReservationInfo('Nuits', '${reservation['nuits']}'),
                        _buildReservationInfo('Personnes', '${reservation['nombrePersonnes']}'),
                        const SizedBox(height: 8),
                        const Divider(),
                        _buildReservationInfo(
                          'Total',
                          '${reservation['prixTotal']} FCFA',
                          isBold: true,
                          textColor: const Color(0xFF9B4610),
                        ),
                        if (reservation['demandesSpeciales'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Demandes spéciales:',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4A2A10),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reservation['demandesSpeciales'],
                                style: GoogleFonts.poppins(),
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
        ),
      ),
    );
  }

  Widget _buildReservationInfo(String label, String value, {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textColor ?? Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmée':
        return Colors.green;
      case 'annulée':
        return Colors.red;
      case 'en_attente':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmée':
        return 'Confirmée';
      case 'annulée':
        return 'Annulée';
      case 'en_attente':
      default:
        return 'En attente';
    }
  }
}