// ============================================================
// chambres_admin_page.dart
//
// Gestion des chambres côté admin :
// - Liste toutes les chambres depuis Firestore
// - Ajouter une nouvelle chambre (avec photo Supabase)
// - Modifier une chambre existante
// - Activer / désactiver disponibilité
// - Supprimer une chambre
// - Champs : nom, type, prix/nuit, capacité, description,
//            équipements, images, disponible
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChambresAdminPage extends StatefulWidget {
  const ChambresAdminPage({super.key});

  @override
  State<ChambresAdminPage> createState() => _ChambresAdminPageState();
}

class _ChambresAdminPageState extends State<ChambresAdminPage> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  final _db = FirebaseFirestore.instance;
  String _filterType = 'Tous';

  static const _types = [
    'Tous', 'Standard', 'Premium', 'Prestige', 'Deluxe', 'Suite'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          // Filtre par type
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _types.map((t) {
                  final sel = _filterType == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t),
                      selected: sel,
                      onSelected: (_) => setState(() => _filterType = t),
                      backgroundColor: Colors.grey[100],
                      selectedColor: _primary,
                      labelStyle: TextStyle(
                          color: sel ? Colors.white : Colors.black87,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 12),
                      checkmarkColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Liste des chambres
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // ✅ Query sans index composite — tri côté client
              stream: _db.collection('chambres').snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primary));
                }
                if (snap.hasError) {
                  return Center(child: Text('Erreur: \${snap.error}'));
                }

                // Filtrer et trier côté client (évite l'index composite Firestore)
                var docs = snap.data?.docs ?? [];
                if (_filterType != 'Tous') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['type'] == _filterType;
                  }).toList();
                }
                // Tri par date décroissante côté client
                docs.sort((a, b) {
                  final ta = (a.data() as Map)['createdAt'] as Timestamp?;
                  final tb = (b.data() as Map)['createdAt'] as Timestamp?;
                  if (ta == null && tb == null) return 0;
                  if (ta == null) return 1;
                  if (tb == null) return -1;
                  return tb.compareTo(ta);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hotel_outlined, size: 70, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Aucune chambre',
                            style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                        const SizedBox(height: 6),
                        Text('Appuyez sur + pour ajouter une chambre',
                            style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ChambreCard(
                      docId: doc.id,
                      data: data,
                      onEdit: () => _openForm(context, doc.id, data),
                      onDelete: () => _delete(doc.id, data['nom'] ?? ''),
                      onToggle: () => _toggleDispo(doc.id, data['disponible'] as bool? ?? true),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null, null),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle chambre',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _openForm(BuildContext context, String? docId, Map<String, dynamic>? data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChambreForm(docId: docId, existing: data),
    );
  }

  Future<void> _delete(String docId, String nom) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer la chambre "$nom" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await _db.collection('chambres').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chambre supprimée'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _toggleDispo(String docId, bool current) async {
    await _db.collection('chambres').doc(docId).update({
      'disponible': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ──────────────────────────────────────────────────────────────
// Card chambre
// ──────────────────────────────────────────────────────────────
class _ChambreCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ChambreCard({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final nom = data['nom'] ?? 'Chambre';
    final type = data['type'] ?? 'Standard';
    final prix = (data['prix'] ?? 0) as num;
    final capacite = data['capacite'] ?? 2;
    final dispo = data['disponible'] as bool? ?? true;
    final imageUrl = data['imageUrl'] as String?;
    final equipements = (data['equipements'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                // Image
                imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
                // Badge disponibilité
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: dispo ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dispo ? '✓ Disponible' : '✗ Indisponible',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                // Badge type
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(type,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(nom,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _dark)),
                    ),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(prix)} FCFA/nuit',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('$capacite personnes',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                if (data['description'] != null &&
                    (data['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(data['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
                if (equipements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: equipements.take(4).map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(e,
                          style: const TextStyle(
                              fontSize: 10,
                              color: _primary,
                              fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // Actions
                Row(
                  children: [
                    // Toggle dispo
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onToggle,
                        icon: Icon(
                            dispo ? Icons.block_rounded : Icons.check_circle_rounded,
                            size: 16),
                        label: Text(dispo ? 'Désactiver' : 'Activer',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: dispo ? Colors.orange : Colors.green,
                          side: BorderSide(
                              color: dispo ? Colors.orange : Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Modifier
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Modifier',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Supprimer
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_rounded,
                          color: Colors.red, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
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

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 180,
      color: const Color(0xFF9B4610).withOpacity(0.08),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_rounded, size: 48, color: Color(0xFF9B4610)),
          SizedBox(height: 8),
          Text('Pas d\'image',
              style: TextStyle(color: Color(0xFF9B4610), fontSize: 12)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Formulaire ajout / modification chambre
// ──────────────────────────────────────────────────────────────
class _ChambreForm extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existing;

  const _ChambreForm({this.docId, this.existing});

  @override
  State<_ChambreForm> createState() => _ChambreFormState();
}

class _ChambreFormState extends State<_ChambreForm> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capaciteCtrl = TextEditingController();

  String _type = 'Standard';
  bool _disponible = true;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _existingImageUrl;
  Uint8List? _imageBytes;
  String? _imageName;

  // Équipements
  final List<String> _equip = [];
  final _equipCtrl = TextEditingController();

  // Équipements suggérés
  static const _suggestions = [
    'Climatisation', 'TV écran plat', 'Wifi', 'Mini-bar', 'Balcon',
    'Baignoire', 'Douche', 'Coffre-fort', 'Bureau', 'Vue jardin',
    'Vue piscine', 'Piscine', 'Parking', 'Room service', 'Netflix'
  ];

  static const _types = ['Standard', 'Premium', 'Prestige', 'Deluxe', 'Suite'];

  bool get _isEdit => widget.docId != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final d = widget.existing!;
      _nomCtrl.text = d['nom'] ?? '';
      _prixCtrl.text = (d['prix'] ?? 0).toString();
      _descCtrl.text = d['description'] ?? '';
      _capaciteCtrl.text = (d['capacite'] ?? 2).toString();
      _type = d['type'] ?? 'Standard';
      _disponible = d['disponible'] as bool? ?? true;
      _existingImageUrl = d['imageUrl'] as String?;
      final eq = d['equipements'] as List?;
      if (eq != null) _equip.addAll(eq.cast<String>());
    } else {
      _capaciteCtrl.text = '2';
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prixCtrl.dispose();
    _descCtrl.dispose();
    _capaciteCtrl.dispose();
    _equipCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
    });
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return _existingImageUrl;
    setState(() => _uploadingImage = true);
    try {
      final supabase = Supabase.instance.client;
      final ext = _imageName?.split('.').last ?? 'jpg';
      final path =
          'chambres/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('chambres-images').uploadBinary(path, _imageBytes!);
      return supabase.storage.from('chambres-images').getPublicUrl(path);
    } catch (e) {
      return _existingImageUrl;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final imageUrl = await _uploadImage();
      final data = {
        'nom': _nomCtrl.text.trim(),
        'type': _type,
        'prix': int.tryParse(_prixCtrl.text) ?? 0,
        'capacite': int.tryParse(_capaciteCtrl.text) ?? 2,
        'description': _descCtrl.text.trim(),
        'equipements': _equip,
        'disponible': _disponible,
        'imageUrl': imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('chambres')
            .doc(widget.docId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('chambres').add(data);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? '✅ Chambre modifiée' : '✅ Chambre ajoutée'),
          backgroundColor: Colors.green,
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
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Titre
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    _isEdit ? 'Modifier la chambre' : 'Nouvelle chambre',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Formulaire
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  children: [
                    // Image
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _primary.withOpacity(0.3),
                              style: BorderStyle.solid),
                        ),
                        child: _uploadingImage
                            ? const Center(child: CircularProgressIndicator(color: _primary))
                            : _imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(_imageBytes!,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover))
                                : _existingImageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(_existingImageUrl!,
                                            width: double.infinity,
                                            height: 160,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _imagePlaceholder()))
                                    : _imagePlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                        child: Text('Appuyez pour changer la photo',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                    const SizedBox(height: 16),

                    // Nom
                    _label('Nom de la chambre'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nomCtrl,
                      decoration: _inputDeco('Ex: Chambre Deluxe 101'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 14),

                    // Type
                    _label('Type'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _type,
                          isExpanded: true,
                          items: _types
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Prix + Capacité
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Prix / nuit (FCFA)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _prixCtrl,
                                decoration: _inputDeco('Ex: 50000'),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Requis'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Capacité (pers.)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _capaciteCtrl,
                                decoration: _inputDeco('Ex: 2'),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Requis'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description
                    _label('Description'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: _inputDeco(
                          'Décrivez la chambre, la vue, les avantages...'),
                    ),
                    const SizedBox(height: 14),

                    // Équipements
                    _label('Équipements'),
                    const SizedBox(height: 8),
                    // Suggestions rapides
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _suggestions.map((s) {
                        final sel = _equip.contains(s);
                        return FilterChip(
                          label: Text(s, style: TextStyle(fontSize: 11)),
                          selected: sel,
                          onSelected: (_) {
                            setState(() {
                              if (sel) {
                                _equip.remove(s);
                              } else {
                                _equip.add(s);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: _primary,
                          labelStyle: TextStyle(
                              color: sel ? Colors.white : Colors.black87),
                          checkmarkColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Ajouter un équipement personnalisé
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _equipCtrl,
                            decoration: _inputDeco('Autre équipement...'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final v = _equipCtrl.text.trim();
                            if (v.isNotEmpty && !_equip.contains(v)) {
                              setState(() {
                                _equip.add(v);
                                _equipCtrl.clear();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                          child: const Icon(Icons.add_rounded, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Disponibilité
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.toggle_on_rounded,
                              size: 20, color: _primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Disponible à la réservation',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          Switch(
                            value: _disponible,
                            onChanged: (v) => setState(() => _disponible = v),
                            activeColor: _primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton sauvegarder
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Icon(_isEdit
                                ? Icons.save_rounded
                                : Icons.add_rounded,
                                size: 18),
                        label: Text(
                          _saving
                              ? 'Enregistrement...'
                              : _isEdit
                                  ? 'Enregistrer les modifications'
                                  : 'Ajouter la chambre',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate_rounded,
            color: _primary, size: 40),
        const SizedBox(height: 8),
        const Text('Ajouter une photo',
            style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _dark));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}