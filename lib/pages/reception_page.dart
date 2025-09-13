import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLOSTAY - Réception',
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
          backgroundColor: const Color(0xFF9B4610),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          if (snapshot.hasData) {
            return const ReceptionPage();
          }
          
          return const LoginPage();
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Vérifier le rôle de l'utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
          
      if (userDoc.exists && userDoc.data()!['role'] == 'receptionniste') {
        // Connexion réussie pour réceptionniste
      } else {
        // Déconnecter si l'utilisateur n'a pas le bon rôle
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accès réservé au personnel de réception')),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4E9),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: kIsWeb ? 500 : 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo avec la couleur thématique
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B4610),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'FLOSTAY',
                  style: GoogleFonts.roboto(
                    fontSize: kIsWeb ? 40 : 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Espace Réception',
                style: TextStyle(
                  fontSize: kIsWeb ? 20 : 16, 
                  color: const Color(0xFF9B4610),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Color(0xFF9B4610)),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF9B4610)),
                  ),
                  labelStyle: TextStyle(color: Color(0xFF9B4610)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF9B4610)),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF9B4610)),
                  ),
                  labelStyle: TextStyle(color: Color(0xFF9B4610)),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B4610),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Se connecter'),
                ),
              ),
            ],
          ),
        ),
      ),
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _unreadNotifications = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    const DashboardPage(), // Tableau de bord en première position
    const ReservationsList(),
    const OrdersList(),
    const CheckInOutList(),
    const ConversationsList(),
    const AlertsPage(), // Page des alertes
  ];

  final List<String> _appBarTitles = [
    "Tableau de Bord",
    "Gestion des Réservations",
    "Suivi des Commandes",
    "Check-in/Check-out",
    "Messages Clients",
    "Alertes Clients"
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
  }

  void _loadUnreadNotifications() async {
    final user = _auth.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .where('receptionistId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'unread')
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _unreadNotifications = snapshot.size;
        });
      });
    }
  }

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
    // Layout pour le web avec drawer (pas de sidebar fixe)
    if (kIsWeb) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: Text(
            _appBarTitles[_selectedIndex],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF9B4610),
          foregroundColor: Colors.white,
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    _showNotificationsDialog();
                  },
                  tooltip: "Notifications",
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: "Se déconnecter",
            ),
          ],
        ),
        drawer: Drawer(
          child: Container(
            color: const Color(0xFF9B4610),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF9B4610),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FLOSTAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _auth.currentUser?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(Icons.dashboard, "Tableau de bord", 0),
                _buildDrawerItem(Icons.hotel, "Réservations", 1),
                _buildDrawerItem(Icons.room_service, "Commandes", 2),
                _buildDrawerItem(Icons.check_circle, "Check-in/out", 3),
                _buildDrawerItem(Icons.message, "Messages", 4),
                _buildDrawerItem(Icons.warning, "Alertes", 5),
                const Divider(color: Colors.white54),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ),
        body: _pages[_selectedIndex], // Le corps prend toute la largeur
      );
    } else {
      // Layout pour mobile avec navigation en bas
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: Text(
            _appBarTitles[_selectedIndex],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF9B4610),
          foregroundColor: Colors.white,
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    _showNotificationsDialog();
                  },
                  tooltip: "Notifications",
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        drawer: Drawer(
          child: Container(
            color: const Color(0xFF9B4610),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF9B4610),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FLOSTAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _auth.currentUser?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(Icons.dashboard, "Tableau de bord", 0),
                _buildDrawerItem(Icons.hotel, "Réservations", 1),
                _buildDrawerItem(Icons.room_service, "Commandes", 2),
                _buildDrawerItem(Icons.check_circle, "Check-in/out", 3),
                _buildDrawerItem(Icons.message, "Messages", 4),
                _buildDrawerItem(Icons.warning, "Alertes", 5),
                const Divider(color: Colors.white54),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF9B4610),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            backgroundColor: const Color(0xFF9B4610),
            showUnselectedLabels: true,
            elevation: 10,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: "Dashboard",
              ),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.warning),
                label: "Alertes",
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        _onItemTapped(index);
        Navigator.pop(context); // Close the drawer
      },
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notifications', style: TextStyle(color: Color(0xFF9B4610))),
          content: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('receptionistId', isEqualTo: _auth.currentUser?.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text("Aucune notification");
              }
              
              final notifications = snapshot.data!.docs;
              
              return SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final data = notification.data() as Map<String, dynamic>;
                    final timestamp = data['createdAt'] as Timestamp?;
                    
                    return ListTile(
                      title: Text(data['title'] ?? 'Notification'),
                      subtitle: Text(data['message'] ?? ''),
                      trailing: Text(timestamp != null 
                          ? DateFormat('dd/MM HH:mm').format(timestamp.toDate())
                          : ''),
                      onTap: () {
                        // Marquer comme lu
                        FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(notification.id)
                            .update({'status': 'read'});
                      },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer', style: TextStyle(color: Color(0xFF9B4610))),
            ),
          ],
        );
      },
    );
  }
}
// ... (le code précédent reste inchangé jusqu'à la classe DashboardPage)

// NOUVELLE PAGE: TABLEAU DE BORD
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // Fonction pour parser les dates (gère à la fois Timestamp et String)
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      try {
        return DateFormat('dd/MM/yyyy').parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    } else {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tableau de Bord',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 20),
          
          // Première ligne de statistiques
          Row(
            children: [
              // Réservations en attente
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.where((res) {
                      final data = res.data() as Map<String, dynamic>;
                      return data['status'] == 'pending';
                    }).length;
                  }
                  return _buildStatCard('Réservations en attente', count, Colors.orange);
                },
              ),
              const SizedBox(width: 16),
              
              // Réservations confirmées
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.where((res) {
                      final data = res.data() as Map<String, dynamic>;
                      return data['status'] == 'confirmed';
                    }).length;
                  }
                  return _buildStatCard('Réservations confirmées', count, Colors.green);
                },
              ),
              const SizedBox(width: 16),
              
              // Clients check-in
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.where((res) {
                      final data = res.data() as Map<String, dynamic>;
                      return data['status'] == 'checked-in';
                    }).length;
                  }
                  return _buildStatCard('Clients check-in', count, Colors.blue);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Deuxième ligne de statistiques
          Row(
            children: [
              // Clients check-out
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.where((res) {
                      final data = res.data() as Map<String, dynamic>;
                      return data['status'] == 'checked-out';
                    }).length;
                  }
                  return _buildStatCard('Clients check-out', count, Colors.purple);
                },
              ),
              const SizedBox(width: 16),
              
              // Alertes non résolues
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.where((alert) {
                      final data = alert.data() as Map<String, dynamic>;
                      return data['status'] != 'resolved';
                    }).length;
                  }
                  return _buildStatCard('Alertes non résolues', count, Colors.red);
                },
              ),
              const SizedBox(width: 16),
              
              // Commandes en cours
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('commandes').snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    count = snapshot.data!.docs.where((cmd) {
                      final data = cmd.data() as Map<String, dynamic>;
                      return data['statut'] == 'en_attente' || data['statut'] == 'en_cours';
                    }).length;
                  }
                  return _buildStatCard('Commandes en cours', count, Colors.amber);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Dernières réservations
          const Text(
            'Dernières réservations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 16),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final reservations = snapshot.data!.docs;
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  final reservation = reservations[index];
                  final data = reservation.data() as Map<String, dynamic>;
                  
                  return ListTile(
                    leading: const Icon(Icons.hotel, color: Color(0xFF9B4610)),
                    title: Text(data['userEmail'] ?? 'Client'),
                    subtitle: Text('Chambre: ${data['roomType'] ?? 'N/A'}'),
                    trailing: Text(
                      DateFormat('dd/MM').format(_parseDate(data['checkInDate'])),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dialogue pour créer une réservation
class CreateReservationDialog extends StatefulWidget {
  const CreateReservationDialog({super.key});

  @override
  State<CreateReservationDialog> createState() => _CreateReservationDialogState();
}

class _CreateReservationDialogState extends State<CreateReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _roomTypeController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController();
  final TextEditingController _checkInDateController = TextEditingController();
  final TextEditingController _checkOutDateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle Réservation'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(labelText: 'Nom du client'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du client';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _clientEmailController,
                decoration: const InputDecoration(labelText: 'Email du client'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer l\'email du client';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _clientPhoneController,
                decoration: const InputDecoration(labelText: 'Téléphone du client'),
              ),
              TextFormField(
                controller: _roomTypeController,
                decoration: const InputDecoration(labelText: 'Type de chambre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le type de chambre';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _guestsController,
                decoration: const InputDecoration(labelText: 'Nombre de personnes'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _checkInDateController,
                decoration: const InputDecoration(labelText: 'Date d\'arrivée (jj/mm/aaaa)'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    _checkInDateController.text = DateFormat('dd/MM/yyyy').format(date);
                  }
                },
              ),
              TextFormField(
                controller: _checkOutDateController,
                decoration: const InputDecoration(labelText: 'Date de départ (jj/mm/aaaa)'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    _checkOutDateController.text = DateFormat('dd/MM/yyyy').format(date);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              // Enregistrer la réservation
              await FirebaseFirestore.instance.collection('reservations').add({
                'userName': _clientNameController.text,
                'userEmail': _clientEmailController.text,
                'userPhone': _clientPhoneController.text,
                'roomType': _roomTypeController.text,
                'guests': int.tryParse(_guestsController.text) ?? 1,
                'checkInDate': _checkInDateController.text,
                'checkOutDate': _checkOutDateController.text,
                'status': 'confirmed', // directement confirmée
                'createdAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}


// PAGE DES ALERTES CLIENTS
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Alertes des clients",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Toutes', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Nouvelles', 'new'),
                    const SizedBox(width: 8),
                    _buildFilterChip('En cours', 'in_progress'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Résolues', 'resolved'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('alerts')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAlerts = snapshot.data!.docs;
              
              // Filtrage local au lieu de filtrage côté serveur
              final filteredAlerts = _filterStatus == 'all'
                  ? allAlerts
                  : allAlerts.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['status'] == _filterStatus;
                    }).toList();

              if (filteredAlerts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filterStatus == 'all'
                            ? "Aucune alerte"
                            : _filterStatus == 'new'
                                ? "Aucune nouvelle alerte"
                                : _filterStatus == 'in_progress'
                                    ? "Aucune alerte en cours"
                                    : "Aucune alerte résolue",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredAlerts.length,
                itemBuilder: (context, index) {
                  final alert = filteredAlerts[index];
                  final data = alert.data() as Map<String, dynamic>;
                  
                  return AlertCard(
                    alertId: alert.id,
                    data: data,
                    onStatusChanged: () {
                      setState(() {});
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _filterStatus == value,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.grey[300],
      selectedColor: const Color(0xFF9B4610),
      labelStyle: TextStyle(
        color: _filterStatus == value ? Colors.white : Colors.black,
      ),
    );
  }
}

// CARTE ALERTE AVEC INTERACTIONS
class AlertCard extends StatefulWidget {
  final String alertId;
  final Map<String, dynamic> data;
  final VoidCallback onStatusChanged;

  const AlertCard({
    super.key,
    required this.alertId,
    required this.data,
    required this.onStatusChanged,
  });

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  bool _isUpdating = false;

  Future<void> _updateAlertStatus(String status) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('alerts')
          .doc(widget.alertId)
          .update({
        'status': status,
        'updatedBy': currentUser?.email ?? 'Réceptionniste',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.onStatusChanged();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alerte marquée comme ${_getStatusText(status)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _deleteAlert() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Êtes-vous sûr de vouloir supprimer cette alerte ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isUpdating = true;
      });

      try {
        await FirebaseFirestore.instance
            .collection('alerts')
            .doc(widget.alertId)
            .delete();

        widget.onStatusChanged();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'new':
        return 'Nouvelle';
      case 'in_progress':
        return 'En cours';
      case 'resolved':
        return 'Résolue';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final timestamp = data['timestamp'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    final time = timestamp != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(timestamp.toDate())
        : 'Date inconnue';
    final updatedTime = updatedAt != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(updatedAt.toDate())
        : null;

    final status = data['status'] ?? 'new';
    final roomNumber = data['roomNumber'] ?? 'Non spécifié';
    final userEmail = data['userEmail'] ?? 'Non spécifié';
    final userName = data['userName'] ?? 'Client';
    final message = data['message'] ?? 'Aucune description';
    final title = data['title'] ?? 'Alerte';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(status),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            if (_isUpdating)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            
            Opacity(
              opacity: _isUpdating ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
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
                  _buildInfoRow("Client:", "$userName ($userEmail)"),
                  _buildInfoRow("Chambre:", roomNumber),
                  _buildInfoRow("Date:", time),
                  if (updatedTime != null)
                    _buildInfoRow("Dernière mise à jour:", updatedTime),
                  if (data['updatedBy'] != null)
                    _buildInfoRow("Traité par:", data['updatedBy']),
                  const SizedBox(height: 12),
                  const Text(
                    "Description:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (status != 'resolved')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (status == 'new')
                          ElevatedButton(
                            onPressed: _isUpdating
                                ? null
                                : () => _updateAlertStatus('in_progress'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Prendre en charge"),
                          ),
                        if (status == 'in_progress')
                          ElevatedButton(
                            onPressed: _isUpdating
                                ? null
                                : () => _updateAlertStatus('resolved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Marquer comme résolu"),
                          ),
                        IconButton(
                          onPressed: _isUpdating ? null : _deleteAlert,
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  
                  if (status == 'resolved')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _isUpdating
                              ? null
                              : () => _updateAlertStatus('in_progress'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Rouvrir l'alerte"),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _isUpdating ? null : _deleteAlert,
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Le reste du code (ReservationsList, OrdersList, CheckInOutList, etc.) reste inchangé
// ... [Tout le code existant pour les autres pages] ...
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

// ... (Les autres classes ReservationCard, OrdersList, CheckInOutList, etc. restent inchangées)

// --- PAGE LISTE DES CONVERSATIONS AVEC RECHERCHE ---
class ConversationsList extends StatefulWidget {
  const ConversationsList({super.key});

  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Rechercher une conversation...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('chats').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.black)));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B4610))));
              }

              final chats = snapshot.data!.docs;

              // Filtrer les conversations selon la recherche
              final filteredChats = chats.where((chat) {
                final data = chat.data() as Map<String, dynamic>;
                final userEmail = data['userEmail']?.toString().toLowerCase() ?? "";
                final lastMessage = data['lastMessage']?.toString().toLowerCase() ?? "";
                
                return userEmail.contains(_searchQuery) || lastMessage.contains(_searchQuery);
              }).toList();

              if (filteredChats.isEmpty) {
                return const Center(child: Text("Aucune conversation", style: TextStyle(color: Colors.black)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredChats.length,
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
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
                            builder: (context) => ChatPageReceptionV2(chatId: userId, userEmail: userEmail),
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

// ... (Les autres classes comme ChatPageReception, CheckInRequestCard, etc. restent inchangées)
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
           // Correction de la section d'affichage des documents
if (widget.data['checkInDocuments'] != null)
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
                  text: "Demandes Check-in",
                ),
                Tab(
                  icon: Icon(Icons.logout),
                  text: "Demandes Check-out",
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: TabBarView(
                children: [
                  _buildCheckInRequests(),
                  _buildCheckOutRequests(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('checkin_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Center(
            child: Text(
              "Aucune demande de check-in en attente",
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            
            return CheckInRequestCard(
              requestId: request.id,
              data: data,
            );
          },
        );
      },
    );
  }

  Widget _buildCheckOutRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('checkout_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Center(
            child: Text(
              "Aucune demande de check-out en attente",
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            
            return CheckOutRequestCard(
              requestId: request.id,
              data: data,
            );
          },
        );
      },
    );
  }
}

class CheckInRequestCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const CheckInRequestCard({
    super.key,
    required this.requestId,
    required this.data,
  });

  @override
  State<CheckInRequestCard> createState() => _CheckInRequestCardState();
}

class _CheckInRequestCardState extends State<CheckInRequestCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _roomNumberController = TextEditingController();

  Future<void> _approveCheckIn() async {
    try {
      // Mettre à jour la demande de check-in
      await _firestore.collection('checkin_requests').doc(widget.requestId).update({
        'status': 'approved',
        'roomNumber': _roomNumberController.text,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Mettre à jour la réservation si elle existe
      if (widget.data['reservationId'] != null) {
        await _firestore.collection('reservations').doc(widget.data['reservationId']).update({
          'status': 'checked-in',
          'roomNumber': _roomNumberController.text,
          'actualCheckIn': FieldValue.serverTimestamp(),
        });
      }

      // Envoyer une notification au client
      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'title': 'Check-in Approuvé',
        'message': 'Votre check-in a été approuvé. Votre chambre est ${_roomNumberController.text}',
        'type': 'checkin',
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-in approuvé avec succès!"),
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

  Future<void> _rejectCheckIn() async {
    try {
      // Mettre à jour la demande de check-in
      await _firestore.collection('checkin_requests').doc(widget.requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Envoyer une notification au client
      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'title': 'Check-in Rejeté',
        'message': 'Votre demande de check-in a été rejetée. Veuillez contacter la réception.',
        'type': 'checkin',
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-in rejeté!"),
          backgroundColor: Colors.red,
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

  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Approuver le check-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Attribuez un numéro de chambre:'),
              const SizedBox(height: 10),
              TextField(
                controller: _roomNumberController,
                decoration: const InputDecoration(
                  hintText: "Numéro de chambre",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_roomNumberController.text.isNotEmpty) {
                  _approveCheckIn();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610),
                foregroundColor: Colors.white,
              ),
              child: const Text('Approuver'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkInDate = widget.data['checkInDate'] is Timestamp
        ? (widget.data['checkInDate'] as Timestamp).toDate()
        : DateTime.now();

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
                    "Demande de check-in #${widget.requestId.substring(0, 8)}",
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
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange,
                    ),
                  ),
                  child: const Text(
                    "En attente",
                    style: TextStyle(
                      color: Colors.orange,
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
            _buildInfoRow("Client:", widget.data['clientName'] ?? 'Non spécifié'),
            _buildInfoRow("Email:", widget.data['clientEmail'] ?? 'Non spécifié'),
            _buildInfoRow("Téléphone:", widget.data['clientPhone'] ?? 'Non spécifié'),
            _buildInfoRow("Type de pièce:", widget.data['idType'] ?? 'Non spécifié'),
            _buildInfoRow("Numéro de pièce:", widget.data['idNumber'] ?? 'Non spécifié'),
            if (widget.data['hasReservation'] != null && widget.data['hasReservation'])
              _buildInfoRow("Avec réservation:", "Oui"),
            if (widget.data['hasReservation'] != null && !widget.data['hasReservation'])
              _buildInfoRow("Avec réservation:", "Non"),
            _buildInfoRow("Date demande:", DateFormat('dd/MM/yyyy à HH:mm').format(checkInDate)),
            
            if (widget.data['specialRequests'] != null && widget.data['specialRequests'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    "Demandes spéciales:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.data['specialRequests'],
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _rejectCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Rejeter"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _showApproveDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B4610),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Approuver"),
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

class CheckOutRequestCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const CheckOutRequestCard({
    super.key,
    required this.requestId,
    required this.data,
  });

  @override
  State<CheckOutRequestCard> createState() => _CheckOutRequestCardState();
}

class _CheckOutRequestCardState extends State<CheckOutRequestCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _approveCheckOut() async {
    try {
      // Mettre à jour la demande de check-out
      await _firestore.collection('checkout_requests').doc(widget.requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Mettre à jour la réservation
      if (widget.data['reservationId'] != null) {
        await _firestore.collection('reservations').doc(widget.data['reservationId']).update({
          'status': 'checked-out',
          'actualCheckOut': FieldValue.serverTimestamp(),
        });
      }

      // Envoyer une notification au client
      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'title': 'Check-out Approuvé',
        'message': 'Votre check-out a été approuvé. Merci pour votre séjour!',
        'type': 'checkout',
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-out approuvé avec succès!"),
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

  Future<void> _rejectCheckOut() async {
    try {
      // Mettre à jour la demande de check-out
      await _firestore.collection('checkout_requests').doc(widget.requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Envoyer une notification au client
      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'title': 'Check-out Rejeté',
        'message': 'Votre demande de check-out a été rejetée. Veuillez contacter la réception.',
        'type': 'checkout',
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-out rejeté!"),
          backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    final checkOutDate = widget.data['checkOutDate'] is Timestamp
        ? (widget.data['checkOutDate'] as Timestamp).toDate()
        : DateTime.now();

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
                    "Demande de check-out #${widget.requestId.substring(0, 8)}",
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
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange,
                    ),
                  ),
                  child: const Text(
                    "En attente",
                    style: TextStyle(
                      color: Colors.orange,
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
            _buildInfoRow("Client:", widget.data['clientName'] ?? 'Non spécifié'),
            _buildInfoRow("Email:", widget.data['clientEmail'] ?? 'Non spécifié'),
            _buildInfoRow("Téléphone:", widget.data['clientPhone'] ?? 'Non spécifié'),
            _buildInfoRow("Chambre:", widget.data['roomNumber'] ?? 'Non attribué'),
            _buildInfoRow("Type de chambre:", widget.data['roomType'] ?? 'Non spécifié'),
            _buildInfoRow("Méthode de paiement:", widget.data['paymentMethod'] ?? 'Non spécifié'),
            _buildInfoRow("Montant total:", "${widget.data['totalAmount'] ?? 0} FCFA"),
            _buildInfoRow("Date demande:", DateFormat('dd/MM/yyyy à HH:mm').format(checkOutDate)),
            
            if (widget.data['feedback'] != null && widget.data['feedback'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    "Feedback:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.data['feedback'],
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _rejectCheckOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Rejeter"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _approveCheckOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B4610),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Approuver"),
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
            width: 140,
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



class _ConversationsListStateV2 extends State<ConversationsList> {
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
                      builder: (context) => ChatPageReceptionV2(chatId: chat.id, userEmail: userEmail),
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
class ChatPageReceptionV2 extends StatefulWidget {
  final String chatId;
  final String userEmail;

  const ChatPageReceptionV2({super.key, required this.chatId, required this.userEmail});

  @override
  State<ChatPageReceptionV2> createState() => _ChatPageReceptionV2State();
}

class _ChatPageReceptionV2State extends State<ChatPageReceptionV2> {
 

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