// ============================================================
// rating_page.dart
//
// Page "Noter mon séjour" côté client :
// - Note globale (étoiles 1-5)
// - Notes par critère : Chambre, Accueil, Restauration, Propreté, Wifi
// - Commentaire libre
// - Sauvegarde dans Firestore collection 'avis'
// - Vue historique des avis déjà soumis
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  late TabController _tab;
  final _user = FirebaseAuth.instance.currentUser;

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
        title: const Text('Mon séjour',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.star_rounded), text: 'Laisser un avis'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Mes avis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _NewRatingTab(user: _user),
          _MyReviewsTab(user: _user),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Onglet : Laisser un avis
// ──────────────────────────────────────────────────────────────
class _NewRatingTab extends StatefulWidget {
  final User? user;
  const _NewRatingTab({required this.user});

  @override
  State<_NewRatingTab> createState() => _NewRatingTabState();
}

class _NewRatingTabState extends State<_NewRatingTab> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  // Notes par critère
  final Map<String, int> _notes = {
    'Chambre': 0,
    'Accueil': 0,
    'Restauration': 0,
    'Propreté': 0,
    'Wifi': 0,
  };

  // Icons par critère
  final Map<String, IconData> _icons = {
    'Chambre': Icons.hotel_rounded,
    'Accueil': Icons.people_rounded,
    'Restauration': Icons.restaurant_rounded,
    'Propreté': Icons.cleaning_services_rounded,
    'Wifi': Icons.wifi_rounded,
  };

  int _noteGlobale = 0;
  final _commentCtrl = TextEditingController();
  bool _saving = false;
  String? _selectedReservation;
  List<Map<String, dynamic>> _reservations = [];
  bool _loadingRes = true;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    if (widget.user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: widget.user!.uid)
          .where('status', whereIn: ['checked-out', 'checked-in'])
          .get();
      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'label': '${data['roomType'] ?? 'Chambre'} — ${data['checkInDate'] ?? ''}',
        };
      }).toList();
      if (mounted) setState(() { _reservations = list; _loadingRes = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRes = false);
    }
  }

  double get _moyenne {
    final vals = _notes.values.where((v) => v > 0);
    if (vals.isEmpty) return 0;
    return vals.fold(0, (a, b) => a + b) / vals.length;
  }

  Future<void> _submit() async {
    if (_noteGlobale == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⭐ Veuillez donner une note globale'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (widget.user == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('avis').add({
        'userId': widget.user!.uid,
        'userEmail': widget.user!.email,
        'noteGlobale': _noteGlobale,
        'notes': _notes,
        'moyenne': _moyenne,
        'commentaire': _commentCtrl.text.trim(),
        'reservationId': _selectedReservation ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'visible': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Merci pour votre avis !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        // Reset
        setState(() {
          _noteGlobale = 0;
          _notes.updateAll((_, __) => 0);
          _commentCtrl.clear();
          _selectedReservation = null;
        });
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF9B4610),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 48),
                const SizedBox(height: 8),
                const Text('Comment s\'est passé votre séjour ?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Votre avis nous aide à nous améliorer',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sélection réservation
          if (_reservations.isNotEmpty) ...[
            _sectionTitle('Séjour concerné'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedReservation,
                  isExpanded: true,
                  hint: const Text('Sélectionner un séjour'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Non spécifié')),
                    ..._reservations.map((r) => DropdownMenuItem(
                          value: r['id'] as String,
                          child: Text(r['label'] as String,
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedReservation = v),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Note globale
          _sectionTitle('Note globale'),
          const SizedBox(height: 10),
          _GlobalStarPicker(
            note: _noteGlobale,
            onChanged: (v) => setState(() => _noteGlobale = v),
          ),
          const SizedBox(height: 24),

          // Notes par critère
          _sectionTitle('Évaluation détaillée'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              children: _notes.entries.map((e) {
                final isLast = e.key == _notes.keys.last;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(_icons[e.key], color: _primary, size: 20),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 100,
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _dark)),
                          ),
                          Expanded(
                            child: _CriteriaStars(
                              note: e.value,
                              onChanged: (v) =>
                                  setState(() => _notes[e.key] = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Commentaire
          _sectionTitle('Commentaire (optionnel)'),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Partagez votre expérience en détail...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 1.5)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),

          // Bouton soumettre
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_saving ? 'Envoi...' : 'Soumettre mon avis',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A2A10)));
}

// ──────────────────────────────────────────────────────────────
// Onglet : Mes avis passés
// ──────────────────────────────────────────────────────────────
class _MyReviewsTab extends StatelessWidget {
  final User? user;
  const _MyReviewsTab({required this.user});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Non connecté'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('avis')
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_outline_rounded, size: 70, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Aucun avis soumis',
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Vos avis apparaîtront ici après soumission',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _ReviewCard(data: data);
          },
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReviewCard({required this.data});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final note = (data['noteGlobale'] ?? 0) as int;
    final comment = data['commentaire'] as String? ?? '';
    final notes = data['notes'] as Map? ?? {};
    final ts = data['createdAt'] as Timestamp?;
    final dateStr =
        ts != null ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Note globale
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < note ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 22,
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text('$note/5',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _dark)),
                const Spacer(),
                Text(dateStr,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('"$comment"',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic)),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: notes.entries.map((e) {
                  final n = (e.value as int?) ?? 0;
                  if (n == 0) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 11, color: _primary, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                        Text('$n',
                            style: const TextStyle(
                                fontSize: 11, color: _primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Widgets étoiles
// ──────────────────────────────────────────────────────────────
class _GlobalStarPicker extends StatelessWidget {
  final int note;
  final Function(int) onChanged;

  const _GlobalStarPicker({required this.note, required this.onChanged});

  static const _labels = ['', 'Mauvais', 'Passable', 'Bien', 'Très bien', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => onChanged(i + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    i < note ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < note ? Colors.amber : Colors.grey[300],
                    size: 44,
                  ),
                ),
              );
            }),
          ),
          if (note > 0) ...[
            const SizedBox(height: 8),
            Text(
              _labels[note],
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber),
            ),
          ],
        ],
      ),
    );
  }
}

class _CriteriaStars extends StatelessWidget {
  final int note;
  final Function(int) onChanged;

  const _CriteriaStars({required this.note, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Icon(
            i < note ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < note ? Colors.amber : Colors.grey[300],
            size: 26,
          ),
        );
      }),
    );
  }
}