// ============================================================
// activite_receptionnistes_page.dart
// Page de suivi d'activité des réceptionnistes et de la cuisine
// pour l'administrateur.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActiviteReceptionnistesPage extends StatelessWidget {
  const ActiviteReceptionnistesPage({Key? key}) : super(key: key);

  // Couleurs de la charte graphique
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text('Activité du Personnel'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Récupère les utilisateurs avec rôle réceptionniste OU cuisine
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', whereIn: ['receptionist', 'cuisine'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (snapshot.hasError) {
            return _buildError('Erreur: ${snapshot.error}');
          }

          final staff = snapshot.data?.docs ?? [];

          if (staff.isEmpty) {
            return _buildEmpty();
          }

          return isWeb
              ? _buildWebLayout(context, staff)
              : _buildMobileLayout(context, staff);
        },
      ),
    );
  }

  // ── Layout web : grille 2 colonnes ──────────────────────────────────────

  Widget _buildWebLayout(BuildContext context, List<QueryDocumentSnapshot> staff) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          // Stats globales
          _buildGlobalStats(staff),
          const SizedBox(height: 24),
          const Text(
            'Membres du personnel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 2.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: staff.length,
            itemBuilder: (ctx, i) {
              final data = staff[i].data() as Map<String, dynamic>;
              return _StaffCard(
                staffId: staff[i].id,
                data: data,
                isWeb: true,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Layout mobile : liste ───────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, List<QueryDocumentSnapshot> staff) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildGlobalStats(staff),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Membres du personnel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final data = staff[i].data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StaffCard(
                    staffId: staff[i].id,
                    data: data,
                    isWeb: false,
                  ),
                );
              },
              childCount: staff.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── En-tête de la page ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.badge_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suivi du personnel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Réceptionnistes & Cuisine',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Statistiques globales ───────────────────────────────────────────────

  Widget _buildGlobalStats(List<QueryDocumentSnapshot> staff) {
    // Compte par rôle
    final receptionCount = staff
        .where((s) => (s.data() as Map)['role'] == 'receptionist')
        .length;
    final cuisineCount = staff
        .where((s) => (s.data() as Map)['role'] == 'cuisine')
        .length;

    return Row(
      children: [
        Expanded(
          child: _StatMini(
            label: 'Réceptionnistes',
            value: receptionCount,
            icon: Icons.support_agent_rounded,
            color: const Color(0xFF2A9D8F),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMini(
            label: 'Cuisine',
            value: cuisineCount,
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFE76F51),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatMini(
            label: 'Total personnel',
            value: staff.length,
            icon: Icons.people_rounded,
            color: _primary,
          ),
        ),
      ],
    );
  }

  // ── Widgets d'état ──────────────────────────────────────────────────────

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 60, color: Colors.red),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun membre du personnel trouvé',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ── Carte membre du personnel ─────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final String staffId;
  final Map<String, dynamic> data;
  final bool isWeb;

  const _StaffCard({
    required this.staffId,
    required this.data,
    required this.isWeb,
  });

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Sans nom';
    final email = data['email'] ?? 'Sans email';
    final role = data['role'] ?? 'staff';
    final isReceptionist = role == 'receptionist';

    final roleColor = isReceptionist
        ? const Color(0xFF2A9D8F)
        : const Color(0xFFE76F51);
    final roleLabel = isReceptionist ? 'Réceptionniste' : 'Cuisine';
    final roleIcon = isReceptionist
        ? Icons.support_agent_rounded
        : Icons.restaurant_rounded;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailActivitePage(
                staffId: staffId,
                staffName: name,
                role: roleLabel,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar avec initiales
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _dark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Badge rôle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(roleIcon, size: 11, color: roleColor),
                          const SizedBox(width: 4),
                          Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini stat card ────────────────────────────────────────────────────────────

class _StatMini extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ── Page de détail d'activité ────────────────────────────────────────────────

class DetailActivitePage extends StatefulWidget {
  final String staffId;
  final String staffName;
  final String role;

  const DetailActivitePage({
    Key? key,
    required this.staffId,
    required this.staffName,
    required this.role,
  }) : super(key: key);

  @override
  State<DetailActivitePage> createState() => _DetailActivitePageState();
}

class _DetailActivitePageState extends State<DetailActivitePage> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // Filtre de période
  String _periodFilter = 'today'; // today | week | all

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text('Activité – ${widget.staffName}'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // En-tête avec infos staff
          _buildStaffHeader(),
          // Filtres de période
          _buildPeriodFilter(),
          // Liste des activités
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}'),
                  );
                }

                final logs = snapshot.data?.docs ?? [];

                if (logs.isEmpty) {
                  return _buildEmptyLogs();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (ctx, i) {
                    final data = logs[i].data() as Map<String, dynamic>;
                    // Dernier item = pas de connecteur de timeline
                    final isLast = i == logs.length - 1;
                    return _ActivityItem(
                      data: data,
                      isLast: isLast,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Construit la requête Firestore selon le filtre sélectionné
  Stream<QuerySnapshot> _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('activity_logs')
        .where('userId', isEqualTo: widget.staffId)
        .orderBy('timestamp', descending: true);

    final now = DateTime.now();
    if (_periodFilter == 'today') {
      final startOfDay = DateTime(now.year, now.month, now.day);
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      );
    } else if (_periodFilter == 'week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(
          startOfWeek.year, startOfWeek.month, startOfWeek.day);
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }

    return query.snapshots();
  }

  // En-tête avec avatar et infos du membre du staff
  Widget _buildStaffHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _primary,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              widget.staffName.isNotEmpty
                  ? widget.staffName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.staffName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sélecteur de période
  Widget _buildPeriodFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          for (final f in [
            ('today', "Aujourd'hui"),
            ('week', 'Cette semaine'),
            ('all', 'Tout'),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  onPressed: () => setState(() => _periodFilter = f.$1),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _periodFilter == f.$1
                        ? _primary
                        : Colors.transparent,
                    foregroundColor: _periodFilter == f.$1
                        ? Colors.white
                        : Colors.grey[700],
                    side: BorderSide(
                      color: _periodFilter == f.$1
                          ? _primary
                          : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    f.$2,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyLogs() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucune activité enregistrée\npour cette période',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item de timeline d'activité ───────────────────────────────────────────────

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isLast;

  const _ActivityItem({required this.data, required this.isLast});

  static const _primary = Color(0xFF9B4610);

  // Donne une couleur et une icône selon le type d'action
  (Color, IconData) _getActionStyle(String action) {
    final a = action.toLowerCase();
    if (a.contains('check-in') || a.contains('checkin')) {
      return (const Color(0xFF2A9D8F), Icons.login_rounded);
    } else if (a.contains('check-out') || a.contains('checkout')) {
      return (const Color(0xFFE76F51), Icons.logout_rounded);
    } else if (a.contains('réservation') || a.contains('reservation')) {
      return (_primary, Icons.hotel_rounded);
    } else if (a.contains('commande') || a.contains('order')) {
      return (const Color(0xFF264653), Icons.restaurant_rounded);
    } else if (a.contains('alerte') || a.contains('alert')) {
      return (Colors.red, Icons.warning_rounded);
    } else if (a.contains('message') || a.contains('chat')) {
      return (Colors.purple, Icons.chat_rounded);
    }
    return (Colors.grey, Icons.circle_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final action = data['action'] ?? 'Action inconnue';
    final details = data['details'] ?? '';
    final timestamp = data['timestamp'] != null
        ? DateFormat('dd/MM/yyyy HH:mm')
            .format((data['timestamp'] as Timestamp).toDate())
        : 'Date inconnue';

    final (color, icon) = _getActionStyle(action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colonne de timeline (point + ligne)
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF4A2A10),
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}