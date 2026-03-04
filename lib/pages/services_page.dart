// ============================================================
// services_page.dart
//
// Page de gestion des services pour l'admin.
// - Upload d'images vers Supabase Storage (bucket: services-images)
// - CRUD complet : ajouter, modifier, supprimer un service
// - Les services s'affichent côté client avec image, prix, détails
// - Sync temps réel via Firestore
//
// Collection Firestore : services
// Champs : name, description, price, category, imageUrl, available, createdAt
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // Supabase bucket
  static const _bucket = 'services-images';
  static const _supabaseUrl = 'https://qocofmvboukgkbzsbwek.supabase.co';

  String _filterCategory = 'Tous';

  final _categories = [
    'Tous', 'Spa', 'Restaurant', 'Transport', 'Loisirs', 'Chambre', 'Autre'
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Column(
      children: [
        // ── En-tête ──────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 24 : 16, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A2A10), _primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.room_service_rounded,
                  color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Gestion des Services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              // Bouton Ajouter
              ElevatedButton.icon(
                onPressed: () => _openServiceDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // ── Filtres catégories ────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final selected = _filterCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _filterCategory = cat),
                    selectedColor: _primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Liste des services ────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('services')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _primary));
              }

              var docs = snap.data?.docs ?? [];

              // Filtre par catégorie
              if (_filterCategory != 'Tous') {
                docs = docs
                    .where((d) =>
                        (d.data() as Map)['category'] ==
                        _filterCategory)
                    .toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.room_service_outlined,
                          size: 70, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _filterCategory == 'Tous'
                            ? 'Aucun service créé'
                            : 'Aucun service dans cette catégorie',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openServiceDialog(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter un service'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Grille web / liste mobile
              if (isWeb) {
                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _ServiceCard(
                    doc: docs[i],
                    onEdit: () => _openServiceDialog(context, doc: docs[i]),
                    onDelete: () => _confirmDelete(context, docs[i]),
                    onToggle: () => _toggleAvailability(docs[i]),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                itemBuilder: (_, i) => _ServiceCard(
                  doc: docs[i],
                  onEdit: () => _openServiceDialog(context, doc: docs[i]),
                  onDelete: () => _confirmDelete(context, docs[i]),
                  onToggle: () => _toggleAvailability(docs[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Toggle disponibilité ──────────────────────────────────────────────────

  Future<void> _toggleAvailability(DocumentSnapshot doc) async {
    final current = (doc.data() as Map)['available'] as bool? ?? true;
    await FirebaseFirestore.instance
        .collection('services')
        .doc(doc.id)
        .update({'available': !current});
  }

  // ── Confirmation suppression ──────────────────────────────────────────────

  Future<void> _confirmDelete(
      BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce service ?'),
        content: Text(
            'Le service "${data['name']}" sera supprimé définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Supprime aussi l'image sur Supabase
      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final path = imageUrl.split('/$_bucket/').last;
          await Supabase.instance.client.storage
              .from(_bucket)
              .remove([path]);
        } catch (_) {}
      }
      await FirebaseFirestore.instance
          .collection('services')
          .doc(doc.id)
          .delete();
    }
  }

  // ── Dialog Ajouter / Modifier ─────────────────────────────────────────────

  void _openServiceDialog(BuildContext context, {DocumentSnapshot? doc}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServiceDialog(doc: doc),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DIALOG AJOUTER / MODIFIER UN SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class _ServiceDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  const _ServiceDialog({this.doc});

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bucket = 'services-images';

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String _category = 'Spa';
  String _subcategory = ''; // Sous-catégorie pour le bon menu
  bool _available = true;
  bool _saving = false;
  bool _uploadingImage = false;

  // Image
  Uint8List? _imageBytes;
  String? _imageName;
  String? _existingImageUrl;

  static const _categories = [
    'Spa', 'Restaurant', 'Transport', 'Loisirs', 'Chambre', 'Autre'
  ];

  // Sous-catégories selon la catégorie principale
  static const Map<String, List<String>> _subcategories = {
    'Restaurant': ['Plat Principal', 'Entrée', 'Dessert', 'Boissons'],
    'Spa': ['Massage', 'Soin Visage', 'Soin Corps', 'Autre'],
    'Transport': ['Location', 'Transport', 'Tourisme'],
    'Loisirs': ['Sport', 'Divertissement', 'Excursion'],
    'Chambre': ['Entretien', 'Restauration', 'Service', 'Autre'],
    'Autre': ['Général'],
  };

  List<String> get _currentSubcategories =>
      _subcategories[_category] ?? ['Général'];

  @override
  void initState() {
    super.initState();
    // Mode modification : pré-rempli les champs
    if (widget.doc != null) {
      final data = widget.doc!.data() as Map<String, dynamic>;
      _nameCtrl.text = data['name'] ?? '';
      _descCtrl.text = data['description'] ?? '';
      _priceCtrl.text = (data['price'] ?? 0).toString();
      _category = data['category'] ?? 'Spa';
      _subcategory = data['subcategory'] ?? '';
      _available = data['available'] as bool? ?? true;
      _existingImageUrl = data['imageUrl'];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── Sélection image ───────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur image : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Upload image vers Supabase ────────────────────────────────────────────

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return _existingImageUrl;

    setState(() => _uploadingImage = true);
    try {
      final ext = _imageName?.split('.').last ?? 'jpg';
      final fileName =
          'service_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage.from(_bucket).uploadBinary(
            fileName,
            _imageBytes!,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              upsert: true,
            ),
          );

      // Construit l'URL publique
      final url = Supabase.instance.client.storage
          .from(_bucket)
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur upload image : $e'),
              backgroundColor: Colors.red),
        );
      }
      return _existingImageUrl;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // ── Sauvegarde ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      // Upload image si une nouvelle a été sélectionnée
      final imageUrl = await _uploadImage();

      final data = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': int.tryParse(_priceCtrl.text) ?? 0,
        'category': _category,
        'subcategory': _subcategory,
        'available': _available,
        'imageUrl': imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.doc == null) {
        // Création
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('services').add(data);
      } else {
        // Modification
        await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.doc!.id)
            .update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.doc == null
              ? '✅ Service créé avec succès'
              : '✅ Service modifié avec succès'),
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
    final isEdit = widget.doc != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Column(
          children: [
            // En-tête dialog
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A2A10), _primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.room_service_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Modifier le service' : 'Nouveau service',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Formulaire
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Image ──────────────────────────────────────────
                      const Text('Image du service',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _dark)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1.5),
                          ),
                          child: _buildImagePreview(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Nom ────────────────────────────────────────────
                      _buildLabel('Nom du service *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDecor('Ex : Massage relaxant'),
                        validator: (v) =>
                            (v?.trim().isEmpty == true) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 14),

                      // ── Description ────────────────────────────────────
                      _buildLabel('Description'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: _inputDecor(
                            'Décrivez le service en détail…'),
                      ),
                      const SizedBox(height: 14),

                      // ── Prix ───────────────────────────────────────────
                      _buildLabel('Prix (FCFA) *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecor('Ex : 15000'),
                        validator: (v) =>
                            (v?.trim().isEmpty == true) ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 14),

                      // ── Catégorie ──────────────────────────────────────
                      _buildLabel('Catégorie'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5F0),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _category,
                            isExpanded: true,
                            items: _categories
                                .map((c) => DropdownMenuItem(
                                    value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() {
                                _category = v!;
                                // Reset subcategory quand catégorie change
                                _subcategory = (_subcategories[v] ?? ['Général']).first;
                              }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Sous-catégorie (s'affiche selon la catégorie) ──
                      _buildLabel('Sous-catégorie (position dans le menu)'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentSubcategories.contains(_subcategory)
                                ? _subcategory
                                : _currentSubcategories.first,
                            isExpanded: true,
                            items: _currentSubcategories
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        Icon(_subcategoryIcon(s), size: 16, color: const Color(0xFF9B4610)),
                                        const SizedBox(width: 8),
                                        Text(s),
                                      ],
                                    )))
                                .toList(),
                            onChanged: (v) => setState(() => _subcategory = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _subcategoryHint(_category, _subcategory.isEmpty ? _currentSubcategories.first : _subcategory),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Disponible ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.toggle_on_rounded,
                                size: 20, color: _primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Disponible pour les clients',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            Switch(
                              value: _available,
                              onChanged: (v) =>
                                  setState(() => _available = v),
                              activeColor: _primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Boutons bas
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: (_saving || _uploadingImage) ? null : _save,
                      icon: (_saving || _uploadingImage)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(
                              isEdit
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                              size: 18),
                      label: Text(
                        _uploadingImage
                            ? 'Upload image…'
                            : _saving
                                ? 'Enregistrement…'
                                : isEdit
                                    ? 'Enregistrer'
                                    : 'Créer le service',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Preview image sélectionnée ou existante
  Widget _buildImagePreview() {
    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_imageBytes!, fit: BoxFit.cover),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (_existingImageUrl?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _existingImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderImage(),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      );
    }

    return _placeholderImage();
  }

  Widget _placeholderImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_rounded,
            size: 40, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text('Cliquez pour ajouter une image',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  // ✅ Icône selon sous-catégorie
  IconData _subcategoryIcon(String sub) {
    switch (sub) {
      case 'Plat Principal': return Icons.restaurant_rounded;
      case 'Entrée': return Icons.soup_kitchen_rounded;
      case 'Dessert': return Icons.cake_rounded;
      case 'Boissons': return Icons.local_drink_rounded;
      case 'Massage': return Icons.spa_rounded;
      case 'Location': return Icons.car_rental_rounded;
      case 'Transport': return Icons.directions_car_rounded;
      case 'Tourisme': return Icons.tour_rounded;
      case 'Entretien': return Icons.cleaning_services_rounded;
      default: return Icons.category_rounded;
    }
  }

  // ✅ Hint expliquant où va apparaître le service
  String _subcategoryHint(String cat, String sub) {
    switch (cat) {
      case 'Restaurant':
        return '→ Apparaîtra dans Commander → Menu Restaurant → Section "$sub"';
      case 'Transport':
        return '→ Apparaîtra dans Commander → Service Voiture → Section "$sub"';
      case 'Spa':
      case 'Loisirs':
      case 'Chambre':
        return '→ Apparaîtra dans Commander → Services Additionnels → Section "$sub"';
      default:
        return '→ Apparaîtra dans Commander → Services Additionnels';
    }
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, color: _dark));
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(0xFFFAF5F0),
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
}

// ══════════════════════════════════════════════════════════════════════════════
// CARTE SERVICE (admin)
// ══════════════════════════════════════════════════════════════════════════════

class _ServiceCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ServiceCard({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Service';
    final description = data['description'] ?? '';
    final price = (data['price'] ?? 0) as num;
    final category = data['category'] ?? 'Autre';
    final imageUrl = data['imageUrl'] as String?;
    final available = data['available'] as bool? ?? true;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: (imageUrl?.isNotEmpty == true)
                    ? Image.network(
                        imageUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildPlaceholder(category),
                      )
                    : _buildPlaceholder(category),
              ),
              // Badge catégorie
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(category,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              // Badge disponibilité
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: available
                          ? Colors.green.withOpacity(0.9)
                          : Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      available ? 'Disponible' : 'Indisponible',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Infos
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(price)} FCFA',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _primary),
                    ),
                    const Spacer(),
                    // Modifier
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          size: 18, color: Colors.blue),
                      onPressed: onEdit,
                      tooltip: 'Modifier',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    // Supprimer
                    IconButton(
                      icon: const Icon(Icons.delete_rounded,
                          size: 18, color: Colors.red),
                      onPressed: onDelete,
                      tooltip: 'Supprimer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  Widget _buildPlaceholder(String category) {
    final icons = {
      'Spa': Icons.spa_rounded,
      'Restaurant': Icons.restaurant_rounded,
      'Transport': Icons.directions_car_rounded,
      'Loisirs': Icons.sports_tennis_rounded,
      'Chambre': Icons.hotel_rounded,
    };
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icons[category] ?? Icons.room_service_rounded,
              size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(category,
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAGE SERVICES CÔTÉ CLIENT (à utiliser dans client_client.dart)
// Affiche uniquement les services disponibles avec image + détails
// ══════════════════════════════════════════════════════════════════════════════

class ClientServicesView extends StatefulWidget {
  const ClientServicesView({super.key});

  @override
  State<ClientServicesView> createState() => _ClientServicesViewState();
}

class _ClientServicesViewState extends State<ClientServicesView> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  String _selectedCategory = 'Tous';

  final _categories = [
    'Tous', 'Spa', 'Restaurant', 'Transport', 'Loisirs', 'Chambre', 'Autre'
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          // En-tête
          Container(
            padding: EdgeInsets.fromLTRB(
                isWeb ? 24 : 16, 16, isWeb ? 24 : 16, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A2A10), _primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nos Services',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Découvrez tous nos services à votre disposition',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75)),
                ),
                const SizedBox(height: 14),
                // Filtres
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final selected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 14),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: selected ? _primary : Colors.white,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Liste services
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .where('available', isEqualTo: true)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _primary));
                }

                var docs = snap.data?.docs ?? [];

                if (_selectedCategory != 'Tous') {
                  docs = docs
                      .where((d) =>
                          (d.data() as Map)['category'] ==
                          _selectedCategory)
                      .toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.room_service_outlined,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun service disponible',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                if (isWeb) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (_, i) =>
                        _ClientServiceCard(doc: docs[i]),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  itemBuilder: (_, i) =>
                      _ClientServiceCard(doc: docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte service côté client ─────────────────────────────────────────────────

class _ClientServiceCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const _ClientServiceCard({required this.doc});

  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Service';
    final description = data['description'] ?? '';
    final price = (data['price'] ?? 0) as num;
    final category = data['category'] ?? 'Autre';
    final imageUrl = data['imageUrl'] as String?;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du service
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: (imageUrl?.isNotEmpty == true)
                ? Image.network(
                    imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 160,
                        color: Colors.grey.shade100,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: _primary, strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (_, __, ___) => _placeholder(category),
                  )
                : _placeholder(category),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge catégorie
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primary),
                  ),
                ),
                const SizedBox(height: 8),

                // Nom
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Description
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Prix + bouton
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${NumberFormat('#,###', 'fr_FR').format(price)} FCFA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showDetails(context, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Voir détails'),
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

  Widget _placeholder(String category) {
    final icons = {
      'Spa': Icons.spa_rounded,
      'Restaurant': Icons.restaurant_rounded,
      'Transport': Icons.directions_car_rounded,
      'Loisirs': Icons.sports_tennis_rounded,
      'Chambre': Icons.hotel_rounded,
    };
    return Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Icon(icons[category] ?? Icons.room_service_rounded,
          size: 48, color: Colors.grey[300]),
    );
  }

  // Dialog détails du service
  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    final imageUrl = data['imageUrl'] as String?;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image
              if (imageUrl?.isNotEmpty == true)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _dark)),
                    const SizedBox(height: 4),
                    Text(data['category'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    if ((data['description'] as String?)?.isNotEmpty == true)
                      Text(data['description'],
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[700])),
                    const SizedBox(height: 16),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(data['price'] ?? 0)} FCFA',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _primary),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Fermer',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}