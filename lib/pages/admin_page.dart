import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Hôtel Geneva',
      theme: ThemeData(
        primaryColor: const Color(0xFF9B4610),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF9B4610),
          secondary: const Color(0xFF9B4610),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F4E9),
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Color(0xFF9B4610)),
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            color: const Color(0xFF9B4610),
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: TextTheme(
          headlineMedium: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF9B4610),
          ),
          titleLarge: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
      home: const AdminPage(),
    );
  }
}

// --- PAGE ADMIN PRINCIPALE ---
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Widget> _pages = [
    const DashboardPage(),
    const AccountsList(),
    const ReservationsAdminList(),
    const OrdersAdminList(),
    const CheckInOutAdminList(),
    const ChatAdminList(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Administration Hôtel Geneva",
          style: GoogleFonts.roboto(
            fontSize: 20,
            color: const Color(0xFF9B4610),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF9B4610),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: "Se déconnecter",
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
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
            elevation: 0,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Tableau de bord"),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: "Utilisateurs"),
              BottomNavigationBarItem(icon: Icon(Icons.hotel), label: "Réservations"),
              BottomNavigationBarItem(icon: Icon(Icons.room_service), label: "Commandes"),
              BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Check-in/out"),
              BottomNavigationBarItem(icon: Icon(Icons.message), label: "Messages"),
            ],
          ),
        ),
      ),
    );
  }
}

// --- DASHBOARD PAGE ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tableau de bord",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          
          // Statistiques
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 600;
              return GridView.count(
                crossAxisCount: isWideScreen ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _buildStatCard("Clients", Icons.people, firestore.collection('users').where('role', isEqualTo: 'client')),
                  _buildStatCard("Réceptionnistes", Icons.support_agent, firestore.collection('users').where('role', isEqualTo: 'receptionniste')),
                  _buildStatCard("Réservations", Icons.hotel, firestore.collection('reservations')),
                  _buildStatCard("Commandes", Icons.restaurant, firestore.collection('orders')),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Actions rapides
          Text(
            "Actions rapides",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 600;
              return GridView.count(
                crossAxisCount: isWideScreen ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildActionButton("Nouvelle réservation", Icons.hotel, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomSelectionPage()));
                  }),
                  _buildActionButton("Voir rapports", Icons.bar_chart, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage()));
                  }),
                  _buildActionButton("Paramètres", Icons.settings, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                  }),
                  _buildActionButton("Support", Icons.support_agent, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportPage()));
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, IconData icon, Query query) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) count = snapshot.data!.docs.length;

        return Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(
            minHeight: 100,
            maxHeight: 120,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFF9B4610).withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: const Color(0xFF9B4610)),
              const SizedBox(height: 8),
              Text(
                title, 
                style: const TextStyle(
                  color: Colors.black87, 
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                "$count", 
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold, 
                  color: const Color(0xFF9B4610),
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 90,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B4610),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE DE RAPPORTS ---
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rapports"),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportCard("Rapport financier", "Analyse des revenus et dépenses", Icons.attach_money),
            const SizedBox(height: 16),
            _buildReportCard("Occupation des chambres", "Taux d'occupation par période", Icons.hotel),
            const SizedBox(height: 16),
            _buildReportCard("Satisfaction clients", "Avis et commentaires des clients", Icons.star),
            const SizedBox(height: 16),
            _buildReportCard("Performance du personnel", "Évaluation du personnel", Icons.people),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String title, String description, IconData icon) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, size: 40, color: const Color(0xFF9B4610)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          // Action pour voir le rapport détaillé
        },
      ),
    );
  }
}

// --- PAGE DE PARAMÈTRES ---
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paramètres"),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildSettingsOption("Notifications", Icons.notifications, () {}),
            _buildSettingsOption("Sécurité", Icons.security, () {}),
            _buildSettingsOption("Apparence", Icons.color_lens, () {}),
            _buildSettingsOption("Langue", Icons.language, () {}),
            _buildSettingsOption("Sauvegarde des données", Icons.backup, () {}),
            _buildSettingsOption("À propos", Icons.info, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsOption(String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF9B4610)),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}

// --- PAGE DE SUPPORT ---
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Support"),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Contactez notre équipe de support",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildContactOption("support@hotelgeneva.com", Icons.email),
            const SizedBox(height: 16),
            _buildContactOption("+225 XX XX XX XX", Icons.phone),
            const SizedBox(height: 16),
            _buildContactOption("Notre centre de service", Icons.location_on),
            const SizedBox(height: 30),
            const Text(
              "FAQ - Questions fréquentes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFaqItem("Comment modifier une réservation ?"),
            _buildFaqItem("Comment annuler une commande ?"),
            _buildFaqItem("Comment gérer les utilisateurs ?"),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption(String text, IconData icon) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF9B4610)),
        title: Text(text),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          // Action pour contacter
        },
      ),
    );
  }

  Widget _buildFaqItem(String question) {
    return ExpansionTile(
      title: Text(question),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Réponse à la question $question...",
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

// --- PAGE DE SÉLECTION DE CHAMBRE ---
class RoomSelectionPage extends StatelessWidget {
  const RoomSelectionPage({super.key});

  final List<Map<String, dynamic>> rooms = const [
    {
      "title": "Chambre Deluxe",
      "price": 75000,
      "image": "assets/images/deluxe.jpg",
      "description": "Idéale pour les courts séjours. Lit double, WiFi, salle de bain privée.",
      "features": ["Lit double", "Climatisation", "Wi-Fi", "Télévision"],
    },
    {
      "title": "Chambre Premium",
      "price": 40000,
      "image": "assets/images/premium.jpg",
      "description": "Spacieuse et confortable avec balcon privé et vue sur la ville.",
      "features": ["Lit Queen", "Balcon", "Wi-Fi", "Petit déjeuner inclus"],
    },
    {
      "title": "Suite Prestige",
      "price": 70000,
      "image": "assets/images/prestige.jpg",
      "description": "Expérience de luxe avec salon, jacuzzi, et service VIP.",
      "features": ["Salon privé", "Jacuzzi", "Room service", "Vue panoramique"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sélectionner une chambre"),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return Card(
            elevation: 6,
            shadowColor: Colors.black26,
            margin: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Image.asset(
                    room["image"],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: const Color(0xFF9B4610).withOpacity(0.1),
                        child: const Icon(Icons.hotel, size: 50, color: Color(0xFF9B4610)),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room["title"],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${room["price"]} FCFA / nuit",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF9B4610),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room["description"],
                        style: const TextStyle(color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: List.generate(room["features"].length, (i) {
                          return Chip(
                            label: Text(room["features"][i]),
                            backgroundColor: const Color(0xFF9B4610).withOpacity(0.2),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text("Réserver"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B4610),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminReservationForm(
                                  roomTitle: room["title"],
                                  roomPrice: room["price"],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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

// --- FORMULAIRE DE RÉSERVATION POUR ADMIN ---
class AdminReservationForm extends StatefulWidget {
  final String roomTitle;
  final int roomPrice;

  const AdminReservationForm({super.key, required this.roomTitle, required this.roomPrice});

  @override
  State<AdminReservationForm> createState() => _AdminReservationFormState();
}

class _AdminReservationFormState extends State<AdminReservationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  DateTime? _arrivalDate;
  DateTime? _departureDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedPaymentMethod = 'espèces';
  int _totalNights = 0;
  int _totalPrice = 0;

  @override
  void initState() {
    super.initState();
    _roomController.text = widget.roomTitle;
    _priceController.text = widget.roomPrice.toString();
    _totalPrice = widget.roomPrice;
  }

  Future<void> _selectDate(BuildContext context, bool isArrival) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    
    if (picked != null) {
      setState(() {
        if (isArrival) {
          _arrivalDate = picked;
          _arrivalController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _departureDate = picked;
          _departureController.text = DateFormat('dd/MM/yyyy').format(picked);
        }
        
        // Calculer le nombre de nuits et le prix total
        _calculateTotal();
      });
    }
  }

  void _calculateTotal() {
    if (_arrivalDate != null && _departureDate != null) {
      final difference = _departureDate!.difference(_arrivalDate!);
      _totalNights = difference.inDays;
      _totalPrice = widget.roomPrice * _totalNights;
      _priceController.text = _totalPrice.toString();
    }
  }

  Future<void> _submitReservation() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Simuler le processus de paiement
        if (_selectedPaymentMethod == 'carte') {
          // Afficher le formulaire de paiement
          final paymentSuccess = await _showPaymentDialog(context);
          if (!paymentSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paiement échoué')),
            );
            return;
          }
        }
        
        await _firestore.collection('reservations').add({
          'clientName': _clientNameController.text,
          'clientEmail': _clientEmailController.text,
          'room': _roomController.text,
          'arrival': Timestamp.fromDate(_arrivalDate!),
          'departure': Timestamp.fromDate(_departureDate!),
          'nights': _totalNights,
          'guests': int.parse(_guestsController.text),
          'totalPrice': _totalPrice,
          'status': 'confirmée',
          'paymentMethod': _selectedPaymentMethod,
          'paymentStatus': _selectedPaymentMethod == 'carte' ? 'payé' : 'en attente',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'admin',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation créée avec succès')),
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<bool> _showPaymentDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Paiement par carte"),
          content: SizedBox(
            height: 300,
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: "Numéro de carte"),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Date d'expiration (MM/AA)"),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: "CVV"),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Nom du titulaire"),
                ),
                const SizedBox(height: 20),
                Text(
                  "Montant: $_totalPrice FCFA",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610),
                foregroundColor: Colors.white,
              ),
              child: const Text("Payer"),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _roomController.dispose();
    _arrivalController.dispose();
    _departureController.dispose();
    _guestsController.dispose();
    _priceController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle réservation (Admin)'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du client',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email du client',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un email';
                  }
                  if (!value.contains('@')) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Chambre',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _arrivalController,
                decoration: InputDecoration(
                  labelText: 'Date d\'arrivée',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner une date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departureController,
                decoration: InputDecoration(
                  labelText: 'Date de départ',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner une date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_totalNights > 0)
                Text(
                  "Nombre de nuits: $_totalNights",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _guestsController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de personnes',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null) {
                    return 'Veuillez entrer un nombre valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Prix total',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                readOnly: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Méthode de paiement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'espèces', child: Text('Espèces')),
                  DropdownMenuItem(value: 'carte', child: Text('Carte bancaire')),
                  DropdownMenuItem(value: 'virement', child: Text('Virement bancaire')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitReservation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B4610),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Créer la réservation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// --- GESTION DES COMPTES ---
class AccountsList extends StatefulWidget {
  const AccountsList({super.key});

  @override
  State<AccountsList> createState() => _AccountsListState();
}

class _AccountsListState extends State<AccountsList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _filterRole = 'tous';

  Future<void> _deleteAccount(String userId, String email) async {
    final currentUser = _auth.currentUser;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: Text("Êtes-vous sûr de vouloir supprimer le compte de $email ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Vérifier si l'utilisateur supprime son propre compte
                  final isDeletingOwnAccount = currentUser != null && currentUser.uid == userId;
                  
                  await _firestore.collection('users').doc(userId).delete();
                  
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Compte $email supprimé avec succès")),
                  );
                  
                  // Si l'utilisateur supprime son propre compte, le déconnecter
                  if (isDeletingOwnAccount) {
                    await _auth.signOut();
                    // La navigation vers la page de connexion sera gérée automatiquement
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur lors de la suppression: $e")),
                  );
                }
              },
              child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  Future<void> _editAccount(String userId, Map<String, dynamic> userData) async {
    TextEditingController nameController = TextEditingController(text: userData['name'] ?? '');
    TextEditingController emailController = TextEditingController(text: userData['email'] ?? '');
    String selectedRole = userData['role'] ?? 'client';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Modifier le compte"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nom"),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                  enabled: false,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  onChanged: (value) => selectedRole = value!,
                  items: const [
                    DropdownMenuItem(value: 'client', child: Text('Client')),
                    DropdownMenuItem(value: 'receptionniste', child: Text('Réceptionniste')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                  ],
                  decoration: const InputDecoration(labelText: 'Rôle'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _firestore.collection('users').doc(userId).update({
                    'name': nameController.text,
                    'role': selectedRole,
                  });
                  
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Compte modifié avec succès")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur lors de la modification: $e")),
                  );
                }
              },
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Query usersQuery = _firestore.collection('users');
    if (_filterRole != 'tous') {
      usersQuery = usersQuery.where('role', isEqualTo: _filterRole);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text("Filtrer par rôle:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _filterRole,
                      onChanged: (String? newValue) {
                        setState(() {
                          _filterRole = newValue!;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 'tous', child: Text("Tous les utilisateurs")),
                        DropdownMenuItem(value: 'client', child: Text("Clients")),
                        DropdownMenuItem(value: 'receptionniste', child: Text("Réceptionnistes")),
                        DropdownMenuItem(value: 'admin', child: Text("Administrateurs")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: usersQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              
              final users = snapshot.data!.docs;
              
              if (users.isEmpty) {
                return const Center(child: Text("Aucun utilisateur trouvé"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final data = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  final name = data['name'] ?? 'Sans nom';
                  final email = data['email'] ?? 'Sans email';
                  final role = data['role'] ?? 'client';

                  Color roleColor;
                  switch (role) {
                    case 'admin':
                      roleColor = const Color(0xFF9B4610);
                      break;
                    case 'receptionniste':
                      roleColor = const Color(0xFF9B4610);
                      break;
                    default:
                      roleColor = const Color(0xFF9B4610);
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.white,
                    elevation: 4,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF9B4610).withOpacity(0.2),
                        foregroundColor: const Color(0xFF9B4610),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.black)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(color: Colors.black87)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editAccount(userId, data),
                            tooltip: "Modifier",
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAccount(userId, email),
                            tooltip: "Supprimer",
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
      ],
    );
  }
}

// --- RÉSERVATIONS ADMIN ---
class ReservationsAdminList extends StatelessWidget {
  const ReservationsAdminList({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('reservations').orderBy('createdAt', descending: true).snapshots(),
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
                ? DateFormat('dd/MM/yyyy').format((data['arrival'] as Timestamp).toDate())
                : 'Date inconnue';
            final departure = data['departure'] != null 
                ? DateFormat('dd/MM/yyyy').format((data['departure'] as Timestamp).toDate())
                : 'Date inconnue';
            final totalPrice = data['totalPrice'] ?? '0';
            final nights = data['nights'] ?? '1';

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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              firestore.collection('reservations').doc(reservationId).update({'status': 'annulée'});
                              _sendNotification(clientName, "Votre réservation a été annulée");
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
                              firestore.collection('reservations').doc(reservationId).update({'status': 'confirmée'});
                              _sendNotification(clientName, "Votre réservation a été confirmée");
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
                              firestore.collection('reservations').doc(reservationId).update({'status': 'annulée'});
                              _sendNotification(clientName, "Votre réservation a été annulée");
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
            child: Text(
              value,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      )
    );
  }

  void _sendNotification(String clientName, String message) {
    // Cette fonction simule l'envoi d'une notification
    // Dans une application réelle, vous utiliseriez Firebase Cloud Messaging ou un service similaire
    print("Notification envoyée à $clientName: $message");
  }
}

// --- COMMANDES ADMIN ---
class OrdersAdminList extends StatelessWidget {
  const OrdersAdminList({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('orders').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        
        final orders = snapshot.data!.docs;
        
        if (orders.isEmpty) {
          return const Center(child: Text("Aucune commande trouvée"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final data = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;
            final clientName = data['clientName'] ?? 'Client inconnu';
            final room = data['room'] ?? 'Chambre inconnue';
            final item = data['item'] ?? 'Article inconnu';
            final status = data['status'] ?? 'en attente';
            final total = data['total'] ?? '0';

            Color statusColor;
            switch (status) {
              case 'livrée':
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
                          "Commande #${index + 1}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    _buildInfoRow("Article:", item),
                    _buildInfoRow("Total:", "$total FCFA"),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'en attente') ...[
                          OutlinedButton(
                            onPressed: () {
                              firestore.collection('orders').doc(orderId).update({'status': 'annulée'});
                              _sendNotification(clientName, "Votre commande a été annulée");
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
                              firestore.collection('orders').doc(orderId).update({'status': 'livrée'});
                              _sendNotification(clientName, "Votre commande a été livrée");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Confirmer"),
                          ),
                        ],
                        if (status == 'livrée')
                          Text(
                            "Commande livrée",
                            style: TextStyle(
                              color: const Color(0xFF9B4610),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (status == 'annulée')
                          Text(
                            "Commande annulée",
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
            child: Text(
              value,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      )
    );
  }

  void _sendNotification(String clientName, String message) {
    // Cette fonction simule l'envoi d'une notification
    print("Notification envoyée à $clientName: $message");
  }
}

// --- CHECK-IN / CHECK-OUT ADMIN ---
class CheckInOutAdminList extends StatelessWidget {
  const CheckInOutAdminList({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const TabBar(
              labelColor: Color(0xFF9B4610),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF9B4610),
              tabs: [
                Tab(icon: Icon(Icons.login), text: "Arrivées"),
                Tab(icon: Icon(Icons.logout), text: "Départs"),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF8F4E9),
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
    final firestore = FirebaseFirestore.instance;
    String collection = isCheckIn ? 'checkins' : 'checkouts';

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection(collection).orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        
        final checks = snapshot.data!.docs;
        
        if (checks.isEmpty) {
          return const Center(child: Text("Aucune donnée trouvée"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: checks.length,
          itemBuilder: (context, index) {
            final data = checks[index].data() as Map<String, dynamic>;
            final checkId = checks[index].id;
            final clientName = data['clientName'] ?? 'Client inconnu';
            final room = data['room'] ?? 'Chambre inconnue';
            final date = data['date'] != null 
                ? DateFormat('dd/MM/yyyy HH:mm').format((data['date'] as Timestamp).toDate())
                : 'Date inconnue';
            final status = data['status'] ?? 'en attente';

            Color statusColor;
            switch (status) {
              case 'confirmé':
                statusColor = const Color(0xFF9B4610);
                break;
              case 'annulé':
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
                          isCheckIn ? "Arrivée #${index + 1}" : "Départ #${index + 1}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    _buildInfoRow("Date:", date),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'en attente') ...[
                          OutlinedButton(
                            onPressed: () {
                              firestore.collection(isCheckIn ? 'checkins' : 'checkouts').doc(checkId).update({'status': 'annulé'});
                              _sendNotification(clientName, "Votre ${isCheckIn ? 'check-in' : 'check-out'} a été annulé");
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
                              firestore.collection(isCheckIn ? 'checkins' : 'checkouts').doc(checkId).update({'status': 'confirmé'});
                              _sendNotification(clientName, "Votre ${isCheckIn ? 'check-in' : 'check-out'} a été confirmé");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isCheckIn ? "Confirmer Check-in" : "Confirmer Check-out"),
                          ),
                        ],
                        if (status == 'confirmé')
                          Text(
                            isCheckIn ? "Check-in confirmé" : "Check-out confirmé",
                            style: TextStyle(
                              color: const Color(0xFF9B4610),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (status == 'annulé')
                          Text(
                            isCheckIn ? "Check-in annulé" : "Check-out annulé",
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
            child: Text(
              value,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      )
    );
  }

  void _sendNotification(String clientName, String message) {
    // Cette fonction simule l'envoi d'une notification
    print("Notification envoyée à $clientName: $message");
  }
}

// --- MESSAGERIE ADMIN ---
class ChatAdminList extends StatefulWidget {
  const ChatAdminList({super.key});

  @override
  State<ChatAdminList> createState() => _ChatAdminListState();
}

class _ChatAdminListState extends State<ChatAdminList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: "Rechercher une conversation",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('chats').orderBy('lastMessageTime', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              
              final chats = snapshot.data!.docs;
              
              if (chats.isEmpty) {
                return const Center(child: Text("Aucune conversation trouvée"));
              }

              // Filtrer les conversations selon la recherche
              final filteredChats = chats.where((chat) {
                final data = chat.data() as Map<String, dynamic>;
                final userEmail = data['userEmail'] ?? "";
                return userEmail.toLowerCase().contains(_searchController.text.toLowerCase());
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredChats.length,
                itemBuilder: (context, index) {
                  final data = filteredChats[index].data() as Map<String, dynamic>;
                  final chatId = filteredChats[index].id;
                  final lastMessage = data['lastMessage'] ?? "";
                  final userEmail = data['userEmail'] ?? "";
                  final lastMessageTime = data['lastMessageTime'] != null 
                      ? DateFormat('dd/MM HH:mm').format((data['lastMessageTime'] as Timestamp).toDate())
                      : "";
                  final hasNewMessages = data['hasNewMessages'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.white,
                    elevation: 4,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF9B4610),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.person),
                      ),
                      title: Text(userEmail, style: const TextStyle(color: Colors.black)),
                      subtitle: Text(lastMessage, 
                        style: const TextStyle(color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(lastMessageTime, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          if (hasNewMessages)
                            const Icon(Icons.circle, color: Colors.red, size: 12),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => ChatAdminPage(
                              chatId: chatId, 
                              userEmail: userEmail,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- PAGE DE CHAT ADMIN ---
class ChatAdminPage extends StatefulWidget {
  final String chatId;
  final String userEmail;

  const ChatAdminPage({super.key, required this.chatId, required this.userEmail});

  @override
  State<ChatAdminPage> createState() => _ChatAdminPageState();
}

class _ChatAdminPageState extends State<ChatAdminPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Marquer les messages comme lus
    _firestore.collection('chats').doc(widget.chatId).update({
      'hasNewMessages': false,
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      // Ajouter le message
      await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
        'text': _messageController.text.trim(),
        'sender': 'admin',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Mettre à jour le dernier message
      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': _messageController.text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasNewMessages': true,
      });

      _messageController.clear();

      // Faire défiler vers le bas
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userEmail),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isAdmin = message['sender'] == 'admin';
                    final text = message['text'] ?? '';
                    final timestamp = message['timestamp'] != null
                        ? DateFormat('HH:mm').format((message['timestamp'] as Timestamp).toDate())
                        : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isAdmin) 
                            const CircleAvatar(
                              backgroundColor: Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                              child: Icon(Icons.person, size: 20),
                            ),
                          if (!isAdmin) const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAdmin 
                                    ? const Color(0xFF9B4610)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isAdmin ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timestamp,
                                    style: TextStyle(
                                      color: isAdmin ? Colors.white70 : Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isAdmin) const SizedBox(width: 8),
                          if (isAdmin)
                            const CircleAvatar(
                              backgroundColor: Color(0xFF9B4610),
                              foregroundColor: Colors.white,
                              child: Icon(Icons.support_agent, size: 20),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Écrire un message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF9B4610),
                  foregroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
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