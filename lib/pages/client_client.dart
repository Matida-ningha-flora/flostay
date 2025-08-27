import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flostay/pages/chat_page.dart';
import 'package:flostay/pages/reservations_page.dart';
import 'package:flostay/pages/commander_page.dart';
import 'package:flostay/pages/profile_page.dart';
import 'package:flostay/pages/checkin_checkout_page.dart';
import 'package:flostay/pages/rating_page.dart';
import 'package:flostay/pages/reservation_history_page.dart';
import 'package:flostay/pages/invoices_page.dart';


class ClientClient extends StatefulWidget {
  const ClientClient({super.key});

  @override
  State<ClientClient> createState() => _ClientClientState();
}

class _ClientClientState extends State<ClientClient> {
  int _currentIndex = 0;
  String userName = "";
  String userEmail = "";

  final List<Widget> _pages = [
    const HomePage(),
    const ReservationsPage(),
    const ProfilePage(),
    const ChatPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
          
      if (doc.exists) {
        setState(() {
          userName = doc.data()?["name"] ?? "";
          userEmail = user.email ?? "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Scaffold(
      appBar: _currentIndex == 0 
          ? AppBar(
              backgroundColor: const Color(0xFF9B4610),
              elevation: 0,
              title: Row(
                children: [
                  Icon(Icons.hotel, color: Colors.white, size: isWeb ? 32 : 28),
                  const SizedBox(width: 10),
                  Text(
                    'FLOSTAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWeb ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                if (userName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isWeb ? 16 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (userEmail.isNotEmpty)
                              Text(
                                userEmail,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: isWeb ? 12 : 10,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : null,
      body: _pages[_currentIndex],
      bottomNavigationBar: isWeb 
          ? null 
          : Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                selectedItemColor: const Color(0xFF9B4610),
                unselectedItemColor: Colors.grey[600],
                backgroundColor: Colors.white,
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                elevation: 0,
                onTap: (index) {
                  setState(() => _currentIndex = index);
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Accueil',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bed_outlined),
                    activeIcon: Icon(Icons.bed),
                    label: 'Réservations',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outlined),
                    activeIcon: Icon(Icons.person),
                    label: 'Profil',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_outlined),
                    activeIcon: Icon(Icons.chat),
                    label: 'Support',
                  ),
                ],
              ),
            ),
      drawer: isWeb ? _buildWebSidebar(context, size) : null,
    );
  }

  Widget _buildWebSidebar(BuildContext context, Size size) {
    return Drawer(
      width: size.width * 0.2,
      child: Container(
        color: const Color(0xFFF8F0E5),
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
                  const Icon(Icons.hotel, size: 40, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    'FLOSTAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (userName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      userName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildSidebarItem(Icons.home, 'Accueil', 0, context),
            _buildSidebarItem(Icons.bed, 'Réservations', 1, context),
            _buildSidebarItem(Icons.person, 'Profil', 2, context),
            _buildSidebarItem(Icons.chat, 'Support', 3, context),
            const Divider(),
            _buildSidebarItem(Icons.history, 'Historique', -1, context, 
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ReservationHistoryPage()));
                }),
            _buildSidebarItem(Icons.receipt, 'Factures', -1, context, 
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const InvoicesPage()));
                }),
            
            _buildSidebarItem(Icons.star, 'Noter mon séjour', -1, context, 
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const RatingPage()));
                }),
            _buildSidebarItem(Icons.login, 'Check-in/out', -1, context, 
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const CheckInOutPage()));
                }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, int index, BuildContext context, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: _currentIndex == index ? const Color(0xFF9B4610) : Colors.grey[700]),
      title: Text(title, style: TextStyle(
        color: _currentIndex == index ? const Color(0xFF9B4610) : Colors.grey[700],
        fontWeight: _currentIndex == index ? FontWeight.bold : FontWeight.normal,
      )),
      onTap: onTap ?? () {
        setState(() {
          _currentIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;
    
    final List<_HomeOption> options = [
      _HomeOption(Icons.bed, 'Réserver une chambre', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const ReservationsPage()));
      }, color: const Color(0xFF9B4610)),
      _HomeOption(Icons.history, 'Historique des réservations', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const ReservationHistoryPage()));
      }, color: const Color(0xFF2A9D8F)),
      _HomeOption(Icons.login, 'Check-in / Check-out', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const CheckInOutPage()));
      }, color: const Color(0xFFE76F51)),
      _HomeOption(Icons.restaurant, 'Effectuer une Commande', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const CommanderPage()));
      }, color: const Color(0xFFF4A261)),
      _HomeOption(Icons.restaurant, 'suivie des commandes', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const CommanderPage()));
      }, color: const Color(0xFF264653)),
    
      _HomeOption(Icons.star, 'Noter mon séjour', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const RatingPage()));
      }, color: const Color(0xFFE9C46A)),
      _HomeOption(Icons.receipt, 'Mes factures', () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const InvoicesPage()));
      }, color: const Color(0xFF2A9D8F)),
     
    ];

    return Container(
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
      child: CustomScrollView(
        slivers: [
          if (!isWeb) 
            SliverAppBar(
              expandedHeight: 200.0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF9B4610),
                        Color(0xFFE27D35),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hotel, size: 60, color: Colors.white),
                      const SizedBox(height: 10),
                      const Text(
                        'FLOSTAY',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Bienvenue dans votre espace client',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.all(isWeb ? 40.0 : 16.0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWeb ? 4 : 2,
                crossAxisSpacing: isWeb ? 20.0 : 12.0,
                mainAxisSpacing: isWeb ? 20.0 : 12.0,
                childAspectRatio: isWeb ? 1.0 : 0.9,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildOptionCard(context, options[index], size, isWeb);
                },
                childCount: options.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, _HomeOption option, Size size, bool isWeb) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: option.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                option.color.withOpacity(0.1),
                option.color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isWeb ? 60 : 48,
                height: isWeb ? 60 : 48,
                decoration: BoxDecoration(
                  color: option.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  size: isWeb ? 30 : 24,
                  color: option.color,
                ),
              ),
              SizedBox(height: isWeb ? 16 : 12),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isWeb ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  _HomeOption(this.icon, this.label, this.onTap, {required this.color});
}