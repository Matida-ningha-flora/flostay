// ============================================================
// availability_page.dart
// Vérification de disponibilité des chambres en temps réel
// via Firestore. Affiche les chambres disponibles selon
// les dates sélectionnées.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AvailabilityPage extends StatefulWidget {
  /// Prix indicatif transmis depuis l'écran précédent
  final int roomPrice;
  /// Date d'arrivée au format 'yyyy-MM-dd'
  final String checkInDate;
  /// Date de départ au format 'yyyy-MM-dd'
  final String checkOutDate;

  const AvailabilityPage({
    super.key,
    required this.roomPrice,
    required this.checkInDate,
    required this.checkOutDate,
  });

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  // ── Couleurs ────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // ── État ────────────────────────────────────────────────────────────────
  bool _isChecking = false;
  List<_RoomAvailability> _results = [];
  bool _hasChecked = false;
  String? _error;

  // Dates sélectionnées (peuvent être modifiées sur cette page)
  late DateTime _checkIn;
  late DateTime _checkOut;

  // ✅ Plus de liste statique - chargée depuis Firestore collection 'chambres'

  @override
  void initState() {
    super.initState();
    // Parse les dates transmises ou utilise aujourd'hui / demain par défaut
    try {
      _checkIn = DateTime.parse(widget.checkInDate);
      _checkOut = DateTime.parse(widget.checkOutDate);
    } catch (_) {
      _checkIn = DateTime.now();
      _checkOut = DateTime.now().add(const Duration(days: 1));
    }
    // Lance la vérification automatiquement
    _checkAvailability();
  }

  // ── Vérification de disponibilité ────────────────────────────────────────

  Future<void> _checkAvailability() async {
    if (_checkOut.isBefore(_checkIn) ||
        _checkOut.isAtSameMomentAs(_checkIn)) {
      setState(() {
        _error = 'La date de départ doit être après la date d\'arrivée.';
        _hasChecked = true;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _error = null;
      _results = [];
    });

    try {
      // ✅ 1. Charger les chambres depuis Firestore (publiées par l'admin)
      final chambresSnap = await FirebaseFirestore.instance
          .collection('chambres')
          .where('disponible', isEqualTo: true)
          .get();

      // ✅ 2. Récupère toutes les réservations actives qui chevauchent la période
      final reservationsSnap = await FirebaseFirestore.instance
          .collection('reservations')
          .where('status', whereIn: ['confirmed', 'checked-in', 'confirmée', 'checkin'])
          .get();

      // ✅ 3. Chambres occupées sur la période demandée (par docId OU par type)
      final occupiedIds = <String>{};
      for (final doc in reservationsSnap.docs) {
        final data = doc.data();
        final arrival = _parseDate(data['checkInDate'] ?? data['dateArrivee']);
        final departure = _parseDate(data['checkOutDate'] ?? data['dateDepart']);
        if (arrival == null || departure == null) continue;
        final overlaps = arrival.isBefore(_checkOut) && departure.isAfter(_checkIn);
        if (overlaps) {
          final chambreId = data['chambreId']?.toString() ?? '';
          final chambreType = data['roomType']?.toString() ?? data['chambre']?.toString() ?? '';
          if (chambreId.isNotEmpty) occupiedIds.add(chambreId);
          if (chambreType.isNotEmpty) occupiedIds.add(chambreType);
        }
      }

      // ✅ 4. Construire les résultats depuis les vraies chambres Firestore
      final nights = _checkOut.difference(_checkIn).inDays;
      final results = <_RoomAvailability>[];

      for (final doc in chambresSnap.docs) {
        final d = doc.data();
        final prix = (d['prix'] ?? 0) as num;
        final isOccupied = occupiedIds.contains(doc.id) ||
            occupiedIds.contains(d['type']?.toString() ?? '');
        results.add(_RoomAvailability(
          docId: doc.id,
          nom: d['nom'] ?? d['type'] ?? 'Chambre',
          type: d['type'] ?? 'Standard',
          description: d['description'] ?? '',
          equipements: (d['equipements'] as List?)?.cast<String>() ?? [],
          imageUrl: d['imageUrl'] ?? '',
          capacite: (d['capacite'] ?? 2) as int,
          pricePerNight: prix.toInt(),
          totalPrice: prix.toInt() * nights,
          nights: nights,
          isAvailable: !isOccupied,
        ));
      }

      // ✅ 5. Trier : disponibles en premier, puis par prix
      results.sort((a, b) {
        if (a.isAvailable && !b.isAvailable) return -1;
        if (!a.isAvailable && b.isAvailable) return 1;
        return a.pricePerNight.compareTo(b.pricePerNight);
      });

      setState(() {
        _results = results;
        _hasChecked = true;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la vérification : $e';
        _isChecking = false;
        _hasChecked = true;
      });
    }
  }

  // Convertit un champ Firestore (Timestamp ou String) en DateTime
  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ── Sélecteur de date ────────────────────────────────────────────────────

  Future<void> _selectDate(bool isCheckIn) async {
    final initial = isCheckIn ? _checkIn : _checkOut;
    final firstDate =
        isCheckIn ? DateTime.now() : _checkIn.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _dark,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkIn = picked;
          // Si le départ est avant ou égal à l'arrivée, on ajuste
          if (!_checkOut.isAfter(_checkIn)) {
            _checkOut = _checkIn.add(const Duration(days: 1));
          }
        } else {
          _checkOut = picked;
        }
      });
      // Relance la vérification
      _checkAvailability();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;
    final fmt = DateFormat('dd/MM/yyyy');
    final nights = _checkOut.difference(_checkIn).inDays;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text('Chambres Disponibles'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasChecked)
            IconButton(
              onPressed: _checkAvailability,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualiser',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? 24 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Sélecteur de dates ──────────────────────────────────
                _buildDateSelector(fmt, nights),
                const SizedBox(height: 20),

                // ── Résultats ───────────────────────────────────────────
                if (_isChecking)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: _primary),
                          SizedBox(height: 12),
                          Text('Vérification en cours...'),
                        ],
                      ),
                    ),
                  )
                else if (_error != null)
                  _buildErrorWidget()
                else if (_hasChecked)
                  _buildResults(nights),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widget sélecteur de dates ─────────────────────────────────────────────

  Widget _buildDateSelector(DateFormat fmt, int nights) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Sélectionnez vos dates',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: 'Arrivée',
                  date: fmt.format(_checkIn),
                  icon: Icons.flight_land_rounded,
                  onTap: () => _selectDate(true),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$nights nuit${nights > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ),
              Expanded(
                child: _DateButton(
                  label: 'Départ',
                  date: fmt.format(_checkOut),
                  icon: Icons.flight_takeoff_rounded,
                  onTap: () => _selectDate(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Widget résultats ─────────────────────────────────────────────────────

  Widget _buildResults(int nights) {
    final available = _results.where((r) => r.isAvailable).toList();
    final occupied = _results.where((r) => !r.isAvailable).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Résumé
        Row(
          children: [
            _SummaryBadge(
              count: available.length,
              label: 'disponibles',
              color: Colors.green,
              icon: Icons.check_circle_rounded,
            ),
            const SizedBox(width: 12),
            _SummaryBadge(
              count: occupied.length,
              label: 'occupées',
              color: Colors.red,
              icon: Icons.cancel_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (available.isNotEmpty) ...[
          const Text(
            'Nos Chambres et Suites',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Découvrez notre sélection de chambres confortables et élégantes',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          ...available.map((r) => _RoomCard(room: r)),
          const SizedBox(height: 20),
        ],

        if (occupied.isNotEmpty) ...[
          Text(
            'Chambres non disponibles pour ces dates',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          ...occupied.map((r) => _RoomCard(room: r)),
        ],

        if (_results.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucune chambre trouvée.'),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modèle de disponibilité ───────────────────────────────────────────────────

class _RoomAvailability {
  final String docId;        // ✅ ID Firestore
  final String nom;          // ✅ Nom personnalisé par l'admin
  final String type;
  final String description;  // ✅ Description admin
  final List<String> equipements; // ✅ Équipements admin
  final String imageUrl;     // ✅ Photo Supabase
  final int capacite;        // ✅ Capacité
  final int pricePerNight;
  final int totalPrice;
  final int nights;
  final bool isAvailable;

  const _RoomAvailability({
    required this.docId,
    required this.nom,
    required this.type,
    required this.description,
    required this.equipements,
    required this.imageUrl,
    required this.capacite,
    required this.pricePerNight,
    required this.totalPrice,
    required this.nights,
    required this.isAvailable,
  });
}

// ── Carte chambre ─────────────────────────────────────────────────────────────
// ✅ Affiche les vraies chambres publiées par l'admin (image, nom, équipements)

class _RoomCard extends StatelessWidget {
  final _RoomAvailability room;
  const _RoomCard({required this.room});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final available = room.isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: available
              ? Colors.green.withOpacity(0.25)
              : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Image de la chambre
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                room.imageUrl.isNotEmpty
                    ? Image.network(
                        room.imageUrl,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _noImage(),
                      )
                    : _noImage(),
                // Badge prix
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${NumberFormat('#,###', 'fr_FR').format(room.pricePerNight)} FCFA / nuit',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ),
                // Badge disponibilité
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: available ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          available ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          available ? 'Disponible' : 'Occupée',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                // Filtre grisé si occupée
                if (!available)
                  Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.black.withOpacity(0.35),
                  ),
              ],
            ),
          ),

          // Infos
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + type
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.nom,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _dark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(room.type,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _primary)),
                    ),
                  ],
                ),

                // Capacité
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${room.capacite} personne${room.capacite > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),

                // Description
                if (room.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    room.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                  ),
                ],

                // Équipements
                if (room.equipements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: room.equipements.take(5).map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(e,
                          style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                    )).toList(),
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Total + bouton
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (room.nights > 0) ...[
                            Text(
                              '${room.nights} nuit${room.nights > 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            Text(
                              'Total : ${NumberFormat('#,###', 'fr_FR').format(room.totalPrice)} FCFA',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Bouton réserver
                    if (available)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, {
                          'type': room.type,
                          'nom': room.nom,
                          'docId': room.docId,
                          'prix': room.pricePerNight,
                        }),
                        icon: const Icon(Icons.hotel_rounded, size: 16),
                        label: const Text('Réserver maintenant',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Non disponible',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noImage() {
    return Container(
      width: double.infinity,
      height: 180,
      color: const Color(0xFF9B4610).withOpacity(0.08),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_rounded, size: 48, color: Color(0xFF9B4610)),
          SizedBox(height: 8),
          Text('Chambre', style: TextStyle(color: Color(0xFF9B4610), fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Bouton de date ────────────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final String label;
  final String date;
  final IconData icon;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF9B4610).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF9B4610)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A2A10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge résumé ──────────────────────────────────────────────────────────────

class _SummaryBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _SummaryBadge({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}