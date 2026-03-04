// ============================================================
// admin_page.dart — VERSION CORRIGÉE
//
// CORRECTIONS APPORTÉES :
// ✅ #1 Profil admin : lit name/displayName/email avec fallback complet
// ✅ #2 Tableau de bord : DateFormat fr_FR avec try/catch sécurisé
// ✅ #3 Tarifs : clés minuscules + valeurs par défaut pré-remplies
// ✅ #4 Réceptionnistes : whereIn pour matcher toutes les variantes
// ✅ #5 case 10 → ClientsBehaviorPage (Profils clients)
// ✅ #6 Activité personnel et Finances retirés du menu
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flostay/pages/create_staff_page.dart';
import 'package:flostay/pages/analyses_ia_page.dart';
import 'package:flostay/pages/create_reservation_page.dart';
import 'package:flostay/pages/parametres_page.dart';
import 'package:flostay/pages/services_page.dart';

import 'package:flostay/admin/accounts_list.dart';
import 'package:flostay/pages/chambres_admin_page.dart';
import 'package:flostay/pages/user_profile_admin_page.dart';
import 'package:flostay/admin/reservations_admin_list.dart';
import 'package:flostay/admin/orders_admin_list.dart';
import 'package:flostay/admin/checkinout_admin_list.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  int _selectedIndex = 0;
  String? _userEmail;
  String? _userName;
  String? _userRole;

  // ✅ #6 : Activité personnel (8) et Finances (9) retirés
  final List<_NavItem> _navItems = [
    _NavItem(0, Icons.dashboard_rounded, 'Tableau de bord'),
    _NavItem(1, Icons.people_rounded, 'Utilisateurs'),
    _NavItem(2, Icons.hotel_rounded, 'Réservations'),
    _NavItem(3, Icons.restaurant_rounded, 'Commandes'),
    _NavItem(4, Icons.check_circle_rounded, 'Check-in/out'),
    _NavItem(5, Icons.warning_rounded, 'Alertes'),
    _NavItem(6, Icons.attach_money_rounded, 'Tarifs'),
    _NavItem(7, Icons.room_service_rounded, 'Services'),
    _NavItem(8, Icons.settings_rounded, 'Paramètres'),
    _NavItem(9, Icons.auto_awesome_rounded, 'Analyses IA'),
    _NavItem(10, Icons.psychology_rounded, 'Profils clients'),
    _NavItem(11, Icons.hotel_rounded, 'Chambres'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // ✅ #1 : Lit le vrai nom depuis Firestore avec plusieurs fallbacks
  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userEmail = user.email;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        String? name;

        // Cherche dans l'ordre : name → displayName → prenom+nom → firebase displayName → email
        if ((data['name'] as String?)?.trim().isNotEmpty == true) {
          name = data['name'];
        } else if ((data['displayName'] as String?)?.trim().isNotEmpty == true) {
          name = data['displayName'];
        } else if ((data['prenom'] as String?)?.trim().isNotEmpty == true) {
          final prenom = data['prenom'] ?? '';
          final nom = data['nom'] ?? '';
          name = '$prenom $nom'.trim();
        } else if (user.displayName?.trim().isNotEmpty == true) {
          name = user.displayName;
        } else {
          name = user.email?.split('@').first;
        }

        setState(() {
          _userName = name;
          _userRole = data['role'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = user.displayName?.isNotEmpty == true
              ? user.displayName
              : user.email?.split('@').first;
          _userRole = 'admin';
        });
      }
    }
  }

  // ✅ #5 : case 10 → ClientsBehaviorPage ajouté
  Widget _buildPage(int index) {
    switch (index) {
      case 0:  return const _DashboardPage();
      case 1:  return const AccountsList();
      case 2:  return const ReservationsAdminList();
      case 3:  return const OrdersAdminList();
      case 4:  return const CheckInOutAdminList();
      case 5:  return const _AlertsAdminPage();
      case 6:  return const _TarifsPage();
      case 7:  return const ServicesPage();
      case 8:  return const ParametresPage();
      case 9:  return const AnalysesIAPage();
      case 10: return const _ClientsProfilsPage();
      case 11: return const ChambresAdminPage();
      default: return const _DashboardPage();
    }
  }

  Future<void> _signOut() async => FirebaseAuth.instance.signOut();

  String get _initial => (_userName?.isNotEmpty == true
          ? _userName![0]
          : _userEmail?.isNotEmpty == true
              ? _userEmail![0]
              : 'A')
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: _buildAppBar(isWeb),
      drawer: isWeb ? null : _buildDrawer(),
      body: isWeb
          ? Row(children: [
              _buildSidebar(),
              // ✅ IndexedStack évite le bug de rechargement entre pages
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: List.generate(12, (i) => _buildPage(i)),
                ),
              ),
            ])
          // ✅ Mobile : même fix
          : IndexedStack(
              index: _selectedIndex,
              children: List.generate(12, (i) => _buildPage(i)),
            ),
    );
  }

  AppBar _buildAppBar(bool isWeb) {
    return AppBar(
      title: Text(
        'FLOSTAY ADMIN',
        style: GoogleFonts.roboto(
          fontSize: isWeb ? 20 : 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
      centerTitle: false,
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('status', isEqualTo: 'new')
              .snapshots(),
          builder: (ctx, snap) {
            final count = snap.data?.docs.length ?? 0;
            return Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  onPressed: () => setState(() => _selectedIndex = 5),
                ),
                if (count > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Text('$count',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
            icon: const Icon(Icons.logout_rounded), onPressed: _signOut),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: _primary.withOpacity(0.04),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _primary,
                  child: Text(_initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // ✅ Affiche le vrai nom de l'utilisateur connecté
                        _userName ??
                            _userEmail?.split('@').first ??
                            'Admin',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _dark),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(_userRole ?? 'admin',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (_, i) {
                final item = _navItems[i];
                return _SidebarItem(
                  item: item,
                  isSelected: _selectedIndex == item.index,
                  onTap: () => setState(() => _selectedIndex = item.index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _userName ?? _userEmail?.split('@').first ?? 'Admin',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_userEmail ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(_initial,
                  style: const TextStyle(fontSize: 22, color: _primary)),
            ),
            decoration: const BoxDecoration(color: _primary),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _navItems.length,
              itemBuilder: (ctx, i) {
                final item = _navItems[i];
                return ListTile(
                  leading: Icon(item.icon,
                      color: _selectedIndex == item.index
                          ? _primary
                          : Colors.grey[600],
                      size: 22),
                  title: Text(item.label,
                      style: TextStyle(
                        fontWeight: _selectedIndex == item.index
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: _selectedIndex == item.index
                            ? _primary
                            : Colors.black87,
                      )),
                  onTap: () {
                    setState(() => _selectedIndex = item.index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: Colors.red, size: 22),
            title: const Text('Déconnexion',
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _signOut();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

class _NavItem {
  final int index;
  final IconData icon;
  final String label;
  const _NavItem(this.index, this.icon, this.label);
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  const _SidebarItem(
      {required this.item, required this.isSelected, required this.onTap});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected ? _primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 20,
                    color: isSelected ? _primary : Colors.grey[600]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: isSelected ? _primary : Colors.black87,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DASHBOARD
// ══════════════════════════════════════════════════════════════════════════════

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    // ✅ #2 : try/catch pour éviter le crash si la locale n'est pas initialisée
    String dateStr;
    try {
      dateStr =
          DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now());
    } catch (_) {
      dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tableau de bord',
              style: TextStyle(
                  fontSize: isWeb ? 24 : 20,
                  fontWeight: FontWeight.w800,
                  color: _dark)),
          Text(dateStr,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 24),

          // Stats
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _StatCard('Clients', Icons.people_rounded,
                    FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'client'),
                    const Color(0xFF457B9D)),
                _StatCard(
                    'Réceptionnistes',
                    Icons.support_agent_rounded,
                    // ✅ #4 : whereIn pour matcher toutes variantes
                    FirebaseFirestore.instance.collection('users').where(
                        'role',
                        whereIn: [
                          'receptionniste',
                          'réceptionniste',
                          'receptionist'
                        ]),
                    const Color(0xFF2A9D8F)),
                _StatCard('Cuisine', Icons.restaurant_rounded,
                    FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'cuisine'),
                    const Color(0xFFE76F51)),
                _StatCard('Réservations', Icons.hotel_rounded,
                    FirebaseFirestore.instance.collection('reservations'),
                    _primary),
                _StatCard('Commandes', Icons.room_service_rounded,
                    FirebaseFirestore.instance.collection('orders'),
                    const Color(0xFF264653)),
                _StatCard(
                    'Check-in actifs',
                    Icons.login_rounded,
                    FirebaseFirestore.instance
                        .collection('reservations')
                        .where('statut', isEqualTo: 'checkin'),
                    Colors.teal),
                _StatCard(
                    'Alertes actives',
                    Icons.warning_rounded,
                    FirebaseFirestore.instance.collection('alerts').where(
                        'status',
                        whereIn: ['new', 'in_progress']),
                    Colors.redAccent),
                _StatCard('Avis clients', Icons.star_rounded,
                    FirebaseFirestore.instance.collection('reviews'),
                    Colors.amber),
              ],
            );
          }),

          const SizedBox(height: 28),
          Text('Actions rapides',
              style: TextStyle(
                  fontSize: isWeb ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: _dark)),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _ActionButton('Créer un membre', Icons.person_add_rounded,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CreateStaffPage()))),
                _ActionButton('Réservation', Icons.hotel_rounded,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CreateReservationPage()))),
                _ActionButton('Check-in/out', Icons.check_circle_rounded,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CheckInOutAdminList()))),
                _ActionButton('Analyses IA', Icons.auto_awesome_rounded,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AnalysesIAPage()))),
              ],
            );
          }),

          const SizedBox(height: 28),
          Text('Alertes récentes',
              style: TextStyle(
                  fontSize: isWeb ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: _dark)),
          const SizedBox(height: 14),
          _buildRecentAlerts(),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }
        final alerts = snap.data?.docs ?? [];
        if (alerts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text('Aucune alerte pour le moment'),
            ]),
          );
        }
        return Column(
          children: alerts.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'new';
            final statusColor = status == 'resolved'
                ? Colors.green
                : status == 'in_progress'
                    ? Colors.orange
                    : Colors.red;
            final ts = data['timestamp'] as Timestamp?;
            final time = ts != null
                ? DateFormat('dd/MM HH:mm').format(ts.toDate())
                : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.25)),
              ),
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message'] ?? data['title'] ?? 'Alerte',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(data['userName'] ?? '',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Text(time,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[400])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'resolved'
                        ? 'Résolu'
                        : status == 'in_progress'
                            ? 'En cours'
                            : 'Nouveau',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── StatCard ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Query query;
  final Color color;
  const _StatCard(this.title, this.icon, this.query, this.color);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text('$count',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 4),
              Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4A2A10))),
            ],
          ),
        );
      },
    );
  }
}

// ── ActionButton ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _ActionButton(this.label, this.icon, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ALERTES ADMIN
// ══════════════════════════════════════════════════════════════════════════════

class _AlertsAdminPage extends StatefulWidget {
  const _AlertsAdminPage();
  @override
  State<_AlertsAdminPage> createState() => _AlertsAdminPageState();
}

class _AlertsAdminPageState extends State<_AlertsAdminPage> {
  static const _primary = Color(0xFF9B4610);
  String _filter = 'all';

  Future<void> _updateStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('alerts').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
    });
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('alerts')
        .orderBy('timestamp', descending: true);
    if (_filter != 'all') query = query.where('status', isEqualTo: _filter);

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in [
              ('all', 'Toutes'),
              ('new', 'Nouvelles'),
              ('in_progress', 'En cours'),
              ('resolved', 'Résolues'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                  selectedColor: _primary,
                  labelStyle: TextStyle(
                      color:
                          _filter == f.$1 ? Colors.white : Colors.black87),
                ),
              ),
          ]),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _primary));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Aucune alerte'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final status = data['status'] ?? 'new';
                final statusColor = status == 'resolved'
                    ? Colors.green
                    : status == 'in_progress'
                        ? Colors.orange
                        : Colors.red;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  data['alertTypeLabel'] ??
                                      data['alertType'] ??
                                      'Alerte',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                status == 'resolved'
                                    ? 'Résolu'
                                    : status == 'in_progress'
                                        ? 'En cours'
                                        : 'Nouveau',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                            '${data['userName'] ?? 'Client'} • Chambre ${data['userRoom'] ?? '?'}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(data['message'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        if (status != 'resolved') ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            if (status == 'new')
                              OutlinedButton(
                                onPressed: () => _updateStatus(
                                    docs[i].id, 'in_progress'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(
                                        color: Colors.orange),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                child: const Text('Prendre en charge',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            const SizedBox(width: 8),
                            if (status == 'in_progress')
                              ElevatedButton(
                                onPressed: () => _updateStatus(
                                    docs[i].id, 'resolved'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                child: const Text('Résoudre',
                                    style: TextStyle(fontSize: 12)),
                              ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TARIFS  — ✅ CORRECTIF #3
// ══════════════════════════════════════════════════════════════════════════════

class _TarifsPage extends StatefulWidget {
  const _TarifsPage();
  @override
  State<_TarifsPage> createState() => _TarifsPageState();
}

class _TarifsPageState extends State<_TarifsPage> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  final _firestore = FirebaseFirestore.instance;
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;
  bool _loaded = false;

  // (label affiché, clé Firestore, prix par défaut)
  static const _rooms = [
    ('Standard', 'standard', 35000),
    ('Premium', 'premium', 48580),
    ('Prestige', 'prestige', 58580),
    ('Deluxe', 'deluxe', 78580),
    ('Suite', 'suite', 120000),
  ];

  @override
  void initState() {
    super.initState();
    for (final r in _rooms) {
      _controllers[r.$2] = TextEditingController();
    }
    _loadPrices();
  }

  @override
  void dispose() {
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadPrices() async {
    try {
      final doc =
          await _firestore.collection('tarifs').doc('chambres').get();
      for (final r in _rooms) {
        final rawData = doc.exists ? doc.data() : null;
        final val = rawData != null ? rawData[r.$2] : null;
        // Utilise la valeur Firestore si non nulle et non zéro, sinon la valeur par défaut
        _controllers[r.$2]!.text =
            (val != null && (val as num) > 0) ? val.toString() : r.$3.toString();
      }
    } catch (_) {
      for (final r in _rooms) {
        _controllers[r.$2]!.text = r.$3.toString();
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _savePrices() async {
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      for (final r in _rooms) {
        data[r.$2] = int.tryParse(_controllers[r.$2]!.text) ?? r.$3;
      }
      await _firestore
          .collection('tarifs')
          .doc('chambres')
          .set(data, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Tarifs enregistrés avec succès'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tarifs des chambres',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            const SizedBox(height: 6),
            Text('Prix en FCFA par nuit',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ...(_rooms.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chambre ${r.$1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _dark)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _controllers[r.$2],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: 'FCFA  ',
                          hintText: r.$3.toString(),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: _primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _savePrices,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                    _saving ? 'Enregistrement…' : 'Enregistrer les tarifs',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// PAGE PROFILS CLIENTS (onglet admin)
// Liste les clients avec bouton "Voir profil complet"
// ══════════════════════════════════════════════════════════════════════════════
class _ClientsProfilsPage extends StatefulWidget {
  const _ClientsProfilsPage();
  @override
  State<_ClientsProfilsPage> createState() => _ClientsProfilsPageState();
}

class _ClientsProfilsPageState extends State<_ClientsProfilsPage> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher un client...',
              prefixIcon: const Icon(Icons.search, color: _primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'client')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _primary));
              }
              var docs = snap.data?.docs ?? [];
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_search) || email.contains(_search);
                }).toList();
              }
              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Aucun client trouvé', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ]),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final uid = doc.id;
                  final name = data['name'] ?? data['displayName'] ??
                      data['email']?.toString().split('@').first ?? 'Client';
                  final email = data['email'] ?? '';
                  final profileImage = data['profileImage'] as String?;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _primary.withOpacity(0.12),
                                backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                                child: profileImage == null
                                    ? Text(initial,
                                        style: const TextStyle(color: _primary, fontWeight: FontWeight.w700, fontSize: 18))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _dark)),
                                    const SizedBox(height: 2),
                                    Text(email,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('CLIENT',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primary)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileAdminPage(
                                    userId: uid,
                                    userName: name,
                                    userEmail: email,
                                    userRole: 'client',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.person_search_rounded, size: 16),
                              label: const Text('Voir le profil complet',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
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
          ),
        ),
      ],
    );
  }
}