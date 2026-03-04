// ============================================================
// client_profile_admin_page.dart
//
// Page d'analyse comportementale d'un client pour l'admin.
// Charge toutes les données Firestore du client (réservations,
// commandes, alertes, avis) et génère des suggestions IA
// personnalisées pour offrir un service sur mesure.
//
// Usage :
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => ClientProfileAdminPage(
//       clientId: 'uid_du_client',
//       clientName: 'Jean Dupont',
//     ),
//   ));
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClientProfileAdminPage extends StatefulWidget {
  final String clientId;
  final String clientName;

  const ClientProfileAdminPage({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  State<ClientProfileAdminPage> createState() =>
      _ClientProfileAdminPageState();
}

class _ClientProfileAdminPageState
    extends State<ClientProfileAdminPage>
    with SingleTickerProviderStateMixin {
  // ── Couleurs ─────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // ── État ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;

  // ── Données client ────────────────────────────────────────────────────────
  Map<String, dynamic> _clientData = {};

  // Réservations
  List<Map<String, dynamic>> _reservations = [];
  int _totalNights = 0;
  Map<String, int> _roomTypeCount = {};      // ex: {Premium: 3, Standard: 1}
  String? _favoriteRoomType;
  double _avgStayDuration = 0;

  // Commandes restaurant
  List<Map<String, dynamic>> _orders = [];
  int _totalOrdersAmount = 0;
  Map<String, int> _dishCount = {};          // ex: {Poulet DG: 4, Ndolé: 2}
  List<String> _favoriteDishes = [];

  // Alertes
  List<Map<String, dynamic>> _alerts = [];
  Map<String, int> _alertTypeCount = {};

  // Avis
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;

  // Habitudes calculées
  String _preferredCheckinTime = 'Indéfini';  // Matin / Après-midi / Soir
  String _preferredStayLength = 'Indéfini';   // Court / Moyen / Long
  String _spendingProfile = 'Indéfini';       // Budget / Standard / Premium
  bool _isLoyalClient = false;                // Plus de 3 séjours
  bool _isHighValueClient = false;            // Dépenses > seuil

  // Suggestions IA
  List<_AISuggestion> _suggestions = [];

  // Tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CHARGEMENT DES DONNÉES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fs = FirebaseFirestore.instance;

      // Chargement parallèle de toutes les collections
      final results = await Future.wait([
        fs.collection('users').doc(widget.clientId).get(),
        fs.collection('reservations')
            .where('userId', isEqualTo: widget.clientId)
            .orderBy('dateCreation', descending: true)
            .get(),
        fs.collection('orders')
            .where('userId', isEqualTo: widget.clientId)
            .orderBy('createdAt', descending: true)
            .get(),
        fs.collection('alerts')
            .where('userId', isEqualTo: widget.clientId)
            .orderBy('timestamp', descending: true)
            .get(),
        fs.collection('reviews')
            .where('userId', isEqualTo: widget.clientId)
            .orderBy('createdAt', descending: true)
            .get(),
      ]);

      // ── Profil client ──────────────────────────────────────────────────
      final userDoc = results[0] as DocumentSnapshot;
      if (userDoc.exists) {
        _clientData = userDoc.data() as Map<String, dynamic>;
      }

      // ── Réservations ───────────────────────────────────────────────────
      final reservDocs = (results[1] as QuerySnapshot).docs;
      _reservations = reservDocs.map((d) {
        return {'id': d.id, ...(d.data() as Map<String, dynamic>)};
      }).toList();

      _analyzeReservations();

      // ── Commandes restaurant ───────────────────────────────────────────
      final orderDocs = (results[2] as QuerySnapshot).docs;
      _orders = orderDocs.map((d) {
        return {'id': d.id, ...(d.data() as Map<String, dynamic>)};
      }).toList();

      _analyzeOrders();

      // ── Alertes ────────────────────────────────────────────────────────
      final alertDocs = (results[3] as QuerySnapshot).docs;
      _alerts = alertDocs.map((d) {
        return {'id': d.id, ...(d.data() as Map<String, dynamic>)};
      }).toList();

      _analyzeAlerts();

      // ── Avis ───────────────────────────────────────────────────────────
      final reviewDocs = (results[4] as QuerySnapshot).docs;
      _reviews = reviewDocs.map((d) {
        return {'id': d.id, ...(d.data() as Map<String, dynamic>)};
      }).toList();

      _analyzeReviews();

      // ── Génère les suggestions IA ──────────────────────────────────────
      _generateAISuggestions();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement : $e';
        _isLoading = false;
      });
    }
  }

  // ── Analyse des réservations ─────────────────────────────────────────────

  void _analyzeReservations() {
    if (_reservations.isEmpty) return;

    int totalNights = 0;
    final roomTypes = <String, int>{};
    final checkinHours = <int>[];

    for (final r in _reservations) {
      // Comptage des types de chambres
      final type = r['chambre']?.toString() ?? 'Autre';
      roomTypes[type] = (roomTypes[type] ?? 0) + 1;

      // Calcul de la durée du séjour
      final arrival = _tsToDate(r['dateArrivee']);
      final departure = _tsToDate(r['dateDepart']);
      if (arrival != null && departure != null) {
        final nights = departure.difference(arrival).inDays;
        if (nights > 0) totalNights += nights;
      }

      // Heure de check-in habituelle
      final createdAt = _tsToDate(r['dateCreation']);
      if (createdAt != null) checkinHours.add(createdAt.hour);
    }

    _totalNights = totalNights;
    _roomTypeCount = roomTypes;

    // Chambre préférée = la plus réservée
    if (roomTypes.isNotEmpty) {
      _favoriteRoomType = roomTypes.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Durée moyenne de séjour
    _avgStayDuration = _reservations.isNotEmpty
        ? totalNights / _reservations.length
        : 0;

    // Profil de durée
    if (_avgStayDuration <= 1.5) {
      _preferredStayLength = 'Court séjour (1 nuit)';
    } else if (_avgStayDuration <= 3) {
      _preferredStayLength = 'Séjour moyen (2–3 nuits)';
    } else {
      _preferredStayLength = 'Long séjour (4+ nuits)';
    }

    // Heure de check-in préférée
    if (checkinHours.isNotEmpty) {
      final avgHour =
          checkinHours.reduce((a, b) => a + b) ~/ checkinHours.length;
      if (avgHour < 12) {
        _preferredCheckinTime = 'Matin (avant 12h)';
      } else if (avgHour < 17) {
        _preferredCheckinTime = 'Après-midi (12h–17h)';
      } else {
        _preferredCheckinTime = 'Soir (après 17h)';
      }
    }

    // Client fidèle ?
    _isLoyalClient = _reservations.length >= 3;
  }

  // ── Analyse des commandes ────────────────────────────────────────────────

  void _analyzeOrders() {
    if (_orders.isEmpty) return;

    int totalAmount = 0;
    final dishes = <String, int>{};

    for (final o in _orders) {
      totalAmount += ((o['total'] ?? o['montant'] ?? 0) as num).toInt();

      // Comptage des plats commandés
      final items = o['items'] as List? ?? [];
      for (final item in items) {
        if (item is Map) {
          final name = item['name']?.toString() ??
              item['nom']?.toString() ??
              'Plat inconnu';
          dishes[name] = (dishes[name] ?? 0) + 1;
        }
      }

      // Si pas de liste d'items, utilise le nom de la commande
      if (items.isEmpty) {
        final name = o['plat']?.toString() ??
            o['description']?.toString() ??
            'Commande';
        if (name != 'Commande') {
          dishes[name] = (dishes[name] ?? 0) + 1;
        }
      }
    }

    _totalOrdersAmount = totalAmount;
    _dishCount = dishes;

    // Top 3 plats favoris
    final sortedDishes = dishes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _favoriteDishes =
        sortedDishes.take(3).map((e) => e.key).toList();
  }

  // ── Analyse des alertes ──────────────────────────────────────────────────

  void _analyzeAlerts() {
    final types = <String, int>{};
    for (final a in _alerts) {
      final type = a['alertType']?.toString() ?? 'autre';
      types[type] = (types[type] ?? 0) + 1;
    }
    _alertTypeCount = types;
  }

  // ── Analyse des avis ─────────────────────────────────────────────────────

  void _analyzeReviews() {
    if (_reviews.isEmpty) return;
    double total = 0;
    for (final r in _reviews) {
      total += ((r['rating'] ?? 0) as num).toDouble();
    }
    _avgRating = total / _reviews.length;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GÉNÉRATION DES SUGGESTIONS IA
  // ══════════════════════════════════════════════════════════════════════════

  void _generateAISuggestions() {
    final suggestions = <_AISuggestion>[];

    // ── Profil de dépenses ──────────────────────────────────────────────
    final totalSpending = _totalOrdersAmount;
    if (totalSpending > 200000) {
      _isHighValueClient = true;
      _spendingProfile = 'Client haut de gamme';
    } else if (totalSpending > 80000) {
      _spendingProfile = 'Client standard';
    } else {
      _spendingProfile = 'Client budget';
    }

    // ── Suggestion : chambre préférée ───────────────────────────────────
    if (_favoriteRoomType != null) {
      suggestions.add(_AISuggestion(
        icon: Icons.hotel_rounded,
        color: _primary,
        category: 'Hébergement',
        title: 'Proposer une surclasse $_favoriteRoomType',
        description:
            'Ce client a réservé la chambre $_favoriteRoomType '
            '${_roomTypeCount[_favoriteRoomType]!} fois. '
            'Proposez-lui un accès prioritaire ou une remise de fidélité '
            'sur ce type de chambre.',
        priority: _isLoyalClient ? 'haute' : 'normale',
      ));
    }

    // ── Suggestion : client fidèle ──────────────────────────────────────
    if (_isLoyalClient) {
      suggestions.add(_AISuggestion(
        icon: Icons.card_giftcard_rounded,
        color: const Color(0xFFF4A261),
        category: 'Fidélité',
        title: 'Programme de fidélité',
        description:
            'Avec ${_reservations.length} séjours, ce client mérite '
            'un statut fidèle. Proposez-lui une nuit offerte, un '
            'surclassement automatique ou un accès early check-in.',
        priority: 'haute',
      ));
    }

    // ── Suggestion : plats favoris ──────────────────────────────────────
    if (_favoriteDishes.isNotEmpty) {
      suggestions.add(_AISuggestion(
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF2A9D8F),
        category: 'Restaurant',
        title: 'Menu personnalisé',
        description:
            'Ce client apprécie particulièrement : '
            '${_favoriteDishes.join(', ')}. '
            'Informez la cuisine à l\'avance pour préparer ses plats '
            'favoris dès son arrivée.',
        priority: 'normale',
      ));
    }

    // ── Suggestion : heure d'arrivée ────────────────────────────────────
    if (_preferredCheckinTime.contains('Soir')) {
      suggestions.add(_AISuggestion(
        icon: Icons.access_time_rounded,
        color: const Color(0xFF264653),
        category: 'Accueil',
        title: 'Préparer un accueil tardif',
        description:
            'Ce client arrive habituellement en soirée. '
            'Assurez-vous que la réception est disponible, '
            'proposez un service de restauration léger à l\'arrivée.',
        priority: 'normale',
      ));
    }

    // ── Suggestion : alertes fréquentes ────────────────────────────────
    if (_alerts.length >= 2) {
      final topAlertType = _alertTypeCount.isNotEmpty
          ? _alertTypeCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : null;
      if (topAlertType != null) {
        suggestions.add(_AISuggestion(
          icon: Icons.warning_rounded,
          color: Colors.orange,
          category: 'Qualité de service',
          title: 'Attention aux problèmes récurrents',
          description:
              'Ce client a signalé ${_alerts.length} alertes '
              '(surtout : $topAlertType). '
              'Vérifiez proactivement sa chambre avant son arrivée '
              'pour éviter tout désagrément.',
          priority: 'haute',
        ));
      }
    }

    // ── Suggestion : note basse ─────────────────────────────────────────
    if (_avgRating > 0 && _avgRating < 3.5) {
      suggestions.add(_AISuggestion(
        icon: Icons.sentiment_dissatisfied_rounded,
        color: Colors.red,
        category: 'Satisfaction',
        title: 'Client insatisfait — action requise',
        description:
            'Note moyenne de ${_avgRating.toStringAsFixed(1)}/5. '
            'Ce client a exprimé de l\'insatisfaction. Contactez-le '
            'personnellement avant son prochain séjour pour comprendre '
            'ses attentes.',
        priority: 'haute',
      ));
    }

    // ── Suggestion : client haut de gamme ──────────────────────────────
    if (_isHighValueClient) {
      suggestions.add(_AISuggestion(
        icon: Icons.star_rounded,
        color: const Color(0xFFE9C46A),
        category: 'Service VIP',
        title: 'Traitement VIP recommandé',
        description:
            'Ce client génère un revenu significatif '
            '(${NumberFormat('#,###', 'fr_FR').format(_totalOrdersAmount)} FCFA '
            'en commandes). '
            'Proposez-lui une bouteille de bienvenue, un surclassement '
            'ou un concierge dédié.',
        priority: 'haute',
      ));
    }

    // ── Suggestion : long séjour ────────────────────────────────────────
    if (_avgStayDuration >= 4) {
      suggestions.add(_AISuggestion(
        icon: Icons.bedtime_rounded,
        color: const Color(0xFF457B9D),
        category: 'Confort',
        title: 'Services long séjour',
        description:
            'Durée moyenne de ${_avgStayDuration.toStringAsFixed(1)} nuits. '
            'Proposez un service de blanchisserie, une remise hebdomadaire '
            'ou un minibar réapprovisionné.',
        priority: 'normale',
      ));
    }

    // Si aucune suggestion générée, message par défaut
    if (suggestions.isEmpty) {
      suggestions.add(_AISuggestion(
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        category: 'Général',
        title: 'Profil en cours de construction',
        description:
            'Pas encore assez de données pour générer des '
            'recommandations personnalisées. Plus le client '
            'utilisera l\'application, plus les suggestions seront pertinentes.',
        priority: 'normale',
      ));
    }

    // Trie : priorité haute en premier
    suggestions.sort((a, b) {
      if (a.priority == 'haute' && b.priority != 'haute') return -1;
      if (b.priority == 'haute' && a.priority != 'haute') return 1;
      return 0;
    });

    _suggestions = suggestions;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      body: _isLoading
          ? _buildLoader()
          : _error != null
              ? _buildError()
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [
                    _buildSliverHeader(isWeb),
                  ],
                  body: _buildTabBody(),
                ),
    );
  }

  // ── SliverAppBar avec profil client ──────────────────────────────────────

  Widget _buildSliverHeader(bool isWeb) {
    final name = _clientData['name'] ??
        _clientData['email']?.toString().split('@').first ??
        widget.clientName;
    final email = _clientData['email'] ?? '';
    final phone = _clientData['phone'] ?? '';
    final joinDate = _tsToDate(_clientData['createdAt']);

    return SliverAppBar(
      expandedHeight: isWeb ? 260 : 230,
      pinned: true,
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3A1F0A), _primary, Color(0xFFD4722A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  isWeb ? 32 : 20, 60, isWeb ? 32 : 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: isWeb ? 34 : 28,
                        backgroundColor:
                            Colors.white.withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: isWeb ? 28 : 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: isWeb ? 22 : 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Badge fidèle / VIP
                                if (_isLoyalClient)
                                  _BadgeChip(
                                    label: _isHighValueClient
                                        ? '⭐ VIP'
                                        : '🏅 Fidèle',
                                    color: _isHighValueClient
                                        ? const Color(0xFFE9C46A)
                                        : const Color(0xFF2A9D8F),
                                  ),
                              ],
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      Colors.white.withOpacity(0.7),
                                ),
                              ),
                            if (phone.isNotEmpty)
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withOpacity(0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats rapides horizontales
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickStat(
                            '${_reservations.length}',
                            'séjours'),
                        _QuickStat(
                            '$_totalNights', 'nuits'),
                        _QuickStat(
                            '${_orders.length}', 'commandes'),
                        _QuickStat(
                            _avgRating > 0
                                ? _avgRating.toStringAsFixed(1)
                                : '—',
                            'note moy.'),
                        if (joinDate != null)
                          _QuickStat(
                            DateFormat('MM/yyyy').format(joinDate),
                            'inscrit',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        isScrollable: true,
        tabs: const [
          Tab(text: '🤖 IA & Suggestions'),
          Tab(text: '🏨 Réservations'),
          Tab(text: '🍽 Commandes'),
          Tab(text: '⚠️ Alertes'),
          Tab(text: '⭐ Avis'),
        ],
      ),
    );
  }

  // ── Corps des onglets ─────────────────────────────────────────────────────

  Widget _buildTabBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildIATab(),
        _buildReservationsTab(),
        _buildOrdersTab(),
        _buildAlertsTab(),
        _buildReviewsTab(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ONGLET 1 : IA & SUGGESTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIATab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Profil comportemental synthétique ──────────────────────────
        _SectionTitle('Profil comportemental'),
        const SizedBox(height: 12),
        _buildBehaviorGrid(),
        const SizedBox(height: 24),

        // ── Répartition chambres ───────────────────────────────────────
        if (_roomTypeCount.isNotEmpty) ...[
          _SectionTitle('Types de chambres préférées'),
          const SizedBox(height: 12),
          _buildRoomTypeChart(),
          const SizedBox(height: 24),
        ],

        // ── Plats favoris ──────────────────────────────────────────────
        if (_favoriteDishes.isNotEmpty) ...[
          _SectionTitle('Plats favoris'),
          const SizedBox(height: 12),
          _buildFavoriteDishes(),
          const SizedBox(height: 24),
        ],

        // ── Suggestions IA ─────────────────────────────────────────────
        _SectionTitle('Recommandations IA personnalisées'),
        const SizedBox(height: 4),
        Text(
          '${_suggestions.length} recommandation${_suggestions.length > 1 ? 's' : ''} générée${_suggestions.length > 1 ? 's' : ''} automatiquement',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 12),
        ..._suggestions.map((s) => _AISuggestionCard(suggestion: s)),
        const SizedBox(height: 24),
      ],
    );
  }

  // Grille des indicateurs comportementaux
  Widget _buildBehaviorGrid() {
    final items = [
      (Icons.hotel_rounded, 'Chambre favorite', _favoriteRoomType ?? '—', _primary),
      (Icons.nights_stay_rounded, 'Durée moy.', '${_avgStayDuration.toStringAsFixed(1)} nuits', const Color(0xFF2A9D8F)),
      (Icons.access_time_rounded, 'Check-in', _preferredCheckinTime, const Color(0xFF264653)),
      (Icons.luggage_rounded, 'Type séjour', _preferredStayLength, const Color(0xFFE76F51)),
      (Icons.payments_rounded, 'Profil dépenses', _spendingProfile, const Color(0xFF457B9D)),
      (Icons.warning_rounded, 'Alertes signalées', '${_alerts.length}', Colors.orange),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.$4.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(item.$1, size: 16, color: item.$4),
                  const SizedBox(width: 6),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.$3,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: item.$4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // Barres de progression pour les types de chambres
  Widget _buildRoomTypeChart() {
    final total = _roomTypeCount.values.fold(0, (a, b) => a + b);
    final colors = [_primary, const Color(0xFF2A9D8F), const Color(0xFFE76F51), const Color(0xFF264653)];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _roomTypeCount.entries.toList().asMap().entries.map((e) {
          final i = e.key;
          final type = e.value.key;
          final count = e.value.value;
          final pct = total > 0 ? count / total : 0.0;
          final color = colors[i % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(type,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(
                      '$count fois (${(pct * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Chips des plats favoris
  Widget _buildFavoriteDishes() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _dishCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(6).toList().map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2A9D8F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF2A9D8F).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant_rounded,
                      size: 13, color: Color(0xFF2A9D8F)),
                  const SizedBox(width: 5),
                  Text(
                    '${e.key} (×${e.value})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2A9D8F),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ONGLET 2 : RÉSERVATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReservationsTab() {
    if (_reservations.isEmpty) {
      return _buildEmptyState(
          'Aucune réservation', Icons.hotel_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reservations.length,
      itemBuilder: (_, i) {
        final r = _reservations[i];
        final chambre = r['chambre'] ?? 'Non défini';
        final statut = r['statut'] ?? 'inconnu';
        final arrival = _tsToDate(r['dateArrivee']);
        final departure = _tsToDate(r['dateDepart']);
        final price = r['prixTotal'] ?? 0;
        final nights = (arrival != null && departure != null)
            ? departure.difference(arrival).inDays
            : 0;

        final statusColor = _statusColor(statut);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.hotel_rounded,
                          size: 18, color: _primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chambre $chambre',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _dark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statut,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text(
                      arrival != null
                          ? DateFormat('dd/MM/yyyy').format(arrival)
                          : '—',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700]),
                    ),
                    Text(' → ',
                        style: TextStyle(color: Colors.grey[400])),
                    Text(
                      departure != null
                          ? DateFormat('dd/MM/yyyy').format(departure)
                          : '—',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700]),
                    ),
                    const Spacer(),
                    Text(
                      '$nights nuit${nights > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.attach_money_rounded,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(price)} FCFA',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primary,
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
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ONGLET 3 : COMMANDES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return _buildEmptyState(
          'Aucune commande', Icons.restaurant_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length + 1, // +1 pour le résumé en tête
      itemBuilder: (_, i) {
        // En-tête récapitulatif
        if (i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A9D8F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat('${_orders.length}', 'commandes'),
                Container(
                    width: 1, height: 30, color: Colors.grey[300]),
                _MiniStat(
                  '${NumberFormat('#,###', 'fr_FR').format(_totalOrdersAmount)} FCFA',
                  'total dépensé',
                ),
              ],
            ),
          );
        }

        final o = _orders[i - 1];
        final statut = o['statut'] ?? o['status'] ?? 'inconnu';
        final ts = _tsToDate(o['createdAt'] ?? o['timestamp']);
        final amount =
            (o['total'] ?? o['montant'] ?? 0) as num;
        final items = o['items'] as List? ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_rounded,
                        size: 18, color: Color(0xFF2A9D8F)),
                    const SizedBox(width: 8),
                    Text(
                      ts != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(ts)
                          : 'Date inconnue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _dark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(amount)} FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF2A9D8F),
                      ),
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: items.take(5).map<Widget>((item) {
                      final name = item is Map
                          ? (item['name'] ??
                              item['nom'] ??
                              'Plat')
                          : item.toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(name.toString(),
                            style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ONGLET 4 : ALERTES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return _buildEmptyState(
          'Aucune alerte signalée', Icons.notifications_none_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (_, i) {
        final a = _alerts[i];
        final type = a['alertTypeLabel'] ?? a['alertType'] ?? 'Autre';
        final msg = a['message'] ?? '';
        final status = a['status'] ?? 'new';
        final ts = _tsToDate(a['timestamp']);
        final statusColor = status == 'resolved'
            ? Colors.green
            : status == 'in_progress'
                ? Colors.orange
                : Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.warning_rounded,
                      size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            type,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _dark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
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
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (msg.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(msg,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700])),
                      ],
                      if (ts != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(ts),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ONGLET 5 : AVIS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return _buildEmptyState(
          'Aucun avis laissé', Icons.star_outline_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length + 1,
      itemBuilder: (_, i) {
        // Résumé en tête
        if (i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  _avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.amber,
                  ),
                ),
                Text(
                  ' / 5   •   ${_reviews.length} avis',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final r = _reviews[i - 1];
        final rating = (r['rating'] ?? 0) as num;
        final comment = r['comment'] ?? r['commentaire'] ?? '';
        final ts = _tsToDate(r['createdAt'] ?? r['timestamp']);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Étoiles
                    ...List.generate(
                      5,
                      (j) => Icon(
                        j < rating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: Colors.amber,
                      ),
                    ),
                    const Spacer(),
                    if (ts != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(ts),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGETS UTILITAIRES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLoader() {
    return const Scaffold(
      backgroundColor: _bgLight,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 16),
            Text('Analyse du profil client…'),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(widget.clientName),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAllData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg,
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // Helpers
  DateTime? _tsToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmée':
        return Colors.green;
      case 'checkin':
        return Colors.blue;
      case 'checkout':
        return Colors.purple;
      case 'annulée':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS SECONDAIRES
// ══════════════════════════════════════════════════════════════════════════════

// Titre de section
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4A2A10),
      ),
    );
  }
}

// Stat rapide dans le header
class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  const _QuickStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// Mini stat dans un widget récapitulatif
class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2A9D8F),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

// Badge client (Fidèle / VIP)
class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// Modèle suggestion IA
class _AISuggestion {
  final IconData icon;
  final Color color;
  final String category;
  final String title;
  final String description;
  final String priority; // 'haute' | 'normale'

  const _AISuggestion({
    required this.icon,
    required this.color,
    required this.category,
    required this.title,
    required this.description,
    required this.priority,
  });
}

// Carte suggestion IA
class _AISuggestionCard extends StatelessWidget {
  final _AISuggestion suggestion;
  const _AISuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: suggestion.priority == 'haute'
              ? suggestion.color.withOpacity(0.4)
              : Colors.grey.shade200,
          width: suggestion.priority == 'haute' ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: suggestion.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(suggestion.icon, size: 20, color: suggestion.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Catégorie
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            suggestion.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        suggestion.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: suggestion.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Badge priorité haute
                    if (suggestion.priority == 'haute')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔴 Priorité haute',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A2A10),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
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