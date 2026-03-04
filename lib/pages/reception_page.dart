import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'notification_service.dart';
// ✅ Import profil utilisateur admin
import 'package:flostay/pages/user_profile_admin_page.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN PAGE (identique à l'original)
// ─────────────────────────────────────────────────────────────────────────────
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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      if (userDoc.exists && userDoc.data()!['role'] == 'receptionniste') {
        // ok
      } else {
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accès réservé au personnel de réception')),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de connexion: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF9B4610)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

// ─────────────────────────────────────────────────────────────────────────────
// RECEPTION PAGE (identique à l'original)
// ─────────────────────────────────────────────────────────────────────────────
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
    const DashboardPage(),
    const ReservationsList(),
    const OrdersList(),
    const CheckInOutList(),
    const ConversationsList(), // ✅ Version améliorée
    const AlertsPage(),
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

  void _loadUnreadNotifications() {
    final user = _auth.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .where('receptionistId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'unread')
          .snapshots()
          .listen((snapshot) {
        if (mounted) setState(() => _unreadNotifications = snapshot.size);
      });
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);
  Future<void> _signOut() async => _auth.signOut();

  @override
  Widget build(BuildContext context) {
    Widget notifBell = Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: _showNotificationsDialog,
          tooltip: "Notifications",
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text('$_unreadNotifications',
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                  textAlign: TextAlign.center),
            ),
          ),
      ],
    );

    Widget drawerContent = Container(
      color: const Color(0xFF9B4610),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF9B4610)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FLOSTAY',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_auth.currentUser?.email ?? '',
                    style: const TextStyle(color: Colors.white70)),
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
    );

    if (kIsWeb) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(_appBarTitles[_selectedIndex],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF9B4610),
          foregroundColor: Colors.white,
          actions: [
            notifBell,
            IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
          ],
        ),
        drawer: Drawer(child: drawerContent),
        body: _pages[_selectedIndex],
      );
    } else {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(_appBarTitles[_selectedIndex],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF9B4610),
          foregroundColor: Colors.white,
          actions: [notifBell],
        ),
        drawer: Drawer(child: drawerContent),
        body: _pages[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF9B4610),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 2)),
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
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
              BottomNavigationBarItem(icon: Icon(Icons.hotel), label: "Réservations"),
              BottomNavigationBarItem(icon: Icon(Icons.room_service), label: "Commandes"),
              BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: "Check-in/out"),
              BottomNavigationBarItem(icon: Icon(Icons.message), label: "Messages"),
              BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Alertes"),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title,
          style: TextStyle(
              color: Colors.white,
              fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal)),
      selected: _selectedIndex == index,
      onTap: () {
        _onItemTapped(index);
        Navigator.pop(context);
      },
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final notif = snapshot.data!.docs[index];
                  final data = notif.data() as Map<String, dynamic>;
                  final ts = data['createdAt'] as Timestamp?;
                  return ListTile(
                    title: Text(data['title'] ?? 'Notification'),
                    subtitle: Text(data['message'] ?? ''),
                    trailing: Text(ts != null ? DateFormat('dd/MM HH:mm').format(ts.toDate()) : ''),
                    onTap: () => FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notif.id)
                        .update({'status': 'read'}),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD (identique à l'original)
// ─────────────────────────────────────────────────────────────────────────────
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try { return DateFormat('dd/MM/yyyy').parse(v); } catch (_) {}
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tableau de Bord',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 20),
          Row(children: [
            _statCard('pending', 'Réservations en attente', Colors.orange),
            const SizedBox(width: 16),
            _statCard('confirmed', 'Réservations confirmées', Colors.green),
            const SizedBox(width: 16),
            _statCard('checked-in', 'Clients check-in', Colors.blue),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _statCard('checked-out', 'Clients check-out', Colors.purple),
            const SizedBox(width: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
              builder: (_, snap) {
                int c = 0;
                if (snap.hasData) c = snap.data!.docs.where((d) => (d.data() as Map)['status'] != 'resolved').length;
                return _buildStatCardWidget('Alertes non résolues', c, Colors.red);
              },
            ),
            const SizedBox(width: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('commandes').snapshots(),
              builder: (_, snap) {
                int c = 0;
                if (snap.hasData) {
                  c = snap.data!.docs.where((d) {
                    final data = d.data() as Map;
                    return data['statut'] == 'en_attente' || data['statut'] == 'en_cours';
                  }).length;
                }
                return _buildStatCardWidget('Commandes en cours', c, Colors.amber);
              },
            ),
          ]),
          const SizedBox(height: 24),
          const Text('Dernières réservations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snap.data!.docs.length,
                itemBuilder: (_, i) {
                  final data = snap.data!.docs[i].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.hotel, color: Color(0xFF9B4610)),
                    title: Text(data['userEmail'] ?? 'Client'),
                    subtitle: Text('Chambre: ${data['roomType'] ?? 'N/A'}'),
                    trailing: Text(DateFormat('dd/MM').format(_parseDate(data['checkInDate'])),
                        style: const TextStyle(color: Colors.grey)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String status, String label, Color color) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
        builder: (_, snap) {
          int c = 0;
          if (snap.hasData) {
            c = snap.data!.docs.where((d) => (d.data() as Map)['status'] == status).length;
          }
          return _buildStatCardWidget(label, c, color);
        },
      ),
    );
  }

  Widget _buildStatCardWidget(String title, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(count.toString(),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ CONVERSATIONS LIST — avec photo profil + bouton voir profil
// ─────────────────────────────────────────────────────────────────────────────
class ConversationsList extends StatefulWidget {
  const ConversationsList({super.key});
  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Rechercher une conversation...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .orderBy('lastMessageTime', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(child: Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.black)));
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B4610))));
              }

              final chats = snap.data!.docs.where((chat) {
                final d = chat.data() as Map<String, dynamic>;
                final email = (d['userEmail'] ?? '').toString().toLowerCase();
                final name = (d['clientName'] ?? '').toString().toLowerCase();
                final last = (d['lastMessage'] ?? '').toString().toLowerCase();
                return email.contains(_searchQuery) || name.contains(_searchQuery) || last.contains(_searchQuery);
              }).toList();

              if (chats.isEmpty) {
                return const Center(child: Text("Aucune conversation", style: TextStyle(color: Colors.black)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: chats.length,
                itemBuilder: (ctx, i) {
                  final chat = chats[i];
                  final data = chat.data() as Map<String, dynamic>;
                  final userEmail = data['userEmail'] ?? '';
                  // ✅ Nom du client (depuis champ sauvegardé par chat_page.dart)
                  final clientName = (data['clientName'] as String?)?.isNotEmpty == true
                      ? data['clientName'] as String
                      : userEmail;
                  final lastMessage = data['lastMessage'] ?? '';
                  final ts = data['lastMessageTime'] as Timestamp?;
                  final timeStr = ts != null ? DateFormat('dd/MM HH:mm').format(ts.toDate()) : '';
                  // ✅ Photo de profil sauvegardée par chat_page.dart
                  final profileImage = data['clientProfileImage'] as String?;
                  final initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';
                  final unread = (data['receptionUnread'] ?? 0) as int;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      // ✅ Avatar avec vraie photo de profil
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF9B4610).withOpacity(0.15),
                            backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                            child: profileImage == null
                                ? Text(initial,
                                    style: const TextStyle(
                                        color: Color(0xFF9B4610),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16))
                                : null,
                          ),
                          // Badge messages non lus
                          if (unread > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text('$unread',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center),
                              ),
                            ),
                        ],
                      ),
                      title: Text(clientName,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (clientName != userEmail)
                            Text(userEmail,
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(lastMessage,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          // ✅ Bouton "Profil" pour voir le profil complet du client
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileAdminPage(
                                  userId: chat.id,
                                  userName: clientName,
                                  userEmail: userEmail,
                                  userRole: 'client',
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9B4610).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Profil',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9B4610),
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPageReceptionV2(
                            chatId: chat.id,
                            userEmail: userEmail,
                            clientName: clientName,
                            clientProfileImage: profileImage,
                          ),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// ✅ CHAT RÉCEPTION — avec photo profil client + bouton voir profil
// ─────────────────────────────────────────────────────────────────────────────
class ChatPageReceptionV2 extends StatefulWidget {
  final String chatId;
  final String userEmail;
  final String clientName;
  final String? clientProfileImage;

  const ChatPageReceptionV2({
    super.key,
    required this.chatId,
    required this.userEmail,
    this.clientName = '',
    this.clientProfileImage,
  });

  @override
  State<ChatPageReceptionV2> createState() => _ChatPageReceptionV2State();
}

class _ChatPageReceptionV2State extends State<ChatPageReceptionV2> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  String? _clientProfileImage;
  late String _clientName;

  @override
  void initState() {
    super.initState();
    _clientProfileImage = widget.clientProfileImage;
    _clientName = widget.clientName.isNotEmpty ? widget.clientName : widget.userEmail;
    _markAsRead();
    _loadClientProfile(); // ✅ Charge la photo si pas encore dispo
  }

  // ✅ Charge la photo depuis Firestore si pas transmise
  Future<void> _loadClientProfile() async {
    if (_clientProfileImage != null) return;
    try {
      // D'abord depuis le document chat (sauvegardé par chat_page.dart)
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
      if (chatDoc.exists) {
        final d = chatDoc.data()!;
        final img = d['clientProfileImage'] as String?;
        final name = d['clientName'] as String?;
        if (mounted) {
          setState(() {
            if (img != null) _clientProfileImage = img;
            if (name != null && name.isNotEmpty) _clientName = name;
          });
        }
        if (img != null) return;
      }
      // Sinon depuis users/{uid}
      final userDoc = await _firestore.collection('users').doc(widget.chatId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _clientProfileImage = userDoc.data()?['profileImage'] as String?;
          final n = userDoc.data()?['name'] as String?;
          if (n != null && n.isNotEmpty) _clientName = n;
        });
      }
    } catch (_) {}
  }

  Future<void> _markAsRead() async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).update({
        'receptionUnread': 0,
      });
    } catch (_) {}
  }

  void sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    final message = _controller.text.trim();

    _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': user?.uid,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'senderEmail': user?.email,
      'sender': 'reception',
    }).then((_) {
      _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'clientUnread': FieldValue.increment(1),
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    });
    _controller.clear();
    setState(() {});
  }

  // ✅ Ouvre le profil complet du client
  void _openClientProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileAdminPage(
          userId: widget.chatId,
          userName: _clientName,
          userEmail: widget.userEmail,
          userRole: 'client',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _clientName.isNotEmpty ? _clientName[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        // ✅ Header cliquable = ouvre profil
        title: GestureDetector(
          onTap: _openClientProfile,
          child: Row(
            children: [
              // ✅ Photo de profil dans AppBar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.25),
                backgroundImage: _clientProfileImage != null
                    ? NetworkImage(_clientProfileImage!)
                    : null,
                child: _clientProfileImage == null
                    ? Text(initial,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clientName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    // ✅ Indicateur "En train d'écrire..."
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .snapshots(),
                      builder: (_, snap) {
                        final isTyping =
                            (snap.data?.data() as Map?)?['isTypingClient'] == true;
                        return Text(
                          isTyping ? '✏️ En train d\'écrire...' : widget.userEmail,
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // ✅ Bouton voir profil complet
          Tooltip(
            message: 'Voir le profil complet',
            child: IconButton(
              icon: const Icon(Icons.person_search_rounded),
              onPressed: _openClientProfile,
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B4610))));
                  }
                  if (snap.hasError) {
                    return Center(child: Text("Erreur: ${snap.error}"));
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text("Aucun message", style: TextStyle(fontSize: 18, color: Colors.black)),
                        ],
                      ),
                    );
                  }

                  final docs = snap.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == user?.uid;
                      final isClient = data['sender'] == 'client';
                      final ts = data['timestamp'] as Timestamp?;
                      final time = ts != null ? DateFormat.Hm().format(ts.toDate()) : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // ✅ Avatar client avec vraie photo
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF9B4610).withOpacity(0.15),
                                backgroundImage: _clientProfileImage != null
                                    ? NetworkImage(_clientProfileImage!)
                                    : null,
                                child: _clientProfileImage == null
                                    ? Text(initial,
                                        style: const TextStyle(
                                            color: Color(0xFF9B4610),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment:
                                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: isMe ? const Color(0xFF9B4610) : Colors.grey[200],
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: Text(data['message'] ?? '',
                                        style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black,
                                            fontSize: 15)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(time,
                                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF9B4610).withOpacity(0.3),
                                child: const Icon(Icons.support_agent,
                                    size: 16, color: Color(0xFF9B4610)),
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Répondre à $_clientName…',
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {});
                                  })
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _controller.text.trim().isNotEmpty ? sendMessage : null,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _controller.text.trim().isNotEmpty
                            ? const Color(0xFF9B4610)
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send,
                          color: _controller.text.trim().isNotEmpty
                              ? Colors.white
                              : Colors.grey.shade500,
                          size: 20),
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

// ─────────────────────────────────────────────────────────────────────────────
// Toutes les autres classes — identiques à l'original
// ─────────────────────────────────────────────────────────────────────────────

class CreateReservationDialog extends StatefulWidget {
  const CreateReservationDialog({super.key});
  @override
  State<CreateReservationDialog> createState() => _CreateReservationDialogState();
}

class _CreateReservationDialogState extends State<CreateReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _roomTypeCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _checkInCtrl = TextEditingController();
  final _checkOutCtrl = TextEditingController();

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
              _field(_clientNameCtrl, 'Nom du client'),
              _field(_clientEmailCtrl, 'Email du client'),
              _field(_clientPhoneCtrl, 'Téléphone', required: false),
              _field(_roomTypeCtrl, 'Type de chambre'),
              _field(_guestsCtrl, 'Nombre de personnes', isNumber: true, required: false),
              _datePicker(_checkInCtrl, 'Date d\'arrivée'),
              _datePicker(_checkOutCtrl, 'Date de départ'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              await FirebaseFirestore.instance.collection('reservations').add({
                'userName': _clientNameCtrl.text,
                'userEmail': _clientEmailCtrl.text,
                'userPhone': _clientPhoneCtrl.text,
                'roomType': _roomTypeCtrl.text,
                'guests': int.tryParse(_guestsCtrl.text) ?? 1,
                'checkInDate': _checkInCtrl.text,
                'checkOutDate': _checkOutCtrl.text,
                'status': 'confirmed',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool isNumber = false, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      keyboardType: isNumber ? TextInputType.number : null,
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Champ requis' : null : null,
    );
  }

  Widget _datePicker(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );
        if (date != null) ctrl.text = DateFormat('dd/MM/yyyy').format(date);
      },
    );
  }
}

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Alertes des clients",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Toutes', 'all'),
                    const SizedBox(width: 8),
                    _chip('Nouvelles', 'new'),
                    const SizedBox(width: 8),
                    _chip('En cours', 'in_progress'),
                    const SizedBox(width: 8),
                    _chip('Résolues', 'resolved'),
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
            builder: (ctx, snap) {
              if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snap.data!.docs;
              final filtered = _filterStatus == 'all'
                  ? all
                  : all.where((d) => (d.data() as Map)['status'] == _filterStatus).toList();

              if (filtered.isEmpty) {
                return Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text("Aucune alerte",
                        style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final alert = filtered[i];
                  return AlertCard(
                      alertId: alert.id,
                      data: alert.data() as Map<String, dynamic>,
                      onStatusChanged: () => setState(() {}));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) => FilterChip(
        label: Text(label),
        selected: _filterStatus == value,
        onSelected: (s) => setState(() => _filterStatus = s ? value : 'all'),
        backgroundColor: Colors.grey[300],
        selectedColor: const Color(0xFF9B4610),
        labelStyle: TextStyle(color: _filterStatus == value ? Colors.white : Colors.black),
      );
}

class AlertCard extends StatefulWidget {
  final String alertId;
  final Map<String, dynamic> data;
  final VoidCallback onStatusChanged;
  const AlertCard({super.key, required this.alertId, required this.data, required this.onStatusChanged});
  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  bool _isUpdating = false;

  Future<void> _update(String status) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance.collection('alerts').doc(widget.alertId).update({
        'status': status,
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'Réceptionniste',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      widget.onStatusChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Alerte mise à jour: $status'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Supprimer cette alerte ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Supprimer")),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('alerts').doc(widget.alertId).delete();
      widget.onStatusChanged();
    }
  }

  Color _color(String s) {
    switch (s) {
      case 'new': return Colors.red;
      case 'in_progress': return Colors.orange;
      case 'resolved': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _text(String s) {
    switch (s) {
      case 'new': return 'Nouvelle';
      case 'in_progress': return 'En cours';
      case 'resolved': return 'Résolue';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] ?? 'new';
    final ts = widget.data['timestamp'] as Timestamp?;
    final time = ts != null ? DateFormat('dd/MM/yyyy à HH:mm').format(ts.toDate()) : 'Date inconnue';
    final updatedAt = widget.data['updatedAt'] as Timestamp?;
    final updatedTime = updatedAt != null ? DateFormat('dd/MM/yyyy à HH:mm').format(updatedAt.toDate()) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _color(status), width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            if (_isUpdating) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
            Opacity(
              opacity: _isUpdating ? 0.5 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(widget.data['title'] ?? 'Alerte',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: _color(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _color(status))),
                        child: Text(_text(status),
                            style: TextStyle(
                                color: _color(status), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(),
                  _row("Client:",
                      "${widget.data['userName'] ?? 'Client'} (${widget.data['userEmail'] ?? ''})"),
                  _row("Chambre:", widget.data['roomNumber'] ?? 'Non spécifié'),
                  _row("Date:", time),
                  if (updatedTime != null) _row("Mise à jour:", updatedTime),
                  if (widget.data['updatedBy'] != null) _row("Traité par:", widget.data['updatedBy']),
                  _row("Description:", widget.data['message'] ?? ''),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (status == 'new')
                        ElevatedButton(
                            onPressed: _isUpdating ? null : () => _update('in_progress'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange, foregroundColor: Colors.white),
                            child: const Text("Prendre en charge")),
                      if (status == 'in_progress')
                        ElevatedButton(
                            onPressed: _isUpdating ? null : () => _update('resolved'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text("Marquer résolu")),
                      if (status == 'resolved')
                        ElevatedButton(
                            onPressed: _isUpdating ? null : () => _update('in_progress'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange, foregroundColor: Colors.white),
                            child: const Text("Rouvrir")),
                      IconButton(
                          onPressed: _isUpdating ? null : _delete,
                          icon: const Icon(Icons.delete, color: Colors.red)),
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

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 100,
              child: Text(l,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
        ]),
      );
}

class ReservationsList extends StatelessWidget {
  const ReservationsList({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reservations = snap.data!.docs;
        final pending = reservations
            .where((r) => (r.data() as Map)['status'] == 'pending')
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: Text("Toutes les réservations",
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF9B4610),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text("$pending en attente",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: reservations.length,
                itemBuilder: (ctx, i) {
                  final res = reservations[i];
                  return ReservationCard(
                      reservationId: res.id, data: res.data() as Map<String, dynamic>);
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
  const ReservationCard({super.key, required this.reservationId, required this.data});
  @override
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _updateReservationStatus(String newStatus) async {
    try {
      await _firestore.collection('reservations').doc(widget.reservationId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final userId = widget.data['userId'] as String?;
      final roomType = widget.data['roomType'] as String? ?? 'chambre';
      final roomNumber = widget.data['roomNumber'] as String? ?? '';
      if (userId != null) {
        switch (newStatus) {
          case 'confirmed':
            await NotificationService.notifyReservationConfirmed(
                userId: userId, reservationId: widget.reservationId, roomType: roomType);
            break;
          case 'cancelled':
            await NotificationService.notifyReservationCancelled(
                userId: userId, reservationId: widget.reservationId);
            break;
          case 'checked-in':
            await NotificationService.notifyCheckInApproved(
                userId: userId, reservationId: widget.reservationId, roomNumber: roomNumber);
            break;
          case 'checked-out':
            await NotificationService.notifyCheckOutApproved(
                userId: userId, reservationId: widget.reservationId);
            break;
        }
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Réservation mise à jour : $newStatus'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _assignRoom(String roomNumber) async {
    try {
      await _firestore.collection('reservations').doc(widget.reservationId).update({
        'roomNumber': roomNumber,
        'status': 'checked-in',
        'actualCheckIn': FieldValue.serverTimestamp(),
      });
      final userId = widget.data['userId'] as String?;
      if (userId != null) {
        await NotificationService.notifyCheckInApproved(
            userId: userId, reservationId: widget.reservationId, roomNumber: roomNumber);
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chambre $roomNumber attribuée'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _showAssignRoomDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Attribuer une chambre'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: "Numéro de chambre", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                _assignRoom(ctrl.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610), foregroundColor: Colors.white),
            child: const Text('Attribuer'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'check-in-requested': return Colors.deepOrange;
      case 'checked-in': return Colors.green;
      case 'checked-out': return Colors.purple;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'check-in-requested': return 'Demande check-in';
      case 'checked-in': return 'Check-in';
      case 'checked-out': return 'Check-out';
      case 'cancelled': return 'Annulée';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = widget.data['checkInDate'] is Timestamp
        ? (widget.data['checkInDate'] as Timestamp).toDate()
        : DateTime.now();
    final checkOut = widget.data['checkOutDate'] is Timestamp
        ? (widget.data['checkOutDate'] as Timestamp).toDate()
        : DateTime.now();
    final status = widget.data['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text("Réservation #${widget.reservationId.substring(0, 8)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                        overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(status))),
                  child: Text(_statusText(status),
                      style: TextStyle(
                          color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(),
            _row("Client:", widget.data['userName'] ?? widget.data['userEmail'] ?? ''),
            _row("Email:", widget.data['userEmail'] ?? ''),
            _row("Téléphone:", widget.data['userPhone'] ?? 'Non spécifié'),
            _row("Chambre:", widget.data['roomType'] ?? ''),
            if (widget.data['roomNumber'] != null) _row("N° chambre:", widget.data['roomNumber']),
            _row("Arrivée:", DateFormat('dd/MM/yyyy').format(checkIn)),
            _row("Départ:", DateFormat('dd/MM/yyyy').format(checkOut)),
            _row("Personnes:", "${widget.data['guests'] ?? 1}"),
            _row("Prix:", "${widget.data['totalAmount'] ?? widget.data['price'] ?? 0} FCFA"),
            if (widget.data['paymentMethod'] != null) _row("Paiement:", widget.data['paymentMethod']),
            const SizedBox(height: 12),
            if (status == 'pending')
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton(
                    onPressed: () => _updateReservationStatus('cancelled'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text("Annuler")),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: () => _updateReservationStatus('confirmed'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B4610), foregroundColor: Colors.white),
                    child: const Text("Confirmer")),
              ]),
            if (status == 'check-in-requested')
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton(
                    onPressed: _showAssignRoomDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("Attribuer chambre")),
              ]),
            if (status == 'checked-in')
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton(
                    onPressed: () => _updateReservationStatus('checked-out'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                    child: const Text("Check-out")),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 100,
              child: Text(l,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.black, fontSize: 12))),
        ]),
      );
}

class OrdersList extends StatelessWidget {
  const OrdersList({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('commandes')
          .where('statut', whereIn: ['en_attente', 'en_cours', 'terminee'])
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final commandes = snap.data!.docs;
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text("Commandes en cours",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                            overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFF9B4610), borderRadius: BorderRadius.circular(20)),
                      child: Text("${commandes.length} en cours",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: commandes.length,
                  itemBuilder: (ctx, i) {
                    final cmd = commandes[i];
                    return CommandeCard(commandeId: cmd.id, data: cmd.data() as Map<String, dynamic>);
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
  const CommandeCard({super.key, required this.commandeId, required this.data});
  @override
  State<CommandeCard> createState() => _CommandeCardState();
}

class _CommandeCardState extends State<CommandeCard> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _changerStatut(String nouveauStatut) async {
    try {
      await _firestore.collection('commandes').doc(widget.commandeId).update({
        'statut': nouveauStatut,
        'dateModification': FieldValue.serverTimestamp(),
      });
      final userId = widget.data['userId'] as String?;
      final itemName = widget.data['item'] as String? ?? 'votre commande';
      if (userId != null) {
        switch (nouveauStatut) {
          case 'en_cours':
            await NotificationService.notifyCommandeEnCours(
                userId: userId, commandeId: widget.commandeId, itemName: itemName);
            break;
          case 'terminee':
            await NotificationService.notifyCommandeTerminee(
                userId: userId, commandeId: widget.commandeId, itemName: itemName);
            break;
          case 'annulee':
            await NotificationService.notifyCommandeAnnulee(
                userId: userId, commandeId: widget.commandeId, itemName: itemName);
            break;
        }
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Commande mise à jour : $nouveauStatut'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  Color _color(String s) {
    switch (s) {
      case 'en_attente': return Colors.orange;
      case 'en_cours': return Colors.blue;
      case 'terminee': return Colors.green;
      case 'annulee': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _text(String s) {
    switch (s) {
      case 'en_attente': return 'En attente';
      case 'en_cours': return 'Chez le client';
      case 'terminee': return 'Terminée';
      case 'annulee': return 'Annulée';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (widget.data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final statut = widget.data['statut'] ?? 'en_attente';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF9B4610).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.restaurant, color: Color(0xFF9B4610)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Commande #${widget.commandeId.substring(0, 8)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                      Text("Chambre: ${widget.data['chambre'] ?? 'Non spécifié'}",
                          style: const TextStyle(fontSize: 13, color: Colors.black)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _color(statut).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _color(statut))),
                  child: Text(_text(statut),
                      style: TextStyle(color: _color(statut), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(),
            _row("Client:", widget.data['userEmail'] ?? ''),
            _row("Produit:", widget.data['item'] ?? ''),
            _row("Quantité:", "${widget.data['quantite']}"),
            _row("Total:", "${widget.data['total']} FCFA"),
            _row("Date:", DateFormat('dd/MM/yyyy à HH:mm').format(date)),
            if (widget.data['instructions'] != null && (widget.data['instructions'] as String).isNotEmpty)
              _row("Instructions:", widget.data['instructions']),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (statut == 'en_attente') ...[
                  OutlinedButton(
                      onPressed: () => _changerStatut('annulee'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text("Annuler")),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: () => _changerStatut('en_cours'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B4610), foregroundColor: Colors.white),
                      child: const Text("Commencer")),
                ],
                if (statut == 'en_cours') ...[
                  OutlinedButton(
                      onPressed: () => _changerStatut('annulee'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text("Annuler")),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: () => _changerStatut('terminee'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B4610), foregroundColor: Colors.white),
                      child: const Text("Terminer")),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(l,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.black, fontSize: 12))),
        ]),
      );
}

class CheckInOutList extends StatelessWidget {
  const CheckInOutList({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: const TabBar(
              labelColor: Color(0xFF9B4610),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF9B4610),
              tabs: [
                Tab(icon: Icon(Icons.login), text: "Demandes Check-in"),
                Tab(icon: Icon(Icons.logout), text: "Demandes Check-out"),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: TabBarView(children: [
                _buildCheckInRequests(),
                _buildCheckOutRequests(),
              ]),
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
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snap.data?.docs ?? [];
        if (requests.isEmpty) {
          return const Center(
              child: Text("Aucune demande de check-in en attente",
                  style: TextStyle(fontSize: 18, color: Colors.black)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (ctx, i) {
            final r = requests[i];
            return CheckInRequestCard(requestId: r.id, data: r.data() as Map<String, dynamic>);
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
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snap.data?.docs ?? [];
        if (requests.isEmpty) {
          return const Center(
              child: Text("Aucune demande de check-out en attente",
                  style: TextStyle(fontSize: 18, color: Colors.black)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (ctx, i) {
            final r = requests[i];
            return CheckOutRequestCard(requestId: r.id, data: r.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }
}

class CheckInRequestCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;
  const CheckInRequestCard({super.key, required this.requestId, required this.data});
  @override
  State<CheckInRequestCard> createState() => _CheckInRequestCardState();
}

class _CheckInRequestCardState extends State<CheckInRequestCard> {
  final _firestore = FirebaseFirestore.instance;
  final _roomCtrl = TextEditingController();

  Future<void> _approve() async {
    try {
      await _firestore.collection('checkin_requests').doc(widget.requestId).update({
        'status': 'approved',
        'roomNumber': _roomCtrl.text,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      if (widget.data['reservationId'] != null) {
        await _firestore.collection('reservations').doc(widget.data['reservationId']).update({
          'status': 'checked-in',
          'roomNumber': _roomCtrl.text,
          'actualCheckIn': FieldValue.serverTimestamp(),
        });
      }
      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'title': 'Check-in Approuvé',
        'message': 'Votre check-in a été approuvé. Chambre : ${_roomCtrl.text}',
        'type': 'checkin',
        'status': 'unread',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Check-in approuvé!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject() async {
    try {
      await _firestore.collection('checkin_requests').doc(widget.requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'title': 'Check-in Rejeté',
        'message': 'Votre demande de check-in a été rejetée.',
        'type': 'checkin',
        'status': 'unread',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Check-in rejeté"), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approuver le check-in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Attribuez un numéro de chambre:'),
            const SizedBox(height: 10),
            TextField(
                controller: _roomCtrl,
                decoration:
                    const InputDecoration(hintText: "Numéro de chambre", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (_roomCtrl.text.isNotEmpty) {
                _approve();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B4610), foregroundColor: Colors.white),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Demande check-in #${widget.requestId.substring(0, 8)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            _row("Client:", widget.data['clientName'] ?? ''),
            _row("Email:", widget.data['clientEmail'] ?? ''),
            _row("Téléphone:", widget.data['clientPhone'] ?? 'Non spécifié'),
            _row("Type pièce:", widget.data['idType'] ?? ''),
            _row("N° pièce:", widget.data['idNumber'] ?? ''),
            if (widget.data['specialRequests']?.isNotEmpty == true)
              _row("Demandes:", widget.data['specialRequests']),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                  onPressed: _reject,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text("Rejeter")),
              const SizedBox(width: 10),
              ElevatedButton(
                  onPressed: _showApproveDialog,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B4610), foregroundColor: Colors.white),
                  child: const Text("Approuver")),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(l,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.black, fontSize: 12))),
        ]),
      );
}

class CheckOutRequestCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;
  const CheckOutRequestCard({super.key, required this.requestId, required this.data});
  @override
  State<CheckOutRequestCard> createState() => _CheckOutRequestCardState();
}

class _CheckOutRequestCardState extends State<CheckOutRequestCard> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _approve() async {
    try {
      await _firestore.collection('checkout_requests').doc(widget.requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
      if (widget.data['reservationId'] != null) {
        await _firestore.collection('reservations').doc(widget.data['reservationId']).update({
          'status': 'checked-out',
          'actualCheckOut': FieldValue.serverTimestamp(),
        });
      }
      await _firestore.collection('notifications').add({
        'userId': widget.data['userId'],
        'title': 'Check-out Approuvé',
        'message': 'Votre check-out a été approuvé. Merci pour votre séjour!',
        'type': 'checkout',
        'status': 'unread',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Check-out approuvé!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject() async {
    try {
      await _firestore.collection('checkout_requests').doc(widget.requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Check-out rejeté"), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Demande check-out #${widget.requestId.substring(0, 8)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            _row("Client:", widget.data['clientName'] ?? ''),
            _row("Email:", widget.data['clientEmail'] ?? ''),
            _row("Chambre:", widget.data['roomNumber'] ?? ''),
            _row("Type chambre:", widget.data['roomType'] ?? 'Non spécifié'),
            _row("Paiement:", widget.data['paymentMethod'] ?? 'Non spécifié'),
            _row("Montant:", "${widget.data['totalAmount'] ?? 0} FCFA"),
            if (widget.data['feedback']?.isNotEmpty == true) _row("Feedback:", widget.data['feedback']),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                  onPressed: _reject,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text("Rejeter")),
              const SizedBox(width: 10),
              ElevatedButton(
                  onPressed: _approve,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B4610), foregroundColor: Colors.white),
                  child: const Text("Approuver")),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 140,
              child: Text(l,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.black, fontSize: 12))),
        ]),
      );
}