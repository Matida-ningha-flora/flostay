import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

// Import des pages depuis le dossier pages
import 'package:flostay/pages/create_staff_page.dart'; // Modifié: anciennement create_receptionist_page.dart
import 'package:flostay/pages/chat_admin_page.dart';
import 'package:flostay/pages/analyses_ia_page.dart';
import 'package:flostay/pages/create_reservation_page.dart';
import 'package:flostay/pages/finances_page.dart';
import 'package:flostay/pages/parametres_page.dart';
import 'package:flostay/pages/services_page.dart';
import 'package:flostay/pages/activite_receptionnistes_page.dart';

// Import des pages depuis le dossier admin
import 'package:flostay/admin/accounts_list.dart';
import 'package:flostay/admin/reservations_admin_list.dart';
import 'package:flostay/admin/orders_admin_list.dart';
import 'package:flostay/admin/checkinout_admin_list.dart';
import 'package:flostay/admin/chat_admin_list.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLOSTAY ADMIN',
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
          backgroundColor: const Color.fromARGB(255, 166, 85, 18),
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.roboto(
            fontSize: kIsWeb ? 24 : 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: TextTheme(
          headlineMedium: GoogleFonts.roboto(
            fontSize: kIsWeb ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF9B4610),
          ),
          titleLarge: GoogleFonts.roboto(
            fontSize: kIsWeb ? 22 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          bodyLarge: TextStyle(
            fontSize: kIsWeb ? 18 : 16,
            color: Colors.black87,
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const AdminPage();
          }

          return const LoginPage();
        },
      ),
    );
  }
}

// --- PAGE DE CONNEXION ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? 'VOTRE_CLIENT_ID_WEB_ICI.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );
  bool _isLoading = false;
  bool _googleLoading = false;

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

      if (userDoc.exists &&
          (userDoc.data()!['role'] == 'admin' ||
              userDoc.data()!['role'] == 'receptionniste')) {
        // Connexion réussie pour admin ou réceptionniste
      } else {
        // Déconnecter si l'utilisateur n'a pas le bon rôle
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accès réservé au personnel')),
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

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);

    try {
      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        // Pour le web, utilisez signInWithPopup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        await _auth.signInWithPopup(googleProvider);
      } else {
        // Pour mobile
        googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          setState(() => _googleLoading = false);
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion Google: ${e.message}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur inattendue: $error')));
    } finally {
      setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4E9),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'FLOSTAY ADMIN',
                style: GoogleFonts.roboto(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF9B4610),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Espace Administrative',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),
              const Text('OU', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _googleLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                  child: _googleLoading
                      ? const CircularProgressIndicator()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: Colors.blue[700],
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('Se connecter avec Google'),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
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
  String? _currentUserRole;
  String? _currentUserEmail;

  final List<Widget> _pages = [
    const DashboardPage(),
    const AccountsList(),
    const ReservationsAdminList(),
    const OrdersAdminList(),
    const CheckInOutAdminList(),
    const AlertsPage(),
    const TarifsPage(),
    const ServicesPage(),
    const ActiviteReceptionnistesPage(),
    const FinancesPage(),
    const ParametresPage(),
    const AnalysesIAPage(),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentUserInfo();
  }

  void _getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserEmail = user.email;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _currentUserRole = doc.get('role');
        });
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "FLOSTAY ADMIN",
          style: GoogleFonts.roboto(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: "Se déconnecter",
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(
                _currentUserRole == 'admin'
                    ? 'Administrateur'
                    : 'Réceptionniste',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_currentUserEmail ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _currentUserEmail != null && _currentUserEmail!.isNotEmpty
                      ? _currentUserEmail![0].toUpperCase()
                      : 'A',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFF9B4610),
                  ),
                ),
              ),
              decoration: const BoxDecoration(color: Color(0xFF9B4610)),
            ),
            _buildDrawerItem(Icons.dashboard, 'Tableau de bord', 0),
            _buildDrawerItem(Icons.people, 'Utilisateurs', 1),
            _buildDrawerItem(Icons.hotel, 'Réservations', 2),
            _buildDrawerItem(Icons.room_service, 'Commandes', 3),
            _buildDrawerItem(Icons.check_circle, 'Check-in/out', 4),
            _buildDrawerItem(Icons.notifications, 'Alertes', 5),
            _buildDrawerItem(Icons.attach_money, 'Gestion des tarifs', 6),
            _buildDrawerItem(Icons.room_service, 'Services', 7),
            _buildDrawerItem(Icons.assignment, 'Activité réceptionnistes', 8),
            _buildDrawerItem(Icons.account_balance, 'Finances', 9),
            _buildDrawerItem(Icons.settings, 'Paramètres', 10),
            _buildDrawerItem(Icons.analytics, 'Analyses IA', 11),
            const Divider(),
            _buildDrawerItem(Icons.logout, 'Déconnexion', -1, isLogout: true),
          ],
        ),
      ),
      body: _selectedIndex >= 0 && _selectedIndex < _pages.length
          ? _pages[_selectedIndex]
          : const DashboardPage(),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    int index, {
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF9B4610)),
      title: Text(title),
      onTap: () {
        if (isLogout) {
          _signOut();
        } else {
          _onItemTapped(index);
        }
        Navigator.pop(context); // Close the drawer
      },
    );
  }
}

// --- DASHBOARD PAGE ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

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
                  _buildStatCard(
                    "Clients",
                    Icons.people,
                    firestore
                        .collection('users')
                        .where('role', isEqualTo: 'client'),
                  ),
                  _buildStatCard(
                    "Réceptionnistes",
                    Icons.support_agent,
                    firestore
                        .collection('users')
                        .where('role', isEqualTo: 'receptionniste'),
                  ),
                  _buildStatCard(
                    "Administrateurs",
                    Icons.admin_panel_settings,
                    firestore
                        .collection('users')
                        .where('role', isEqualTo: 'admin'),
                  ),
                  _buildStatCard(
                    "Réservations",
                    Icons.hotel,
                    firestore.collection('reservations'),
                  ),
                  _buildStatCard(
                    "Commandes",
                    Icons.restaurant,
                    firestore.collection('commandes'),
                  ),
                  _buildStatCard(
                    "Check-in Aujourd'hui",
                    Icons.login,
                    firestore
                        .collection('reservations')
                        .where('checkIn', isEqualTo: true)
                        .where('checkInDate', isEqualTo: today),
                  ),
                  _buildStatCard(
                    "Check-out Aujourd'hui",
                    Icons.logout,
                    firestore
                        .collection('reservations')
                        .where('checkOut', isEqualTo: true)
                        .where('checkOutDate', isEqualTo: today),
                  ),
                  _buildStatCard(
                    "Avis Clients",
                    Icons.star,
                    firestore.collection('reviews'),
                  ),
                  _buildStatCard(
                    "Alertes Non Lus",
                    Icons.warning,
                    firestore
                        .collection('alerts')
                        .where('read', isEqualTo: false),
                  ),
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
                  _buildActionButton("Créer un membre", Icons.person_add, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateStaffPage(),
                      ),
                    );
                  }),
                  _buildActionButton("Effectuer Réservation", Icons.hotel, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateReservationPage(),
                      ),
                    );
                  }),
                  _buildActionButton(
                    "Voir Check-in/out",
                    Icons.check_circle,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CheckInOutAdminList(),
                        ),
                      );
                    },
                  ),
                  _buildActionButton("Messages", Icons.message, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatAdminList(),
                      ),
                    );
                  }),
                ],
              );
            },
          ),

          // Dernières alertes
          const SizedBox(height: 24),
          Text(
            "Dernières Alertes",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _buildAlertesList(),
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
          constraints: const BoxConstraints(minHeight: 100, maxHeight: 120),
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
                maxLines: 2,
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

  Widget _buildActionButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
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

  Widget _buildAlertesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final alerts = snapshot.data!.docs;

        if (alerts.isEmpty) {
          return const Card(
            child: ListTile(title: Text("Aucune alerte pour le moment")),
          );
        }

        return Column(
          children: alerts.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Alerte sans titre';
            final message = data['message'] ?? '';
            final read = data['read'] ?? false;
            final createdAt = data['createdAt'] != null
                ? DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format((data['createdAt'] as Timestamp).toDate())
                : 'Date inconnue';

            return Card(
              color: read ? Colors.white : Colors.red[50],
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  Icons.warning,
                  color: read ? Colors.grey : Colors.red,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(message),
                trailing: Text(createdAt, style: const TextStyle(fontSize: 12)),
                onTap: () {
                  // Marquer comme lu
                  FirebaseFirestore.instance
                      .collection('alerts')
                      .doc(doc.id)
                      .update({'read': true});
                },
              ),
            );
          }).toList(),
        );
      },
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
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
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
        content: const Text(
          "Êtes-vous sûr de vouloir supprimer cette alerte ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
        side: BorderSide(color: _getStatusColor(status), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            if (_isUpdating)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(status)),
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
                  Text(message, style: const TextStyle(fontSize: 12)),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

// --- PAGE DE GESTION DES TARIFS ---
class TarifsPage extends StatefulWidget {
  const TarifsPage({super.key});

  @override
  State<TarifsPage> createState() => _TarifsPageState();
}

class _TarifsPageState extends State<TarifsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialiser les contrôleurs pour les types de chambres
    _controllers['standard'] = TextEditingController();
    _controllers['premium'] = TextEditingController();
    _controllers['prestige'] = TextEditingController();
    _loadPrices();
  }

  void _loadPrices() async {
    final doc = await _firestore.collection('tarifs').doc('chambres').get();
    if (doc.exists) {
      setState(() {
        _controllers['standard']!.text = doc.get('standard')?.toString() ?? '';
        _controllers['premium']!.text = doc.get('premium')?.toString() ?? '';
        _controllers['prestige']!.text = doc.get('prestige')?.toString() ?? '';
      });
    }
  }

  void _savePrices() async {
    try {
      await _firestore.collection('tarifs').doc('chambres').set({
        'standard': int.parse(_controllers['standard']!.text),
        'premium': int.parse(_controllers['premium']!.text),
        'prestige': int.parse(_controllers['prestige']!.text),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarifs mis à jour avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Tarifs'),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tarifs des Chambres (FCFA/nuit)',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            _buildPriceField('Chambre Standard', _controllers['standard']!),
            _buildPriceField('Chambre Premium', _controllers['premium']!),
            _buildPriceField('Chambre Prestige', _controllers['prestige']!),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _savePrices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B4610),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                child: const Text('Enregistrer les tarifs'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixText: 'FCFA ',
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }
}
