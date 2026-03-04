// ============================================================
// clients_behavior_page.dart
//
// Page de liste des clients pour l'administrateur.
// Affiche tous les clients avec leurs indicateurs clés
// (nombre de séjours, chambre favorite, statut fidélité).
// Un clic ouvre le profil comportemental complet.
//
// À ajouter dans admin_page.dart :
//   case XX: return const ClientsBehaviorPage();
//
// Et dans la liste _navItems :
//   _NavItem(XX, Icons.psychology_rounded, 'Profils clients', null),
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'client_profile_admin_page.dart';

class ClientsBehaviorPage extends StatefulWidget {
  const ClientsBehaviorPage({Key? key}) : super(key: key);

  @override
  State<ClientsBehaviorPage> createState() =>
      _ClientsBehaviorPageState();
}

class _ClientsBehaviorPageState extends State<ClientsBehaviorPage> {
  // ── Couleurs ─────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // ── État ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;

  // Liste enrichie des clients avec leurs métriques
  List<_ClientSummary> _clients = [];
  List<_ClientSummary> _filtered = [];

  // Recherche & tri
  final _searchCtrl = TextEditingController();
  String _sortBy = 'name'; // name | stays | rating

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CHARGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fs = FirebaseFirestore.instance;

      // Récupère tous les clients
      final usersSnap = await fs
          .collection('users')
          .where('role', isEqualTo: 'client')
          .get();

      // Pour chaque client, charge ses métriques en parallèle
      final futures = usersSnap.docs.map((userDoc) async {
        final uid = userDoc.id;
        final data = userDoc.data();

        // Réservations du client
        final reservSnap = await fs
            .collection('reservations')
            .where('userId', isEqualTo: uid)
            .get();

        // Commandes du client
        final ordersSnap = await fs
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .get();

        // Avis du client
        final reviewsSnap = await fs
            .collection('reviews')
            .where('userId', isEqualTo: uid)
            .get();

        // Calcul chambre favorite
        final roomTypes = <String, int>{};
        for (final r in reservSnap.docs) {
          final type =
              (r.data() as Map)['chambre']?.toString() ?? 'Autre';
          roomTypes[type] = (roomTypes[type] ?? 0) + 1;
        }
        final favoriteRoom = roomTypes.isNotEmpty
            ? roomTypes.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key
            : null;

        // Note moyenne
        double avgRating = 0;
        if (reviewsSnap.docs.isNotEmpty) {
          double total = 0;
          for (final r in reviewsSnap.docs) {
            total +=
                ((r.data() as Map)['rating'] ?? 0 as num).toDouble();
          }
          avgRating = total / reviewsSnap.docs.length;
        }

        // Total dépensé
        int totalSpent = 0;
        for (final o in ordersSnap.docs) {
          totalSpent +=
              ((o.data() as Map)['total'] ?? 0 as num).toInt();
        }

        return _ClientSummary(
          uid: uid,
          name: data['name'] ?? data['email']?.split('@').first ?? 'Client',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          totalStays: reservSnap.docs.length,
          favoriteRoom: favoriteRoom,
          avgRating: avgRating,
          totalOrders: ordersSnap.docs.length,
          totalSpent: totalSpent,
          isLoyal: reservSnap.docs.length >= 3,
          isHighValue: totalSpent > 200000,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        );
      });

      final clients = await Future.wait(futures);

      // Tri par défaut : nombre de séjours décroissant
      clients.sort((a, b) => b.totalStays.compareTo(a.totalStays));

      setState(() {
        _clients = clients;
        _filtered = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _isLoading = false;
      });
    }
  }

  // Filtre la liste selon la recherche et le tri
  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    var list = _clients.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();

    // Tri
    switch (_sortBy) {
      case 'stays':
        list.sort((a, b) => b.totalStays.compareTo(a.totalStays));
        break;
      case 'rating':
        list.sort((a, b) => b.avgRating.compareTo(a.avgRating));
        break;
      case 'spent':
        list.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
        break;
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
    }

    setState(() => _filtered = list);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 12),
            Text('Analyse des profils clients…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadClients,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── En-tête avec stats globales ─────────────────────────────────
        _buildHeader(isWeb),
        // ── Barre recherche + tri ───────────────────────────────────────
        _buildSearchBar(),
        // ── Liste ──────────────────────────────────────────────────────
        Expanded(
          child: _filtered.isEmpty
              ? _buildEmpty()
              : isWeb
                  ? _buildWebGrid()
                  : _buildMobileList(),
        ),
      ],
    );
  }

  // ── En-tête ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isWeb) {
    final loyalCount = _clients.where((c) => c.isLoyal).length;
    final vipCount = _clients.where((c) => c.isHighValue).length;

    return Container(
      padding: EdgeInsets.all(isWeb ? 20 : 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A2A10), _primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profils comportementaux',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_clients.length} clients  •  '
                  '$loyalCount fidèles  •  $vipCount VIP',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          // Bouton actualiser
          IconButton(
            onPressed: _loadClients,
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white),
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }

  // ── Barre de recherche + tri ──────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Champ de recherche
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF9B4610).withOpacity(0.15)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher un client…',
                  hintStyle:
                      TextStyle(fontSize: 13, color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: Colors.grey[400]),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tri
          PopupMenuButton<String>(
            onSelected: (v) {
              setState(() => _sortBy = v);
              _applyFilter();
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF9B4610).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sort_rounded,
                  size: 18, color: _primary),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'name', child: Text('Trier par nom')),
              const PopupMenuItem(
                  value: 'stays',
                  child: Text('Trier par séjours')),
              const PopupMenuItem(
                  value: 'spent',
                  child: Text('Trier par dépenses')),
              const PopupMenuItem(
                  value: 'rating',
                  child: Text('Trier par note')),
            ],
          ),
        ],
      ),
    );
  }

  // ── Liste mobile ──────────────────────────────────────────────────────────

  Widget _buildMobileList() {
    return RefreshIndicator(
      onRefresh: _loadClients,
      color: _primary,
      child: ListView.separated(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) =>
            _ClientCard(client: _filtered[i], isWeb: false),
      ),
    );
  }

  // ── Grille web ────────────────────────────────────────────────────────────

  Widget _buildWebGrid() {
    return RefreshIndicator(
      onRefresh: _loadClients,
      color: _primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          childAspectRatio: 1.55,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _filtered.length,
        itemBuilder: (_, i) =>
            _ClientCard(client: _filtered[i], isWeb: true),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun client trouvé',
            style: TextStyle(
                fontSize: 15, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MODÈLE CLIENT RÉSUMÉ
// ══════════════════════════════════════════════════════════════════════════════

class _ClientSummary {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final int totalStays;
  final String? favoriteRoom;
  final double avgRating;
  final int totalOrders;
  final int totalSpent;
  final bool isLoyal;
  final bool isHighValue;
  final DateTime? createdAt;

  const _ClientSummary({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.totalStays,
    required this.favoriteRoom,
    required this.avgRating,
    required this.totalOrders,
    required this.totalSpent,
    required this.isLoyal,
    required this.isHighValue,
    required this.createdAt,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  CARTE CLIENT
// ══════════════════════════════════════════════════════════════════════════════

class _ClientCard extends StatelessWidget {
  final _ClientSummary client;
  final bool isWeb;

  const _ClientCard({required this.client, required this.isWeb});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  // Couleur de l'avatar selon le profil
  Color get _avatarColor {
    if (client.isHighValue) return const Color(0xFFE9C46A);
    if (client.isLoyal) return const Color(0xFF2A9D8F);
    return _primary;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.07),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Ouvre le profil comportemental complet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientProfileAdminPage(
                clientId: client.uid,
                clientName: client.name,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne 1 : Avatar + nom + badges ───────────────────────
              Row(
                children: [
                  // Avatar avec initiale
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _avatarColor.withOpacity(0.15),
                    child: Text(
                      client.name.isNotEmpty
                          ? client.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _avatarColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _dark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          client.email,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Flèche
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 10),

              // ── Badges statut ──────────────────────────────────────────
              Row(
                children: [
                  if (client.isHighValue)
                    _StatusBadge('⭐ VIP',
                        const Color(0xFFE9C46A))
                  else if (client.isLoyal)
                    _StatusBadge('🏅 Fidèle',
                        const Color(0xFF2A9D8F))
                  else
                    _StatusBadge('Nouveau', Colors.grey),
                  const SizedBox(width: 6),
                  if (client.favoriteRoom != null)
                    _StatusBadge(
                      '🛏 ${client.favoriteRoom}',
                      _primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Stats ──────────────────────────────────────────────────
              Row(
                children: [
                  _StatItem(
                    Icons.hotel_rounded,
                    '${client.totalStays}',
                    'séjours',
                  ),
                  const SizedBox(width: 14),
                  _StatItem(
                    Icons.restaurant_rounded,
                    '${client.totalOrders}',
                    'commandes',
                  ),
                  const SizedBox(width: 14),
                  if (client.avgRating > 0)
                    _StatItem(
                      Icons.star_rounded,
                      client.avgRating.toStringAsFixed(1),
                      'note',
                      color: Colors.amber,
                    ),
                ],
              ),

              // ── Total dépensé ──────────────────────────────────────────
              if (client.totalSpent > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.payments_rounded,
                        size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(client.totalSpent)} FCFA dépensés',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Petit badge statut ────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Mini indicateur statistique ───────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  const _StatItem(this.icon, this.value, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF9B4610);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }
}