// ============================================================
// invoices_page.dart
//
// Page Factures & Paiement côté client :
// - Liste toutes les factures (réservations + commandes)
// - Statut : Payé / En attente / En retard
// - Payer en ligne (MTN, Orange Money, Carte bancaire)
// - Télécharger / voir détail facture
// - Total dépensé + récapitulatif
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  late TabController _tab;
  final _user = FirebaseAuth.instance.currentUser;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        title: const Text('Mes Factures',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.hotel_rounded), text: 'Séjours'),
            Tab(icon: Icon(Icons.room_service_rounded), text: 'Commandes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ReservationInvoices(user: _user, db: _db),
          _CommandeInvoices(user: _user, db: _db),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Factures Réservations (séjours)
// ──────────────────────────────────────────────────────────────
class _ReservationInvoices extends StatelessWidget {
  final User? user;
  final FirebaseFirestore db;

  const _ReservationInvoices({required this.user, required this.db});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Non connecté'));

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('reservations')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.receipt_long_rounded,
            message: 'Aucune facture de séjour',
            sub: 'Vos factures de réservation apparaîtront ici',
          );
        }

        // Calcul total
        final total = docs.fold<int>(0, (sum, d) {
          final data = d.data() as Map<String, dynamic>;
          return sum + ((data['totalAmount'] ?? data['price'] ?? 0) as num).toInt();
        });
        final paid = docs.fold<int>(0, (sum, d) {
          final data = d.data() as Map<String, dynamic>;
          if (data['paymentStatus'] == 'paid') {
            return sum + ((data['totalAmount'] ?? data['price'] ?? 0) as num).toInt();
          }
          return sum;
        });

        return Column(
          children: [
            // Résumé
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                        label: 'Total dépensé',
                        value: '${_fmt(total)} FCFA',
                        icon: Icons.account_balance_wallet_rounded),
                  ),
                  Container(width: 1, height: 40, color: Colors.white30),
                  Expanded(
                    child: _SummaryItem(
                        label: 'Payé',
                        value: '${_fmt(paid)} FCFA',
                        icon: Icons.check_circle_rounded),
                  ),
                  Container(width: 1, height: 40, color: Colors.white30),
                  Expanded(
                    child: _SummaryItem(
                        label: 'En attente',
                        value: '${_fmt(total - paid)} FCFA',
                        icon: Icons.pending_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _ReservationInvoiceCard(
                    docId: doc.id,
                    data: data,
                    db: db,
                    userId: user!.uid,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmt(int v) => NumberFormat('#,###', 'fr_FR').format(v);
}

class _ReservationInvoiceCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final String userId;

  const _ReservationInvoiceCard(
      {required this.docId,
      required this.data,
      required this.db,
      required this.userId});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final payStatus = data['paymentStatus'] ?? 'pending';
    final roomType = data['roomType'] ?? 'Chambre';
    final checkIn = _parseDate(data['checkInDate']);
    final checkOut = _parseDate(data['checkOutDate']);
    final nights = checkOut != null && checkIn != null
        ? checkOut.difference(checkIn).inDays
        : 0;
    final amount = (data['totalAmount'] ?? data['price'] ?? 0) as num;
    final ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('dd/MM/yyyy').format(ts.toDate())
        : '';
    final isPaid = payStatus == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPaid
                  ? Colors.green.withOpacity(0.07)
                  : _primary.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.hotel_rounded,
                    color: isPaid ? Colors.green : _primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$roomType • $nights nuit${nights > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _dark)),
                      if (dateStr.isNotEmpty)
                        Text('Réservé le $dateStr',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                _StatusBadge(isPaid: isPaid),
              ],
            ),
          ),
          // Détails
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _Row('Arrivée', checkIn != null
                    ? DateFormat('dd/MM/yyyy').format(checkIn)
                    : '—'),
                _Row('Départ', checkOut != null
                    ? DateFormat('dd/MM/yyyy').format(checkOut)
                    : '—'),
                _Row('Chambre n°', data['roomNumber'] ?? 'Non attribuée'),
                _Row('Statut séjour', _statusLabel(status)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _dark)),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(amount)} FCFA',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isPaid ? Colors.green : _primary),
                    ),
                  ],
                ),
                if (!isPaid) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showPaymentDialog(context, amount, docId),
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text('Payer maintenant',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
                if (isPaid) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showInvoiceDetail(context),
                      icon: const Icon(Icons.receipt_rounded, size: 16),
                      label: const Text('Voir la facture'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateFormat('dd/MM/yyyy').parse(v);
      } catch (_) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
      }
    }
    return null;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmée';
      case 'checked-in': return 'En cours';
      case 'checked-out': return 'Terminée';
      case 'cancelled': return 'Annulée';
      default: return s;
    }
  }

  void _showPaymentDialog(BuildContext context, num amount, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        amount: amount,
        label: 'Séjour hôtel',
        onPaid: (method) async {
          await FirebaseFirestore.instance
              .collection('reservations')
              .doc(docId)
              .update({
            'paymentStatus': 'paid',
            'paymentMethod': method,
            'paidAt': FieldValue.serverTimestamp(),
          });
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Paiement effectué avec succès !'),
              backgroundColor: Colors.green,
            ));
          }
        },
      ),
    );
  }

  void _showInvoiceDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _InvoiceDetailDialog(data: data, type: 'reservation'),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Factures Commandes
// ──────────────────────────────────────────────────────────────
class _CommandeInvoices extends StatelessWidget {
  final User? user;
  final FirebaseFirestore db;

  const _CommandeInvoices({required this.user, required this.db});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Non connecté'));

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('commandes')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.room_service_rounded,
            message: 'Aucune facture de commande',
            sub: 'Vos commandes de services apparaîtront ici',
          );
        }

        final total = docs.fold<int>(0, (sum, d) {
          final data = d.data() as Map<String, dynamic>;
          return sum + ((data['total'] ?? 0) as num).toInt();
        });

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total commandes',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${NumberFormat('#,###', 'fr_FR').format(total)} FCFA',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _CommandeInvoiceCard(
                      docId: doc.id, data: data, db: db);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommandeInvoiceCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;

  const _CommandeInvoiceCard(
      {required this.docId, required this.data, required this.db});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final item = data['item'] ?? 'Commande';
    final quantite = data['quantite'] ?? 1;
    final total = (data['total'] ?? 0) as num;
    final statut = data['statut'] ?? 'en_attente';
    final isPaid = data['paymentStatus'] == 'paid' || statut == 'terminee';
    final ts = data['date'] as Timestamp?;
    final dateStr =
        ts != null ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.room_service_rounded,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _dark)),
                      Text('Qté : $quantite • $dateStr',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                _StatusBadge(isPaid: isPaid),
              ],
            ),
            const SizedBox(height: 10),
            _Row('Chambre', data['chambre'] ?? '—'),
            _Row('Instructions', data['instructions'] ?? 'Aucune'),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _dark)),
                Text(
                  '${NumberFormat('#,###', 'fr_FR').format(total)} FCFA',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isPaid ? Colors.green : _primary),
                ),
              ],
            ),
            if (!isPaid) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(context, total, docId),
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: const Text('Payer',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, num amount, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        amount: amount,
        label: data['item'] ?? 'Commande',
        onPaid: (method) async {
          await FirebaseFirestore.instance
              .collection('commandes')
              .doc(docId)
              .update({
            'paymentStatus': 'paid',
            'paymentMethod': method,
            'paidAt': FieldValue.serverTimestamp(),
          });
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Paiement effectué avec succès !'),
              backgroundColor: Colors.green,
            ));
          }
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sheet de paiement (bottom sheet)
// ──────────────────────────────────────────────────────────────
class _PaymentSheet extends StatefulWidget {
  final num amount;
  final String label;
  final Function(String method) onPaid;

  const _PaymentSheet(
      {required this.amount, required this.label, required this.onPaid});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  String _selected = 'MTN Mobile Money';
  bool _processing = false;

  final _methods = [
    ('MTN Mobile Money', Icons.phone_android_rounded, Color(0xFFFFCC00)),
    ('Orange Money', Icons.phone_android_rounded, Color(0xFFFF6B00)),
    ('Carte Bancaire', Icons.credit_card_rounded, Color(0xFF1976D2)),
    ('Paiement à la réception', Icons.store_rounded, Color(0xFF388E3C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Choisir le mode de paiement',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 6),
          Text(widget.label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,###', 'fr_FR').format(widget.amount)} FCFA',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: _primary),
          ),
          const SizedBox(height: 20),
          // Méthodes
          ..._methods.map((m) {
            final isSelected = _selected == m.$1;
            return GestureDetector(
              onTap: () => setState(() => _selected = m.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primary.withOpacity(0.07)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _primary : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: m.$3.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(m.$2, color: m.$3, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(m.$1,
                          style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected ? _primary : Colors.black87,
                              fontSize: 14)),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: _primary, size: 22),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processing ? null : _pay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _selected == 'Paiement à la réception'
                          ? 'Confirmer'
                          : 'Payer ${NumberFormat('#,###', 'fr_FR').format(widget.amount)} FCFA',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _pay() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1500)); // Simulation
    widget.onPaid(_selected);
  }
}

// ──────────────────────────────────────────────────────────────
// Dialog détail facture
// ──────────────────────────────────────────────────────────────
class _InvoiceDetailDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final String type;

  const _InvoiceDetailDialog({required this.data, required this.type});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final amount = (data['totalAmount'] ?? data['total'] ?? data['price'] ?? 0) as num;
    final paidAt = data['paidAt'] as Timestamp?;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('FLOSTAY',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _dark,
                    letterSpacing: 2)),
            const Text('Facture de séjour',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            const Divider(),
            if (type == 'reservation') ...[
              _Row('Type de chambre', data['roomType'] ?? ''),
              _Row('N° chambre', data['roomNumber'] ?? 'Non attribuée'),
              _Row('Arrivée', data['checkInDate']?.toString() ?? ''),
              _Row('Départ', data['checkOutDate']?.toString() ?? ''),
            ],
            _Row('Méthode paiement', data['paymentMethod'] ?? ''),
            if (paidAt != null)
              _Row('Payé le',
                  DateFormat('dd/MM/yyyy').format(paidAt.toDate())),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _dark)),
                Text(
                  '${NumberFormat('#,###', 'fr_FR').format(amount)} FCFA',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: _primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text('Paiement confirmé',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer',
                    style: TextStyle(color: _primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Widgets communs
// ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isPaid;
  const _StatusBadge({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid
            ? Colors.green.withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaid ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Text(
        isPaid ? '✓ Payé' : '⏳ En attente',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPaid ? Colors.green : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13),
            textAlign: TextAlign.center),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A2A10))),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState(
      {required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 6),
          Text(sub,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}