// ============================================================
// analyses_ia_page.dart
// Page d'analyses IA basée sur les vraies données Firestore.
// Calcule des indicateurs réels + recommandations intelligentes.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalysesIAPage extends StatefulWidget {
  const AnalysesIAPage({Key? key}) : super(key: key);

  @override
  State<AnalysesIAPage> createState() => _AnalysesIAPageState();
}

class _AnalysesIAPageState extends State<AnalysesIAPage> {
  // ── Constantes de couleurs ───────────────────────────────────────────────
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // ── État des analyses ────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;

  // Métriques calculées depuis Firestore
  int _totalReservations = 0;
  int _activeReservations = 0;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  int _totalClients = 0;
  int _totalAlerts = 0;
  int _unresolvedAlerts = 0;
  double _averageRating = 0.0;
  int _totalReviews = 0;
  int _weeklyRevenue = 0;
  Map<String, int> _roomTypeCount = {};
  Map<String, int> _alertTypeCount = {};
  double _occupancyRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  // ── Chargement des données Firestore ─────────────────────────────────────

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      // Chargement parallèle pour performance
      final results = await Future.wait([
        firestore.collection('reservations').get(),
        firestore.collection('orders').get(),
        firestore.collection('users').where('role', isEqualTo: 'client').get(),
        firestore.collection('alerts').get(),
        firestore.collection('reviews').get(),
        firestore
            .collection('reservations')
            .where('dateCreation',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
            .get(),
      ]);

      final reservations = results[0].docs;
      final orders = results[1].docs;
      final clients = results[2].docs;
      final alerts = results[3].docs;
      final reviews = results[4].docs;
      final weeklyReservations = results[5].docs;

      // ── Calcul des métriques ─────────────────────────────────────────────

      // Réservations actives
      final active = reservations
          .where((d) => ['confirmée', 'checkin']
              .contains((d.data() as Map)['statut']))
          .length;

      // Commandes en attente
      final pendingOrds = orders
          .where((d) => (d.data() as Map)['statut'] == 'en_attente')
          .length;

      // Alertes non résolues
      final unresolved = alerts
          .where((d) => (d.data() as Map)['status'] != 'resolved')
          .length;

      // Note moyenne des avis
      double totalRating = 0.0;
      for (final r in reviews) {
        final data = r.data() as Map<String, dynamic>;
        totalRating += ((data['rating'] ?? 0) as num).toDouble();
      }
      final avgRating =
          reviews.isNotEmpty ? totalRating / reviews.length : 0.0;

      // Revenu hebdomadaire
      int weekRev = 0;
      for (final r in weeklyReservations) {
        final data = r.data() as Map<String, dynamic>;
        if (['confirmée', 'checkin', 'checkout']
            .contains(data['statut'])) {
          weekRev += ((data['prixTotal'] ?? 0) as num).toInt();
        }
      }

      // Répartition par type de chambre
      final roomTypes = <String, int>{};
      for (final r in reservations) {
        final data = r.data() as Map<String, dynamic>;
        final type = data['chambre']?.toString() ?? 'Autre';
        roomTypes[type] = (roomTypes[type] ?? 0) + 1;
      }

      // Répartition par type d'alerte
      final alertTypes = <String, int>{};
      for (final a in alerts) {
        final data = a.data() as Map<String, dynamic>;
        final type = data['alertType']?.toString() ?? 'autre';
        alertTypes[type] = (alertTypes[type] ?? 0) + 1;
      }

      // Taux d'occupation estimé (réservations actives / 20 chambres supposées)
      const totalRooms = 20;
      final occupancy = active / totalRooms * 100;

      setState(() {
        _totalReservations = reservations.length;
        _activeReservations = active;
        _totalOrders = orders.length;
        _pendingOrders = pendingOrds;
        _totalClients = clients.length;
        _totalAlerts = alerts.length;
        _unresolvedAlerts = unresolved;
        _averageRating = avgRating;
        _totalReviews = reviews.length;
        _weeklyRevenue = weekRev;
        _roomTypeCount = roomTypes;
        _alertTypeCount = alertTypes;
        _occupancyRate = occupancy.clamp(0, 100);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  color: _primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWeb ? 24 : 16),
                    child: isWeb
                        ? _buildWebContent()
                        : _buildMobileContent(),
                  ),
                ),
    );
  }

  Widget _buildWebContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
        const SizedBox(height: 24),
        // KPIs en grille 4 colonnes
        _buildKpiGrid(columns: 4),
        const SizedBox(height: 24),
        // Ligne: taux occupation + revenus
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildOccupancyCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildRevenueCard()),
          ],
        ),
        const SizedBox(height: 24),
        // Ligne: types de chambres + recommandations IA
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRoomTypeBreakdown()),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildAIRecommendations()),
          ],
        ),
        const SizedBox(height: 24),
        _buildAlertsAnalysis(),
      ],
    );
  }

  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
        const SizedBox(height: 16),
        _buildKpiGrid(columns: 2),
        const SizedBox(height: 16),
        _buildOccupancyCard(),
        const SizedBox(height: 16),
        _buildRevenueCard(),
        const SizedBox(height: 16),
        _buildRoomTypeBreakdown(),
        const SizedBox(height: 16),
        _buildAIRecommendations(),
        const SizedBox(height: 16),
        _buildAlertsAnalysis(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── En-tête ───────────────────────────────────────────────────────────────

  Widget _buildPageHeader() {
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
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analyses & IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mis à jour le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }

  // ── KPIs ─────────────────────────────────────────────────────────────────

  Widget _buildKpiGrid({required int columns}) {
    final kpis = [
      _KpiData('Réservations', _totalReservations, Icons.hotel_rounded,
          const Color(0xFF2A9D8F), 'Total'),
      _KpiData('Actives', _activeReservations, Icons.event_available_rounded,
          _primary, 'En cours'),
      _KpiData('Commandes', _totalOrders, Icons.restaurant_rounded,
          const Color(0xFF264653), '$_pendingOrders en attente'),
      _KpiData('Clients', _totalClients, Icons.people_rounded,
          const Color(0xFF457B9D), 'Inscrits'),
      _KpiData('Note moyenne', (_averageRating * 10).round() ~/ 10,
          Icons.star_rounded, const Color(0xFFF4A261),
          '${_totalReviews} avis'),
      _KpiData('Alertes', _unresolvedAlerts, Icons.warning_rounded,
          Colors.redAccent, 'Non résolues'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: columns == 4 ? 1.5 : 1.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: kpis.length,
      itemBuilder: (_, i) => _KpiCard(data: kpis[i]),
    );
  }

  // ── Taux d'occupation ────────────────────────────────────────────────────

  Widget _buildOccupancyCard() {
    final pct = _occupancyRate;
    final color = pct >= 70
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : Colors.red;

    return _AnalysisCard(
      title: "Taux d'occupation",
      icon: Icons.hotel_rounded,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    '$_activeReservations / 20',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pct >= 70
                ? '✅ Excellent taux d\'occupation'
                : pct >= 40
                    ? '⚠️ Taux d\'occupation moyen'
                    : '❌ Taux d\'occupation faible',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenus ───────────────────────────────────────────────────────────────

  Widget _buildRevenueCard() {
    return _AnalysisCard(
      title: 'Revenus de la semaine',
      icon: Icons.trending_up_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '${NumberFormat('#,###', 'fr_FR').format(_weeklyRevenue)} FCFA',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Basé sur ${_totalReservations} réservation(s) confirmées cette semaine',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded,
                    color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Revenu moyen par réservation : '
                    '${_totalReservations > 0 ? NumberFormat('#,###', 'fr_FR').format(_weeklyRevenue ~/ _totalReservations) : 0} FCFA',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Répartition par type de chambre ──────────────────────────────────────

  Widget _buildRoomTypeBreakdown() {
    if (_roomTypeCount.isEmpty) {
      return _AnalysisCard(
        title: 'Types de chambres',
        icon: Icons.meeting_room_rounded,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucune donnée disponible'),
        ),
      );
    }

    final total = _roomTypeCount.values.fold(0, (a, b) => a + b);
    final colors = [
      _primary,
      const Color(0xFF2A9D8F),
      const Color(0xFFE76F51),
      const Color(0xFF264653),
      const Color(0xFFF4A261),
    ];

    return _AnalysisCard(
      title: 'Types de chambres',
      icon: Icons.meeting_room_rounded,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._roomTypeCount.entries.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final type = entry.value.key;
            final count = entry.value.value;
            final pct = total > 0 ? count / total : 0.0;
            final color = colors[i % colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(type,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        '$count (${(pct * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Recommandations IA ────────────────────────────────────────────────────

  Widget _buildAIRecommendations() {
    // Génère des recommandations basées sur les métriques réelles
    final recommendations = _generateRecommendations();

    return _AnalysisCard(
      title: 'Recommandations IA',
      icon: Icons.auto_awesome_rounded,
      headerColor: _primary,
      child: Column(
        children: recommendations
            .map((r) => _AIRecommendationItem(rec: r))
            .toList(),
      ),
    );
  }

  // Génère des recommandations intelligentes selon les données
  List<_AIRecommendation> _generateRecommendations() {
    final recs = <_AIRecommendation>[];

    // Taux d'occupation
    if (_occupancyRate < 40) {
      recs.add(_AIRecommendation(
        type: 'warning',
        title: 'Faible occupation',
        description:
            'Taux d\'occupation à ${_occupancyRate.toStringAsFixed(0)}%. Envisagez des promotions ou offres spéciales pour attirer plus de clients.',
        icon: Icons.hotel_rounded,
      ));
    } else if (_occupancyRate >= 80) {
      recs.add(_AIRecommendation(
        type: 'success',
        title: 'Excellente occupation',
        description:
            'Taux à ${_occupancyRate.toStringAsFixed(0)}%. Vous pouvez envisager d\'augmenter légèrement les tarifs.',
        icon: Icons.trending_up_rounded,
      ));
    }

    // Alertes non résolues
    if (_unresolvedAlerts > 3) {
      recs.add(_AIRecommendation(
        type: 'danger',
        title: 'Alertes en suspens',
        description:
            '$_unresolvedAlerts alertes non résolues. Priorité aux urgences pour maintenir la satisfaction client.',
        icon: Icons.warning_rounded,
      ));
    }

    // Note moyenne
    if (_averageRating > 0 && _averageRating < 3.5) {
      recs.add(_AIRecommendation(
        type: 'warning',
        title: 'Note client à améliorer',
        description:
            'Note moyenne de ${_averageRating.toStringAsFixed(1)}/5. Analysez les retours clients et améliorez les points faibles.',
        icon: Icons.star_rounded,
      ));
    } else if (_averageRating >= 4.5) {
      recs.add(_AIRecommendation(
        type: 'success',
        title: 'Excellente satisfaction',
        description:
            'Note moyenne de ${_averageRating.toStringAsFixed(1)}/5. Continuez sur cette lancée !',
        icon: Icons.star_rounded,
      ));
    }

    // Commandes en attente
    if (_pendingOrders > 5) {
      recs.add(_AIRecommendation(
        type: 'warning',
        title: 'Commandes en attente',
        description:
            '$_pendingOrders commandes en attente. La cuisine a besoin de renfort.',
        icon: Icons.restaurant_rounded,
      ));
    }

    // Type de chambre le plus populaire
    if (_roomTypeCount.isNotEmpty) {
      final popular = _roomTypeCount.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      recs.add(_AIRecommendation(
        type: 'info',
        title: 'Chambre populaire',
        description:
            'La chambre "${popular.key}" est la plus demandée (${popular.value} réservations). Assurez-vous qu\'elle est toujours en parfait état.',
        icon: Icons.meeting_room_rounded,
      ));
    }

    // Si pas de recommandations
    if (recs.isEmpty) {
      recs.add(_AIRecommendation(
        type: 'info',
        title: 'Tout va bien',
        description:
            'Aucune anomalie détectée. Continuez le bon travail !',
        icon: Icons.check_circle_rounded,
      ));
    }

    return recs;
  }

  // ── Analyse des alertes ───────────────────────────────────────────────────

  Widget _buildAlertsAnalysis() {
    return _AnalysisCard(
      title: 'Analyse des alertes par type',
      icon: Icons.analytics_rounded,
      child: _alertTypeCount.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune alerte enregistrée'),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _alertTypeCount.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded,
                          size: 14, color: _primary),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Widgets utilitaires ───────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
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
    );
  }
}

// ── Carte d'analyse réutilisable ─────────────────────────────────────────────

class _AnalysisCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? headerColor;

  const _AnalysisCard({
    required this.title,
    required this.icon,
    required this.child,
    this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: headerColor ?? const Color(0xFF9B4610)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: headerColor ?? const Color(0xFF4A2A10),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────────────────────

class _KpiData {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _KpiData(
      this.title, this.value, this.icon, this.color, this.subtitle);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

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
        border: Border.all(color: data.color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, size: 18, color: data.color),
              ),
              Text(
                '${data.value}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: data.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A2A10),
            ),
          ),
          Text(
            data.subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ── Recommandation IA ─────────────────────────────────────────────────────────

class _AIRecommendation {
  final String type; // success | warning | danger | info
  final String title;
  final String description;
  final IconData icon;

  const _AIRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _AIRecommendationItem extends StatelessWidget {
  final _AIRecommendation rec;
  const _AIRecommendationItem({required this.rec});

  (Color, Color) get _colors {
    switch (rec.type) {
      case 'success':
        return (Colors.green, Colors.green.shade50);
      case 'warning':
        return (Colors.orange, Colors.orange.shade50);
      case 'danger':
        return (Colors.red, Colors.red.shade50);
      default:
        return (const Color(0xFF457B9D), const Color(0xFFEBF5FB));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (borderColor, bgColor) = _colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(rec.icon, size: 20, color: borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: borderColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rec.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: borderColor.withOpacity(0.8),
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