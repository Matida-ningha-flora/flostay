// ============================================================
// client_client.dart — VERSION CORRIGÉE
//
// CORRECTIONS :
// ✅ Suppression du "a" parasite ligne 22 (bug compilation)
// ✅ NotificationBell ajoutée dans AppBar
// ✅ Services affichés côté client depuis Firestore (collection 'services')
// ✅ Tab Profil (index 2) bien séparé de l'Accueil (index 0)
// ✅ Services s'affichent côté client en temps réel
// ✅ Section services ajoutée dans HomePage
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:flostay/pages/alert_page.dart';
import 'package:flostay/pages/chat_page.dart';
import 'package:flostay/pages/reservations_page.dart';
import 'package:flostay/pages/commander_page.dart';
import 'package:flostay/pages/profile_page.dart';
import 'package:flostay/pages/checkin_checkout_page.dart';
import 'package:flostay/pages/rating_page.dart';
import 'package:flostay/pages/reservation_history_page.dart';
import 'package:flostay/pages/invoices_page.dart';
import 'package:flostay/pages/suivi_commandes_page.dart';
import 'package:flostay/pages/notifications_page.dart'; // ✅ NotificationBell

class ClientClient extends StatefulWidget {
  const ClientClient({super.key});

  @override
  State<ClientClient> createState() => _ClientClientState();
}

// ✅ CORRECTION : suppression du "a" parasite qui causait l'erreur de compilation
class _ClientClientState extends State<ClientClient> {
  int _currentIndex = 0;
  String userName = "Nom non défini";
  String userEmail = "";
  String? _profileImageUrl; // ✅ Photo de profil
  bool _isLoading = true;

  // ✅ index 0 = Accueil, index 1 = Réservations, index 2 = Profil, index 3 = Support
  // Profil (index 2) est DISTINCT de l'Accueil (index 0)
  final List<Widget> _pages = [
    const HomePage(),
    const ReservationsPage(),
    const ProfilePage(), // ✅ Profil = page dédiée, pas l'Accueil
    const ChatPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          setState(() {
            userName = doc.data()?["name"] ?? "Nom non défini";
            userEmail = user.email ?? "";
            _profileImageUrl = doc.data()?["profileImage"]; // ✅
            _isLoading = false;
          });
        } else {
          setState(() {
            userEmail = user.email ?? "";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement utilisateur: $e");
      setState(() {
        _isLoading = false;
      });
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
                  Icon(Icons.hotel,
                      color: Colors.white, size: isWeb ? 32 : 28),
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
                // ✅ Cloche notifications temps réel
                const NotificationBell(),
                const SizedBox(width: 4),

                if (!_isLoading)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      children: [
                        // ✅ Vraie photo de profil dans l'AppBar
                        GestureDetector(
                          onTap: () => setState(() => _currentIndex = 2),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Colors.white.withOpacity(0.3),
                            backgroundImage: _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : null,
                            child: _profileImageUrl == null
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                        ),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF9B4610)))
          // ✅ FIX : IndexedStack garde toutes les pages en mémoire
          // Évite le bug où Profil = Accueil (rechargement)
          : IndexedStack(index: _currentIndex, children: _pages),
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
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profil', // ✅ Profil séparé
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
                  const Text(
                    'FLOSTAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isLoading) ...[
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
            _buildSidebarItem(
                Icons.bed, 'Réservations', 1, context),
            _buildSidebarItem(Icons.person, 'Profil', 2, context),
            _buildSidebarItem(Icons.chat, 'Support', 3, context),
            const Divider(),
            _buildSidebarItem(
              Icons.history,
              'Historique',
              -1,
              context,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const ReservationHistoryPage()));
              },
            ),
            _buildSidebarItem(
              Icons.receipt,
              'Factures',
              -1,
              context,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InvoicesPage()));
              },
            ),
            _buildSidebarItem(
              Icons.star,
              'Noter mon séjour',
              -1,
              context,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RatingPage()));
              },
            ),
            _buildSidebarItem(
              Icons.login,
              'Check-in/out',
              -1,
              context,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CheckInOutPage()));
              },
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    int index,
    BuildContext context, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: _currentIndex == index
              ? const Color(0xFF9B4610)
              : Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          color: _currentIndex == index
              ? const Color(0xFF9B4610)
              : Colors.grey[700],
          fontWeight: _currentIndex == index
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      onTap: onTap ??
          () {
            setState(() {
              _currentIndex = index;
            });
            // ✅ FIX : on ferme le drawer seulement s'il est ouvert
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  HOME PAGE — Accueil client                                             ║
// ╚══════════════════════════════════════════════════════════════════════════╝

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    final List<_HomeOption> options = [
      _HomeOption(Icons.bed, 'Réserver une chambre', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ReservationsPage()));
      }, color: const Color(0xFF9B4610)),
      _HomeOption(Icons.history, 'Historique des réservations', () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ReservationHistoryPage()));
      }, color: const Color(0xFF2A9D8F)),
      _HomeOption(Icons.login, 'Check-in / Check-out', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CheckInOutPage()));
      }, color: const Color(0xFFE76F51)),
      _HomeOption(Icons.restaurant, 'Effectuer une Commande', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CommanderPage()));
      }, color: const Color(0xFFF4A261)),
      _HomeOption(Icons.track_changes, 'Suivi des commandes', () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SuiviCommandesPage()));
      }, color: const Color(0xFF264653)),
      _HomeOption(Icons.warning, 'Signaler une alerte', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AlertPage()));
      }, color: const Color(0xFFE76F51)),
      _HomeOption(Icons.star, 'Noter mon séjour', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const RatingPage()));
      }, color: const Color(0xFFE9C46A)),
      _HomeOption(Icons.receipt, 'Mes factures', () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InvoicesPage()));
      }, color: const Color(0xFF2A9D8F)),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F0E5), Color(0xFFFDF8F3)],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          // ── Banner mobile ──────────────────────────────────────────────
          if (!isWeb)
            SliverAppBar(
              expandedHeight: 180.0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF9B4610), Color(0xFFE27D35)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hotel,
                          size: 54, color: Colors.white),
                      const SizedBox(height: 8),
                      const Text(
                        'FLOSTAY',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bienvenue dans votre espace client',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Grille d'actions ───────────────────────────────────────────
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
                (context, index) =>
                    _buildOptionCard(context, options[index], isWeb),
                childCount: options.length,
              ),
            ),
          ),

          // ── Section services disponibles ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  isWeb ? 40 : 16, 0, isWeb ? 40 : 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.room_service_rounded,
                      color: _primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Nos services exclusifs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A2A10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ Services depuis Firestore en temps réel
          SliverToBoxAdapter(
            child: _ServicesSection(isWeb: isWeb),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
      BuildContext context, _HomeOption option, bool isWeb) {
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

// ── Section services temps réel ────────────────────────────────────────────────

class _ServicesSection extends StatelessWidget {
  final bool isWeb;
  const _ServicesSection({required this.isWeb});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('available', isEqualTo: true)
            // ✅ Seuls les services "Autre" s'affichent ici
            // Les autres (Restaurant, Transport, Spa, etc.) vont dans Commander
            .where('category', isEqualTo: 'Autre')
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child:
                  Center(child: CircularProgressIndicator(color: _primary)),
            );
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Aucun service disponible pour le moment',
                    style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          // Grille de services
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWeb ? 4 : 2,
              crossAxisSpacing: isWeb ? 20 : 12,
              mainAxisSpacing: isWeb ? 20 : 12,
              childAspectRatio: 0.82,
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _ServiceCard(data: data);
            },
          );
        },
      ),
    );
  }
}

// ── Carte service ──────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ServiceCard({required this.data});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['imageUrl'] as String?;
    final name = data['name'] ?? '';
    final description = data['description'] ?? '';
    final price = (data['price'] ?? 0) as num;
    final category = (data['category'] ?? '').toString().toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 105,
              width: double.infinity,
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _placeholder(category),
                    )
                  : _placeholder(category),
            ),
          ),

          // Infos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A2A10),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    '${NumberFormat('#,###', 'fr_FR').format(price)} FCFA',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String category) {
    IconData icon;
    switch (category) {
      case 'spa':        icon = Icons.spa_rounded; break;
      case 'restaurant': icon = Icons.restaurant_rounded; break;
      case 'transport':  icon = Icons.directions_car_rounded; break;
      case 'loisirs':    icon = Icons.sports_tennis_rounded; break;
      case 'chambre':    icon = Icons.hotel_rounded; break;
      default:           icon = Icons.room_service_rounded;
    }
    return Container(
      color: const Color(0xFFF8F0E5),
      child: Center(
        child: Icon(icon, size: 34, color: Colors.grey[400]),
      ),
    );
  }
}

// ── Modèle option accueil ──────────────────────────────────────────────────────

class _HomeOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  _HomeOption(this.icon, this.label, this.onTap, {required this.color});
}