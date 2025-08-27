import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hôtel Réception - Geneva',
      theme: ThemeData(
        primaryColor: const Color(0xFF9B4610),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF9B4610),
          secondary: const Color(0xFF9B4610),
        ),
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF9B4610),
          iconTheme: const IconThemeData(color: Color(0xFF9B4610)),
          titleTextStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9B4610),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ),
      home: const ReceptionPage(),
    );
  }
}

class ReceptionPage extends StatefulWidget {
  const ReceptionPage({super.key});

  @override
  State<ReceptionPage> createState() => _ReceptionPageState();
}

class _ReceptionPageState extends State<ReceptionPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ReservationsList(),
    const OrdersList(),
    const CheckInOutList(),
    const ConversationsList(),
  ];

  final List<String> _appBarTitles = [
    "Gestion des Réservations",
    "Suivi des Commandes",
    "Check-in/Check-out",
    "Messages Clients"
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _appBarTitles[_selectedIndex],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9B4610),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF9B4610),
        actions: [
          if (_selectedIndex == 3)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF9B4610)),
              onPressed: () {
                setState(() {});
              },
            ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF9B4610),
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          showUnselectedLabels: true,
          elevation: 10,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.hotel),
              label: "Réservations",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.room_service),
              label: "Commandes",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle),
              label: "Check-in/out",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: "Messages",
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE LISTE DES RÉSERVATIONS ---
class ReservationsList extends StatelessWidget {
  const ReservationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reservations = snapshot.data!.docs;

        // Compter les réservations en attente
        final pendingCount = reservations.where((res) {
          final data = res.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Toutes les réservations",
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B4610),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$pendingCount en attente",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  final reservation = reservations[index];
                  final data = reservation.data() as Map<String, dynamic>;
                  
                  return ReservationCard(
                    reservationId: reservation.id,
                    data: data,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ReservationCard extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> data;

  const ReservationCard({
    super.key,
    required this.reservationId,
    required this.data,
  });

  @override
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateReservationStatus(String newStatus) async {
    try {
      await _firestore.collection('reservations').doc(widget.reservationId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Créer une notification pour le client
      String message = '';
      String title = '';
      
      if (newStatus == 'confirmed') {
        title = 'Réservation Confirmée';
        message = 'Votre réservation a été confirmée par la réception';
      } else if (newStatus == 'cancelled') {
        title = 'Réservation Annulée';
        message = 'Votre réservation a été annulée par la réception';
      } else if (newStatus == 'check-in-requested') {
        title = 'Demande de Check-in';
        message = 'Votre demande de check-in a été reçue et est en cours de traitement';
      } else if (newStatus == 'checked-in') {
        title = 'Check-in Effectué';
        message = 'Votre check-in a été confirmé par la réception';
      } else if (newStatus == 'checked-out') {
        title = 'Check-out Effectué';
        message = 'Votre check-out a été effectué par la réception';
      }

      if (widget.data['userId'] != null) {
        await _firestore.collection('notifications').add({
          'userId': widget.data['userId'],
          'title': title,
          'message': message,
          'type': 'reservation',
          'reservationId': widget.reservationId,
          'status': 'unread',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Réservation $newStatus avec succès!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _assignRoom(String roomNumber) async {
    try {
      await _firestore.collection('reservations').doc(widget.reservationId).update({
        'roomNumber': roomNumber,
        'status': 'checked-in',
        'actualCheckIn': FieldValue.serverTimestamp(),
      });

      // Créer une notification pour le client
      if (widget.data['userId'] != null) {
        await _firestore.collection('notifications').add({
          'userId': widget.data['userId'],
          'title': 'Check-in Confirmé',
          'message': 'Votre check-in a été confirmé. Votre chambre est $roomNumber',
          'type': 'reservation',
          'reservationId': widget.reservationId,
          'status': 'unread',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Chambre $roomNumber attribuée avec succès!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAssignRoomDialog() {
    TextEditingController roomController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Attribuer une chambre'),
          content: TextField(
            controller: roomController,
            decoration: const InputDecoration(
              hintText: "Numéro de chambre",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (roomController.text.isNotEmpty) {
                  _assignRoom(roomController.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610),
                foregroundColor: Colors.white,
              ),
              child: const Text('Attribuer'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'check-in-requested':
        return Colors.deepOrange;
      case 'checked-in':
        return Colors.green;
      case 'checked-out':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'check-in-requested':
        return 'Demande de check-in';
      case 'checked-in':
        return 'Check-in';
      case 'checked-out':
        return 'Check-out';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkInDate = widget.data['checkInDate'] is Timestamp
        ? (widget.data['checkInDate'] as Timestamp).toDate()
        : DateTime.now();
    final checkOutDate = widget.data['checkOutDate'] is Timestamp
        ? (widget.data['checkOutDate'] as Timestamp).toDate()
        : DateTime.now();
    final status = widget.data['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Réservation #${widget.reservationId.substring(0, 8)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(status),
                    ),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            _buildInfoRow("Client:", widget.data['userName'] ?? widget.data['userEmail'] ?? 'Non spécifié'),
            _buildInfoRow("Email:", widget.data['userEmail'] ?? 'Non spécifié'),
            _buildInfoRow("Téléphone:", widget.data['userPhone'] ?? 'Non spécifié'),
            _buildInfoRow("Chambre:", widget.data['roomType'] ?? 'Non spécifié'),
            if (widget.data['roomNumber'] != null)
              _buildInfoRow("Numéro de chambre:", widget.data['roomNumber']),
            _buildInfoRow("Arrivée:", DateFormat('dd/MM/yyyy').format(checkInDate)),
            _buildInfoRow("Départ:", DateFormat('dd/MM/yyyy').format(checkOutDate)),
            _buildInfoRow("Personnes:", "${widget.data['guests'] ?? '1'}"),
            _buildInfoRow("Prix total:", "${widget.data['totalAmount'] ?? widget.data['price'] ?? 0} FCFA"),
            if (widget.data['paymentMethod'] != null)
              _buildInfoRow("Paiement:", widget.data['paymentMethod']),
            
            // Afficher les documents soumis pour le check-in
            if (status == 'check-in-requested' && widget.data['checkInDocuments'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    "Documents soumis:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(widget.data['checkInDocuments'] as Map<String, dynamic>).entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            "${entry.key}: ",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Boutons d'action selon le statut
            if (status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _updateReservationStatus('cancelled'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Annuler"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _updateReservationStatus('confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B4610),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Confirmer"),
                  ),
                ],
              ),
            if (status == 'check-in-requested')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _showAssignRoomDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Attribuer chambre"),
                  ),
                ],
              ),
            if (status == 'checked-in')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _updateReservationStatus('checked-out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Check-out"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Les autres classes (OrdersList, CheckInOutList, ConversationsList, etc.) restent similaires
// mais adaptées pour utiliser les vraies données de Firestore

// --- PAGE LISTE DES COMMANDES ---
class OrdersList extends StatelessWidget {
  const OrdersList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('commandes')
          .where('statut', whereIn: ['en_attente', 'en_cours', 'terminee'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final commandes = snapshot.data!.docs;

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Commandes en cours",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                    ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B4610),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${commandes.length} en cours",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: commandes.length,
                  itemBuilder: (context, index) {
                    final commande = commandes[index];
                    final data = commande.data() as Map<String, dynamic>;
                    
                    return CommandeCard(
                      commandeId: commande.id,
                      data: data,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CommandeCard extends StatefulWidget {
  final String commandeId;
  final Map<String, dynamic> data;

  const CommandeCard({
    super.key,
    required this.commandeId,
    required this.data,
  });

  @override
  State<CommandeCard> createState() => _CommandeCardState();
}

class _CommandeCardState extends State<CommandeCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _changerStatutCommande(String nouveauStatut) async {
    try {
      await _firestore.collection('commandes').doc(widget.commandeId).update({
        'statut': nouveauStatut,
        'dateModification': FieldValue.serverTimestamp(),
      });

      // Créer une notification pour le client
      String message = '';
      if (nouveauStatut == 'en_cours') {
        message = 'Votre commande est en cours de préparation';
      } else if (nouveauStatut == 'terminee') {
        message = 'Votre commande a été livrée avec succès';
      }

      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'titre': 'Mise à jour de commande',
        'message': message,
        'type': 'commande',
        'commandeId': widget.commandeId,
        'statut': 'non_lu',
        'date': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Statut de la commande mis à jour: $nouveauStatut"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getStatutText(String statut) {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'en_cours':
        return 'Chez le client';
      case 'terminee':
        return 'Terminée';
      case 'annulee':
        return 'Annulée';
      default:
        return statut;
    }
  }

  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'en_attente':
        return Colors.orange;
      case 'en_cours':
        return Colors.blue;
      case 'terminee':
        return Colors.green;
      case 'annulee':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (widget.data['date'] as Timestamp).toDate();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la commande
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B4610).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant, color: Color(0xFF9B4610)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Commande #${widget.commandeId.substring(0, 8)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Chambre: ${widget.data['chambre'] ?? 'Non spécifié'}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatutColor(widget.data['statut']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStatutColor(widget.data['statut']),
                    ),
                  ),
                  child: Text(
                    _getStatutText(widget.data['statut']),
                    style: TextStyle(
                      color: _getStatutColor(widget.data['statut']),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            
            // Détails de la commande
            _buildInfoRow("Client:", widget.data['userEmail'] ?? 'Non spécifié'),
            _buildInfoRow("Produit:", widget.data['item'] ?? 'Non spécifié'),
            _buildInfoRow("Quantité:", widget.data['quantite'].toString()),
            _buildInfoRow("Total:", "${widget.data['total']} FCFA"),
            _buildInfoRow("Date:", DateFormat('dd/MM/yyyy à HH:mm').format(date)),
            
            if (widget.data['instructions'] != null && widget.data['instructions'].isNotEmpty)
              _buildInfoRow("Instructions:", widget.data['instructions']),
            
            const SizedBox(height: 16),
            
            // Boutons d'action selon le statut
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _getActions(widget.data['statut']),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getActions(String statut) {
    switch (statut) {
      case 'en_attente':
        return [
          OutlinedButton(
            onPressed: () {
              _changerStatutCommande('annulee');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Annuler"),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              _changerStatutCommande('en_cours');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B4610),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Commencer"),
          ),
        ];
      case 'en_cours':
        return [
          OutlinedButton(
            onPressed: () {
              _changerStatutCommande('annulee');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Annuler"),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              _changerStatutCommande('terminee');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B4610),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Terminer"),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Les autres classes (CheckInOutList, ConversationsList, ChatPageReception) restent similaires
// mais adaptées pour utiliser les vraies données de Firestore

// --- PAGE CHECK-IN / CHECK-OUT ---
class CheckInOutList extends StatelessWidget {
  const CheckInOutList({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: const TabBar(
              labelColor: Color(0xFF9B4610),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF9B4610),
              tabs: [
                Tab(
                  icon: Icon(Icons.login),
                  text: "Arrivées",
                ),
                Tab(
                  icon: Icon(Icons.logout),
                  text: "Départs",
                ),
              ],
            ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: TabBarView(
                  children: [
                    _buildCheckList(true),
                    _buildCheckList(false),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildCheckList(bool isCheckIn) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('status', isEqualTo: isCheckIn ? 'check-in-requested' : 'checked-in')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reservations = snapshot.data!.docs;

        if (reservations.isEmpty) {
          return Center(
            child: Text(
              isCheckIn ? "Aucune demande de check-in" : "Aucun départ prévu",
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index];
            final data = reservation.data() as Map<String, dynamic>;
            final checkInDate = data['checkInDate'] is Timestamp
                ? (data['checkInDate'] as Timestamp).toDate()
                : DateTime.now();
            final checkOutDate = data['checkOutDate'] is Timestamp
                ? (data['checkOutDate'] as Timestamp).toDate()
                : DateTime.now();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCheckIn
                                ? Colors.deepOrange.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCheckIn ? Icons.login : Icons.logout,
                            color: isCheckIn ? Colors.deepOrange : Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCheckIn ? "Demande de check-in #${index + 1}" : "Départ #${index + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Client: ${data['userEmail'] ?? 'Non spécifié'}",
                                style: const TextStyle(color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        if (isCheckIn)
                          ElevatedButton(
                            onPressed: () {
                              // Action pour attribuer une chambre
                              _showAssignRoomDialog(context, reservation.id, data);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text("Attribuer chambre"),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 12),
                    
                    // Détails
                    _buildDetailRow("Type de chambre:", data['roomType'] ?? 'Non spécifié'),
                    _buildDetailRow("Arrivée:", DateFormat('dd/MM/yyyy').format(checkInDate)),
                    _buildDetailRow("Départ:", DateFormat('dd/MM/yyyy').format(checkOutDate)),
                    _buildDetailRow("Personnes:", "${data['guests'] ?? '1'}"),
                    _buildDetailRow("Montant total:", "${data['totalAmount'] ?? data['price'] ?? 0} FCFA"),
                    
                    // Afficher les documents soumis pour le check-in
                    if (isCheckIn && data['checkInDocuments'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            "Documents soumis:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(data['checkInDocuments'] as Map<String, dynamic>).entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    "${entry.key}: ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value.toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B4610).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCheckIn 
                          ? "Vérifier les documents et attribuer une chambre"
                          : "Vérifier l'état de la chambre et préparer la facture",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                        ),
                      ),
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

  void _showAssignRoomDialog(BuildContext context, String reservationId, Map<String, dynamic> data) {
    TextEditingController roomController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Attribuer une chambre'),
          content: TextField(
            controller: roomController,
            decoration: const InputDecoration(
              hintText: "Numéro de chambre",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (roomController.text.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance.collection('reservations').doc(reservationId).update({
                      'roomNumber': roomController.text,
                      'status': 'checked-in',
                      'actualCheckIn': FieldValue.serverTimestamp(),
                    });

                    // Créer une notification pour le client
                    if (data['userId'] != null) {
                      await FirebaseFirestore.instance.collection('notifications').add({
                        'userId': data['userId'],
                        'title': 'Check-in Confirmé',
                        'message': 'Votre check-in a été confirmé. Votre chambre est ${roomController.text}',
                        'type': 'reservation',
                        'reservationId': reservationId,
                        'status': 'unread',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }

                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Chambre ${roomController.text} attribuée avec succès!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Erreur: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610),
                foregroundColor: Colors.white,
              ),
              child: const Text('Attribuer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
        ],
      )
    );
  }
}

// Les classes ConversationsList et ChatPageReception restent similaires à votre code original
// mais adaptées pour utiliser les vraies données de Firestore

// --- PAGE LISTE DES CONVERSATIONS ---
class ConversationsList extends StatefulWidget {
  const ConversationsList({super.key});

  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('chats').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.black)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B4610))));
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return const Center(child: Text("Aucune conversation", style: TextStyle(color: Colors.black)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final data = chat.data() as Map<String, dynamic>;
            final lastMessage = data['lastMessage'] ?? '';
            final lastMessageTime = data['lastMessageTime'] as Timestamp?;
            final userEmail = data['userEmail'] ?? '';
            final userId = chat.id;

            String timeString = '';
            if (lastMessageTime != null) {
              timeString = DateFormat('dd/MM HH:mm').format(lastMessageTime.toDate());
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              elevation: 2,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF9B4610),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person),
                ),
                title: Text(userEmail, style: const TextStyle(color: Colors.black)),
                subtitle: Text(lastMessage, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black)),
                trailing: Text(timeString, style: const TextStyle(fontSize: 12, color: Colors.black)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPageReception(chatId: userId, userEmail: userEmail),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// --- PAGE CHAT POUR RÉCEPTIONNISTE ---
class ChatPageReception extends StatefulWidget {
  final String chatId;
  final String userEmail;

  const ChatPageReception({super.key, required this.chatId, required this.userEmail});

  @override
  State<ChatPageReception> createState() => _ChatPageReceptionState();
}

class _ChatPageReceptionState extends State<ChatPageReception> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  void sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final message = _controller.text.trim();

    // Ajouter le message à la sous-collection
    _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': user?.uid,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'senderEmail': user?.email,
    }).then((_) {
      // Mettre à jour le document chat avec le dernier message
      _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Faire défiler vers le bas après l'envoi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userEmail, style: const TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Liste des messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B4610)),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.black)),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            "Aucun message",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          const Text(
                            "Envoyez votre premier message",
                            style: TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == user?.uid;
                      final timestamp = data['timestamp'] as Timestamp?;
                      final time = timestamp != null
                          ? DateFormat.Hm().format(timestamp.toDate())
                          : '';
                      final sender = isMe ? "Vous" : data['senderEmail'] ?? "Client";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              const CircleAvatar(
                                backgroundColor: Color(0xFF9B4610),
                                foregroundColor: Colors.white,
                                child: Icon(Icons.person),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sender,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isMe 
                                          ? const Color(0xFF9B4610)
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color(0xFF9B4610)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft: isMe
                                            ? const Radius.circular(20)
                                            : const Radius.circular(4),
                                        bottomRight: isMe
                                            ? const Radius.circular(4)
                                            : const Radius.circular(20),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      data['message'],
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Text(
                                      time,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: const Color(0xFF9B4610).withOpacity(0.3),
                                foregroundColor: const Color(0xFF9B4610),
                                child: const Icon(Icons.support_agent),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Zone de saisie
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Écrire un message...",
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => setState(() {}),
                        onSubmitted: (value) => sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _controller.text.trim().isNotEmpty
                          ? const Color(0xFF9B4610)
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send,
                          color: _controller.text.trim().isNotEmpty
                              ? Colors.white
                              : Colors.grey[500]),
                      onPressed: _controller.text.trim().isNotEmpty
                          ? sendMessage
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}