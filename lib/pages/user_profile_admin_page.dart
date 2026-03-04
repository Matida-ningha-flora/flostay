// ============================================================
// user_profile_admin_page.dart
//
// Page profil complet d'un utilisateur (vue admin) avec :
// - Infos personnelles
// - Statistiques globales (CA, réservations, commandes)
// - Historique réservations avec statuts
// - Historique commandes avec montants
// - Préférences détectées automatiquement
// - Analyse comportementale pour services personnalisés
//
// Usage :
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => UserProfileAdminPage(userId: 'uid', userName: 'Nom'),
//   ));
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserProfileAdminPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const UserProfileAdminPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<UserProfileAdminPage> createState() => _UserProfileAdminPageState();
}

class _UserProfileAdminPageState extends State<UserProfileAdminPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  // Données chargées
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _commandes = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _ratings = [];

  bool _isLoading = true;

  // Analytics calculés
  double _totalCA = 0;
  double _avgReservationValue = 0;
  double _avgCommandeValue = 0;
  String _preferredRoomType = '—';
  String _preferredFood = '—';
  String _clientSegment = '—';
  double _avgRating = 0;
  int _loyaltyScore = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadUserData(),
      _loadReservations(),
      _loadCommandes(),
      _loadAlerts(),
      _loadRatings(),
    ]);
    _computeAnalytics();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    final doc =
        await _firestore.collection('users').doc(widget.userId).get();
    if (doc.exists) _userData = doc.data();
  }

  Future<void> _loadReservations() async {
    final snap = await _firestore
        .collection('reservations')
        .where('userId', isEqualTo: widget.userId)
        .get();
    _reservations = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    _reservations.sort((a, b) {
      final aTs = a['createdAt'] as Timestamp?;
      final bTs = b['createdAt'] as Timestamp?;
      if (aTs == null || bTs == null) return 0;
      return bTs.compareTo(aTs);
    });
  }

  Future<void> _loadCommandes() async {
    final snap = await _firestore
        .collection('commandes')
        .where('userId', isEqualTo: widget.userId)
        .get();
    _commandes = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    _commandes.sort((a, b) {
      final aTs = a['date'] as Timestamp?;
      final bTs = b['date'] as Timestamp?;
      if (aTs == null || bTs == null) return 0;
      return bTs.compareTo(aTs);
    });
  }

  Future<void> _loadAlerts() async {
    final snap = await _firestore
        .collection('alerts')
        .where('userId', isEqualTo: widget.userId)
        .get();
    _alerts = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> _loadRatings() async {
    final snap = await _firestore
        .collection('ratings')
        .where('userId', isEqualTo: widget.userId)
        .get();
    _ratings = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  void _computeAnalytics() {
    // CA total
    double caRes = 0;
    double caCmd = 0;

    for (final r in _reservations) {
      caRes += (r['totalAmount'] ?? r['price'] ?? 0) as num;
    }
    for (final c in _commandes) {
      caCmd += (c['total'] ?? 0) as num;
    }
    _totalCA = caRes + caCmd;

    // Moyennes
    if (_reservations.isNotEmpty) {
      _avgReservationValue = caRes / _reservations.length;
    }
    if (_commandes.isNotEmpty) {
      _avgCommandeValue = caCmd / _commandes.length;
    }

    // Chambre préférée
    final roomCounts = <String, int>{};
    for (final r in _reservations) {
      final rt = r['roomType'] as String?;
      if (rt != null && rt.isNotEmpty) {
        roomCounts[rt] = (roomCounts[rt] ?? 0) + 1;
      }
    }
    if (roomCounts.isNotEmpty) {
      _preferredRoomType = roomCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // Plat préféré
    final foodCounts = <String, int>{};
    for (final c in _commandes) {
      final item = c['item'] as String?;
      if (item != null && item.isNotEmpty) {
        foodCounts[item] = (foodCounts[item] ?? 0) + 1;
      }
    }
    if (foodCounts.isNotEmpty) {
      _preferredFood = foodCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // Note moyenne
    if (_ratings.isNotEmpty) {
      double total = 0;
      for (final r in _ratings) {
        total += (r['overallRating'] ?? 0) as num;
      }
      _avgRating = total / _ratings.length;
    }

    // Segment client
    if (_totalCA > 500000) {
      _clientSegment = '⭐ VIP';
    } else if (_totalCA > 200000) {
      _clientSegment = '🥈 Premium';
    } else if (_reservations.length >= 3) {
      _clientSegment = '🔄 Fidèle';
    } else if (_reservations.isNotEmpty) {
      _clientSegment = '🆕 Régulier';
    } else {
      _clientSegment = '👤 Nouveau';
    }

    // Score fidélité (sur 100)
    _loyaltyScore = (_reservations.length * 15 +
            _commandes.length * 5 +
            (_avgRating * 10).round())
        .clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: _buildAppBar(),
        body: const Center(
            child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(),

          // ── Onglets ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: _primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _primary,
              isScrollable: true,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Vue globale'),
                Tab(text: 'Réservations'),
                Tab(text: 'Commandes'),
                Tab(text: 'Analyse IA'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildReservationsTab(),
                _buildCommandesTab(),
                _buildAiTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.userName,
          style: const TextStyle(color: Colors.white)),
      backgroundColor: _dark,
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }

  Widget _buildHeader() {
    final profileImage = _userData?['profileImage'] as String?;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A2A10), _primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            backgroundImage:
                profileImage != null ? NetworkImage(profileImage) : null,
            child: profileImage == null
                ? Text(
                    widget.userName.isNotEmpty
                        ? widget.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _primary),
                  )
                : null,
          ),
          const SizedBox(width: 16),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(widget.userEmail,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.75))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildPill(widget.userRole.toUpperCase(), Colors.white,
                        _primary),
                    const SizedBox(width: 8),
                    _buildPill(_clientSegment, _primary, Colors.white),
                  ],
                ),
              ],
            ),
          ),

          // Score fidélité
          Column(
            children: [
              Text(
                '$_loyaltyScore',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
              Text(
                'Score fidélité',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.75)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(0.5)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // ── Onglet Vue globale ────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // KPIs principaux
          Row(
            children: [
              _buildKpi('CA Total',
                  '${NumberFormat('#,###', 'fr_FR').format(_totalCA)} FCFA',
                  Icons.attach_money_rounded, Colors.green),
              const SizedBox(width: 12),
              _buildKpi('Réservations', '${_reservations.length}',
                  Icons.hotel_rounded, _primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildKpi('Commandes', '${_commandes.length}',
                  Icons.room_service_rounded, Colors.orange),
              const SizedBox(width: 12),
              _buildKpi('Note moyenne',
                  _avgRating > 0
                      ? _avgRating.toStringAsFixed(1)
                      : '—',
                  Icons.star_rounded, Colors.amber),
            ],
          ),

          const SizedBox(height: 20),

          // Coordonnées
          _buildCard(
            title: 'Coordonnées',
            icon: Icons.contact_page_rounded,
            child: Column(
              children: [
                _buildInfoRow(Icons.email_rounded, 'Email',
                    _userData?['email'] ?? widget.userEmail),
                _buildInfoRow(Icons.phone_rounded, 'Téléphone',
                    _userData?['phone'] ?? '—'),
                _buildInfoRow(Icons.calendar_today_rounded, 'Inscrit le',
                    _userData?['createdAt'] != null
                        ? DateFormat('dd/MM/yyyy').format(
                            (_userData!['createdAt'] as Timestamp)
                                .toDate())
                        : '—'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Préférences détectées
          _buildCard(
            title: 'Préférences détectées',
            icon: Icons.auto_awesome_rounded,
            child: Column(
              children: [
                _buildInfoRow(
                    Icons.hotel_rounded, 'Chambre favorite', _preferredRoomType),
                _buildInfoRow(
                    Icons.restaurant_rounded, 'Plat favori', _preferredFood),
                _buildInfoRow(Icons.trending_up_rounded, 'Panier moyen réservation',
                    '${NumberFormat('#,###', 'fr_FR').format(_avgReservationValue)} FCFA'),
                _buildInfoRow(Icons.shopping_cart_rounded, 'Panier moyen commande',
                    '${NumberFormat('#,###', 'fr_FR').format(_avgCommandeValue)} FCFA'),
                _buildInfoRow(Icons.warning_rounded, 'Alertes signalées',
                    '${_alerts.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Onglet Réservations ───────────────────────────────────────────────────

  Widget _buildReservationsTab() {
    if (_reservations.isEmpty) {
      return _buildEmpty('Aucune réservation', Icons.hotel_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _reservations.length,
      itemBuilder: (_, i) {
        final r = _reservations[i];
        final status = r['status'] ?? 'pending';
        final checkIn = r['checkInDate'];
        final checkOut = r['checkOutDate'];
        final total = (r['totalAmount'] ?? r['price'] ?? 0) as num;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: _reservationStatusColor(status).withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r['roomType'] ?? 'Chambre',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _dark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _reservationStatusColor(status)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _reservationStatusText(status),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _reservationStatusColor(status)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatTs(checkIn)} → ${_formatTs(checkOut)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chambre: ${r['roomNumber'] ?? '—'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(total)} FCFA',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Onglet Commandes ──────────────────────────────────────────────────────

  Widget _buildCommandesTab() {
    if (_commandes.isEmpty) {
      return _buildEmpty('Aucune commande', Icons.room_service_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _commandes.length,
      itemBuilder: (_, i) {
        final c = _commandes[i];
        final statut = c['statut'] ?? 'en_attente';
        final total = (c['total'] ?? 0) as num;
        final date = c['date'] as Timestamp?;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _commandeStatusColor(statut).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_rounded,
                  color: _commandeStatusColor(statut), size: 20),
            ),
            title: Text(c['item'] ?? 'Article',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Qté: ${c['quantite'] ?? 1}  •  ${_commandeStatusText(statut)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(date.toDate()),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
              ],
            ),
            trailing: Text(
              '${NumberFormat('#,###', 'fr_FR').format(total)} FCFA',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _primary),
            ),
          ),
        );
      },
    );
  }

  // ── Onglet Analyse IA ─────────────────────────────────────────────────────

  Widget _buildAiTab() {
    // Calcul répartition CA
    double caRes = 0, caCmd = 0;
    for (final r in _reservations) {
      caRes += (r['totalAmount'] ?? r['price'] ?? 0) as num;
    }
    for (final c in _commandes) {
      caCmd += (c['total'] ?? 0) as num;
    }

    // Statuts réservations
    final statusCounts = <String, int>{};
    for (final r in _reservations) {
      final s = r['status'] ?? 'pending';
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }

    // Recommandations personnalisées
    final recommendations = _generateRecommendations();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segment client
          _buildCard(
            title: 'Profil client',
            icon: Icons.psychology_rounded,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniKpi('Segment', _clientSegment, Colors.purple),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniKpi('Fidélité',
                          '$_loyaltyScore / 100', Colors.green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniKpi('Avis',
                          _avgRating > 0
                              ? '${_avgRating.toStringAsFixed(1)} ⭐'
                              : '—',
                          Colors.amber),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Barre fidélité
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Score de fidélité',
                            style: TextStyle(fontSize: 13, color: _dark)),
                        Text('$_loyaltyScore%',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _loyaltyScore / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_primary),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Répartition CA
          _buildCard(
            title: 'Répartition du chiffre d\'affaires',
            icon: Icons.pie_chart_rounded,
            child: Column(
              children: [
                _buildCaBar('Hébergement', caRes, _totalCA, _primary),
                const SizedBox(height: 10),
                _buildCaBar('Restauration', caCmd, _totalCA, Colors.orange),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(_totalCA)} FCFA',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _primary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Recommandations
          _buildCard(
            title: '💡 Services recommandés',
            icon: Icons.lightbulb_rounded,
            child: Column(
              children: recommendations
                  .map((rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5, right: 10),
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                rec,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateRecommendations() {
    final recs = <String>[];

    if (_preferredRoomType != '—') {
      recs.add('Proposer des offres sur "$_preferredRoomType" (chambre favorite)');
    }
    if (_preferredFood != '—') {
      recs.add('Mettre en avant "$_preferredFood" dans les prochaines commandes');
    }
    if (_reservations.length >= 3) {
      recs.add('Éligible à une carte de fidélité ou tarif préférentiel');
    }
    if (_totalCA > 200000) {
      recs.add('Client premium : offrir un upgrade de chambre lors du prochain séjour');
    }
    if (_commandes.length >= 5) {
      recs.add('Gros consommateur restaurant : proposer un forfait demi-pension');
    }
    if (_avgRating >= 4) {
      recs.add('Client satisfait : solliciter un témoignage ou avis public');
    }
    if (_avgRating > 0 && _avgRating < 3) {
      recs.add('⚠️ Note faible : contacter le client pour améliorer l\'expérience');
    }
    if (_alerts.isNotEmpty) {
      recs.add('${_alerts.length} alerte(s) signalée(s) → vérifier les problèmes récurrents');
    }
    if (recs.isEmpty) {
      recs.add('Pas encore assez de données pour générer des recommandations');
    }
    return recs;
  }

  // ── Widgets helper ────────────────────────────────────────────────────────

  Widget _buildKpi(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _dark)),
        ],
      ),
    );
  }

  Widget _buildCaBar(
      String label, double value, double total, Color color) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(
              '${NumberFormat('#,###', 'fr_FR').format(value)} FCFA  '
              '(${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────

  String _formatTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(ts.toDate());
    }
    if (ts is String) return ts;
    return '—';
  }

  Color _reservationStatusColor(String s) {
    switch (s) {
      case 'confirmed': return Colors.blue;
      case 'checked-in': return Colors.green;
      case 'checked-out': return Colors.purple;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _reservationStatusText(String s) {
    switch (s) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'checked-in': return 'Check-in';
      case 'checked-out': return 'Check-out';
      case 'cancelled': return 'Annulée';
      default: return s;
    }
  }

  Color _commandeStatusColor(String s) {
    switch (s) {
      case 'en_attente': return Colors.orange;
      case 'en_cours': return Colors.blue;
      case 'terminee': return Colors.green;
      case 'annulee': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _commandeStatusText(String s) {
    switch (s) {
      case 'en_attente': return 'En attente';
      case 'en_cours': return 'En préparation';
      case 'terminee': return 'Livrée';
      case 'annulee': return 'Annulée';
      default: return s;
    }
  }
}