// ============================================================
// commander_page.dart — VERSION HYBRIDE FIRESTORE
//
// ✅ Items fixes existants conservés (Poulet DG, Ndolè, etc.)
// ✅ Services publiés par l'admin depuis Firestore apparaissent
//    DANS la bonne section selon leur catégorie :
//      - "Restaurant"  → Menu Restaurant (commandable)
//      - "Transport"   → Service Voiture
//      - "Spa"         → Services Additionnels
//      - "Loisirs"     → Services Additionnels
//      - "Chambre"     → Services Additionnels
//      - "Autre"       → Services Additionnels
// ✅ Chaque service Firestore est commandable comme les items fixes
// ✅ Image Supabase affichée si disponible, sinon placeholder
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:flostay/pages/details_commande_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page principale : liste des catégories
// ─────────────────────────────────────────────────────────────────────────────

class CommanderPage extends StatelessWidget {
  const CommanderPage({super.key});

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Commandes et Services"),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCategoryCard(
              context,
              "Plat Restaurant 🍽️",
              "Commandez des plats délicieux de notre restaurant",
              Icons.restaurant,
              const Color(0xFF9B4610),
              () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ListeItemsPage(type: "restaurant"),
              )),
              type: "restaurant",
            ),
            const SizedBox(height: 12),
            _buildCategoryCard(
              context,
              "Produit Vitrine 🛍️",
              "Découvrez nos produits exclusifs en vitrine",
              Icons.shopping_bag,
              const Color(0xFF2A9D8F),
              () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ListeItemsPage(type: "vitrine"),
              )),
              type: "vitrine",
            ),
            const SizedBox(height: 12),
            _buildCategoryCard(
              context,
              "Service Voiture 🚗",
              "Réservez un service de transport ou location",
              Icons.directions_car,
              const Color(0xFFE76F51),
              () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ListeItemsPage(type: "voiture"),
              )),
              type: "voiture",
            ),
            const SizedBox(height: 12),
            _buildCategoryCard(
              context,
              "Services Additionnels 🧹",
              "Nettoyage, room service, et autres services",
              Icons.cleaning_services,
              const Color(0xFF264653),
              () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ListeItemsPage(type: "services"),
              )),
              type: "services",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title,
      String description, IconData icon, Color color, VoidCallback onTap,
      {String type = ''}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(description,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              // Badge dynamique du nb de dispo depuis Firestore
              _FirestoreCountBadge(type: type),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios,
                  size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // Mapping type → catégories Firestore
  static String _firestoreCatForType(String type) {
    switch (type) {
      case 'restaurant': return 'Restaurant';
      case 'voiture':    return 'Transport';
      default:           return ''; // services et vitrine = Spa+Loisirs+Chambre+Autre
    }
  }
}

// Badge nombre de services dispo dans Firestore pour cette catégorie
class _FirestoreCountBadge extends StatelessWidget {
  final String type;
  const _FirestoreCountBadge({required this.type});

  static const _primary = Color(0xFF9B4610);

  String get _cat {
    switch (type) {
      case 'restaurant': return 'Restaurant';
      case 'voiture':    return 'Transport';
      default:           return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cat.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('category', isEqualTo: _cat)
          .where('available', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '+$count nouveau${count > 1 ? 'x' : ''}',
            style: const TextStyle(
                fontSize: 10,
                color: _primary,
                fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page liste des items (fixe + Firestore fusionnés)
// ─────────────────────────────────────────────────────────────────────────────

class ListeItemsPage extends StatelessWidget {
  final String type;
  const ListeItemsPage({super.key, required this.type});

  static const _primary = Color(0xFF9B4610);

  // ── Items fixes selon le type ─────────────────────────────────────────────

  List<Map<String, dynamic>> get _fixedItems {
    switch (type) {
      case "restaurant":
        return [
          {"nom": "Poulet DG", "prix": 5000, "desc": "Plat camerounais délicieux avec poulet, plantain et légumes.", "img": "assets/images/restaurant/poulet_dg.webp", "categorie": "Plat Principal"},
          {"nom": "Poisson Braisé", "prix": 4000, "desc": "Poisson grillé accompagné de plantain et sauce piquante.", "img": "assets/images/restaurant/poisson_braise.webp", "categorie": "Plat Principal"},
          {"nom": "Ndolè", "prix": 3500, "desc": "Plat traditionnel aux feuilles de ndolè, crevettes, gambas et poisson.", "img": "assets/images/restaurant/ndole.jpeg", "categorie": "Plat Principal"},
          {"nom": "Soupe de Poisson", "prix": 3000, "desc": "Soupe traditionnelle à base de poisson frais et épices.", "img": "assets/images/restaurant/soupe_poisson.webp", "categorie": "Entrée"},
          {"nom": "Fruits Frais", "prix": 2000, "desc": "Assortiment de fruits de saison coupés et présentés.", "img": "assets/images/restaurant/fruits_frais.jpeg", "categorie": "Dessert"},
          {"nom": "Eau Minérale", "prix": 500, "desc": "Bouteille d'eau minérale 50cl.", "img": "assets/images/restaurant/eau_minerale.jpeg", "categorie": "Boissons"},
          {"nom": "Jus Naturel", "prix": 1000, "desc": "Jus de fruits pressés maison.", "img": "assets/images/restaurant/jus_naturel.webp", "categorie": "Boissons"},
          {"nom": "Soda", "prix": 800, "desc": "Canette de soda au choix.", "img": "assets/images/restaurant/soda.jpeg", "categorie": "Boissons"},
        ];
      case "vitrine":
        return [
          {"nom": "Parfum Dior", "prix": 25000, "desc": "Eau de parfum élégante et durable.", "img": "assets/images/vitrine/parfum.webp", "categorie": "Beauté"},
          {"nom": "Sac à Main Cuir", "prix": 15000, "desc": "Sac en cuir véritable de haute qualité.", "img": "assets/images/vitrine/sac.webp", "categorie": "Accessoires"},
          {"nom": "Art Local", "prix": 12000, "desc": "Œuvre d'art artisanale de la région.", "img": "assets/images/vitrine/art_local.jpg", "categorie": "Décoration"},
          {"nom": "Bijoux Traditionnels", "prix": 8000, "desc": "Bijoux artisanaux inspirés de la culture locale.", "img": "assets/images/vitrine/bijoux.webp", "categorie": "Accessoires"},
        ];
      case "voiture":
        return [
          {"nom": "Location Toyota Prado", "prix": 80000, "desc": "SUV confortable pour 7 passagers, avec chauffeur.", "img": "assets/images/voiture/toyota_prado.jpg", "categorie": "Location"},
          {"nom": "Mercedes Classe E", "prix": 120000, "desc": "Voiture de luxe avec tous les équipements premium.", "img": "assets/images/voiture/mercedes_classe_e.jpg", "categorie": "Location"},
          {"nom": "Transfert Aéroport", "prix": 15000, "desc": "Service de transfert vers/de l'aéroport.", "img": "assets/images/voiture/transfert_aeroport.jpg", "categorie": "Transport"},
          {"nom": "Tourisme Guidé", "prix": 50000, "desc": "Excursion d'une journée avec guide francophone.", "img": "assets/images/voiture/tourisme_guide.jpg", "categorie": "Tourisme"},
        ];
      case "services":
        return [
          {"nom": "Nettoyage Chambre", "prix": 5000, "desc": "Service de nettoyage complet de la chambre.", "img": "assets/images/services/nettoyage_chambre.jpg", "categorie": "Entretien"},
          {"nom": "Service en Chambre", "prix": 3000, "desc": "Service de repas directement dans votre chambre.", "img": "assets/images/services/room_service.jpg", "categorie": "Restauration"},
          {"nom": "Blanchisserie", "prix": 7000, "desc": "Service de lavage et repassage de vêtements.", "img": "assets/images/services/blanchisserie.jpg", "categorie": "Entretien"},
          {"nom": "Réveil Personnalisé", "prix": 1000, "desc": "Service de réveil téléphonique à l'heure demandée.", "img": "assets/images/services/reveil_personnalise.jpg", "categorie": "Service"},
        ];
      default:
        return [];
    }
  }

  // Catégories Firestore correspondant à ce type
  List<String> get _firestoreCategories {
    switch (type) {
      case 'restaurant': return ['Restaurant'];
      case 'voiture':    return ['Transport'];
      case 'vitrine':    return ['Autre'];
      case 'services':   return ['Spa', 'Loisirs', 'Chambre', 'Autre'];
      default:           return [];
    }
  }

  String get _pageTitle {
    switch (type) {
      case 'restaurant': return 'Menu Restaurant';
      case 'vitrine':    return 'Produits en Vitrine';
      case 'voiture':    return 'Services de Transport';
      case 'services':   return 'Services Additionnels';
      default:           return 'Articles';
    }
  }

  ImageProvider get _headerImage {
    switch (type) {
      case 'restaurant': return const AssetImage("assets/images/header_restaurant.jpg");
      case 'vitrine':    return const AssetImage("assets/images/header_vitrine.webp");
      case 'voiture':    return const AssetImage("assets/images/header_voiture.jpg");
      default:           return const AssetImage("assets/images/header_services.jpg");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grouper les items fixes par catégorie
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _fixedItems) {
      final cat = item['categorie'] as String;
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ Charge les services Firestore en temps réel
        stream: _firestoreCategories.isEmpty
            ? const Stream.empty()
            : FirebaseFirestore.instance
                .collection('services')
                .where('category', whereIn: _firestoreCategories)
                .where('available', isEqualTo: true)
                .snapshots(),
        builder: (ctx, snap) {
          // Convertir les docs Firestore en items compatibles
          final firestoreItems = <Map<String, dynamic>>[];
          if (snap.hasData) {
            for (final doc in snap.data!.docs) {
              final d = doc.data() as Map<String, dynamic>;
              firestoreItems.add({
                'nom': d['name'] ?? '',
                'prix': (d['price'] ?? 0) as num,
                'desc': d['description'] ?? '',
                'img': '',                          // pas d'asset local
                'imageUrl': d['imageUrl'] ?? '',    // ✅ URL Supabase
                // ✅ Utilise subcategory pour aller dans la bonne section
                'categorie': (d['subcategory'] as String?)?.isNotEmpty == true
                    ? d['subcategory'] as String
                    : '✨ Nouveautés',
                'firestoreId': doc.id,
              });
            }
          }

          // ✅ FIX : Distribuer chaque item Firestore dans son vrai groupe
          final Map<String, List<Map<String, dynamic>>> allGrouped =
              Map.from(grouped);
          for (final item in firestoreItems) {
            final cat = item['categorie'] as String;
            if (allGrouped.containsKey(cat)) {
              // Ajouter à une section existante (ex: "Boissons", "Plat Principal")
              allGrouped[cat] = [...allGrouped[cat]!, item];
            } else {
              // Nouvelle section (ex: "✨ Nouveautés" si pas de subcategory)
              allGrouped[cat] = [item];
            }
          }

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              // Image d'en-tête
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 120,
                  margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: _headerImage,
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    ),
                    color: _primary.withOpacity(0.2),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Indicateur chargement Firestore
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(color: _primary),
                ),

              // Sections groupées
              ...allGrouped.entries.map((entry) {
                // isNew = section non reconnue (sans subcategory défini)
              final isNew = entry.key == '✨ Nouveautés';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre de section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      child: Row(
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isNew
                                  ? Colors.deepOrange
                                  : _primary,
                            ),
                          ),
                          if (isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${entry.value.length} ajouté${entry.value.length > 1 ? 's' : ''} par l\'admin',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Items de la section
                    ...entry.value.map((item) => _ItemCard(item: item)),
                  ],
                );
              }).toList(),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte item (fixe ou Firestore)
// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemCard({required this.item});

  static const _primary = Color(0xFF9B4610);

  bool get _isFirestore => item.containsKey('firestoreId');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openFinaliser(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image ────────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: _buildImage(),
                ),
              ),
              const SizedBox(width: 10),

              // ── Détails ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['nom'] ?? '',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Badge "Nouveau" pour les items Firestore
                        if (_isFirestore)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['desc'] ?? '',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(item['prix'])} FCFA',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bouton panier ────────────────────────────────────────────
              IconButton(
                onPressed: () => _openFinaliser(context),
                icon: const Icon(Icons.add_shopping_cart,
                    color: _primary, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    // Item Firestore avec URL Supabase
    final imageUrl = item['imageUrl'] as String?;
    if (_isFirestore && imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF8F0E5),
            child: const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF9B4610), strokeWidth: 2),
            ),
          );
        },
      );
    }

    // Item fixe avec asset local
    final assetPath = item['img'] as String? ?? '';
    if (assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF8F0E5),
      child: const Center(
        child: Icon(Icons.restaurant_rounded,
            color: Color(0xFF9B4610), size: 28),
      ),
    );
  }

  void _openFinaliser(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinaliserCommandePage(item: item),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page finaliser la commande
// ─────────────────────────────────────────────────────────────────────────────

class FinaliserCommandePage extends StatefulWidget {
  final Map<String, dynamic> item;
  const FinaliserCommandePage({super.key, required this.item});

  @override
  State<FinaliserCommandePage> createState() =>
      _FinaliserCommandePageState();
}

class _FinaliserCommandePageState extends State<FinaliserCommandePage> {
  static const _primary = Color(0xFF9B4610);

  int quantite = 1;
  String instructions = "";
  bool _loading = false;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _notifications = FlutterLocalNotificationsPlugin();

  bool get _isFirestore => widget.item.containsKey('firestoreId');

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(settings);
  }

  Future<void> _enregistrerCommande() async {
    final user = _auth.currentUser;
    if (user == null) {
      _snack("Vous devez être connecté pour commander", Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      final total = quantite * (widget.item['prix'] as num);

      final commandeRef = await _firestore.collection('commandes').add({
        'userId': user.uid,
        'userEmail': user.email,
        'item': widget.item['nom'],
        'description': widget.item['desc'],
        'prixUnitaire': widget.item['prix'],
        'imageUrl': widget.item['imageUrl'] ?? widget.item['img'] ?? '',
        'quantite': quantite,
        'total': total,
        'instructions': instructions,
        'statut': 'en_attente',
        'date': FieldValue.serverTimestamp(),
        'type': 'commande',
        // Si c'est un service Firestore, on garde la référence
        if (_isFirestore) 'serviceId': widget.item['firestoreId'],
      });

      // Notification pour la réception
      await _firestore.collection('notifications').add({
        'titre': 'Nouvelle Commande',
        'message': '${user.email} a commandé : ${widget.item["nom"]}',
        'type': 'commande',
        'commandeId': commandeRef.id,
        'userId': user.uid,
        'statut': 'non_lu',
        'read': false,
        'date': FieldValue.serverTimestamp(),
      });

      // Notification locale
      await _notifications.show(
        0,
        'Commande Envoyée ✅',
        'Votre commande de ${widget.item["nom"]} a été envoyée',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id', 'Commandes',
            channelDescription: 'Notifications commandes',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );

      _snack("Commande envoyée avec succès !", Colors.green);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DetailsCommandePage(commandeId: commandeRef.id),
          ),
        );
      }
    } catch (e) {
      _snack("Erreur : $e", Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final total = quantite * (widget.item['prix'] as num);
    final imageUrl = widget.item['imageUrl'] as String?;
    final assetImg = widget.item['img'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Finaliser la commande"),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image du produit ─────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: _buildHeaderImage(imageUrl, assetImg),
              ),
            ),
            const SizedBox(height: 16),

            // ── Nom et description ────────────────────────────────────────
            Text(widget.item['nom'] ?? '',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(widget.item['desc'] ?? '',
                style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            const SizedBox(height: 16),

            // ── Prix unitaire ─────────────────────────────────────────────
            Text(
              'Prix unitaire : ${NumberFormat('#,###', 'fr_FR').format(widget.item['prix'])} FCFA',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // ── Quantité ─────────────────────────────────────────────────
            const Text("Quantité :",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (quantite > 1)
                      setState(() => quantite--);
                  },
                  icon: const Icon(Icons.remove_circle, size: 30),
                  color: _primary,
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("$quantite",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => setState(() => quantite++),
                  icon: const Icon(Icons.add_circle, size: 30),
                  color: _primary,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Instructions spéciales ────────────────────────────────────
            const Text("Instructions spéciales (optionnel) :",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => instructions = v,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Ex: Sans sel, à livrer à 19h...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Total ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total :",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '${NumberFormat('#,###', 'fr_FR').format(total)} FCFA',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Bouton confirmer ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _enregistrerCommande,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : const Text(
                        "Confirmer la commande",
                        style: TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderImage(String? imageUrl, String assetImg) {
    // URL Supabase (service Firestore)
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    // Asset local (item fixe)
    if (assetImg.isNotEmpty) {
      return Image.asset(
        assetImg,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF8F0E5),
      child: const Center(
        child: Icon(Icons.restaurant_rounded,
            size: 64, color: Color(0xFF9B4610)),
      ),
    );
  }
}