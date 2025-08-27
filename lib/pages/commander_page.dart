import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flostay/pages/details_commande_page.dart';

class CommanderPage extends StatelessWidget {
  const CommanderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Commandes et Services"),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
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
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ListeItemsPage(type: "restaurant")),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildCategoryCard(
              context,
              "Produit Vitrine 🛍️",
              "Découvrez nos produits exclusifs en vitrine",
              Icons.shopping_bag,
              const Color(0xFF2A9D8F),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ListeItemsPage(type: "vitrine")),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildCategoryCard(
              context,
              "Service Voiture 🚗",
              "Réservez un service de transport ou location",
              Icons.directions_car,
              const Color(0xFFE76F51),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ListeItemsPage(type: "voiture")),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildCategoryCard(
              context,
              "Services Additionnels 🧹",
              "Nettoyage, room service, et autres services",
              Icons.cleaning_services,
              const Color(0xFF264653),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ListeItemsPage(type: "services")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, String description, IconData icon, Color color, VoidCallback onTap) {
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class ListeItemsPage extends StatelessWidget {
  final String type;
  const ListeItemsPage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    String title;
    List<Map<String, dynamic>> items;

    switch (type) {
      case "restaurant":
        title = "Menu Restaurant";
        items = [
          {"nom": "Poulet DG", "prix": 5000, "desc": "Plat camerounais délicieux avec poulet, plantain et légumes.", "img": "assets/images/restaurant/poulet_dg.webp", "categorie": "Plat Principal"},
          {"nom": "Poisson Braisé", "prix": 4000, "desc": "Poisson grillé accompagné de plantain et sauce piquante.", "img": "assets/images/restaurant/poisson_braise.webp", "categorie": "Plat Principal"},
          {"nom": "Ndolè", "prix": 3500, "desc": "Plat traditionnel aux feuilles de ndolè, crevettes ,gambase et poisson.", "img": "assets/images/restaurant/ndole.jpeg", "categorie": "Plat Principal"},
          {"nom": "Soupe de Poisson", "prix": 3000, "desc": "Soupe traditionnelle à base de poisson frais et épices.", "img": "assets/images/restaurant/soupe_poisson.webp", "categorie": "Entrée"},
          {"nom": "Fruits Frais", "prix": 2000, "desc": "Assortiment de fruits de saison coupés et présentés.", "img": "assets/images/restaurant/fruits_frais.jpeg", "categorie": "Dessert"},
          {"nom": "Eau Minérale", "prix": 500, "desc": "Bouteille d'eau minérale 50cl.", "img": "assets/images/restaurant/eau_minerale.jpeg", "categorie": "Boissons"},
          {"nom": "Jus Naturel", "prix": 1000, "desc": "Jus de fruits pressés maison.", "img": "assets/images/restaurant/jus_naturel.webp", "categorie": "Boissons"},
          {"nom": "Soda", "prix": 800, "desc": "Canette de soda au choix.", "img": "assets/images/restaurant/soda.jpeg", "categorie": "Boissons"},
        ];
        break;
      case "vitrine":
        title = "Produits en Vitrine";
        items = [
          {"nom": "Parfum Dior", "prix": 25000, "desc": "Eau de parfum élégante et durable.", "img": "assets/images/vitrine/parfum.webp", "categorie": "Beauté"},
          {"nom": "Sac à Main Cuir", "prix": 15000, "desc": "Sac en africtude véritable de haute qualité.", "img": "assets/images/vitrine/sac.webp", "categorie": "Accessoires"},
          {"nom": "Art Local", "prix": 12000, "desc": "Œuvre d'art artisanale de la région.", "img": "assets/images/vitrine/art_local.jpg", "categorie": "Décoration"},
          {"nom": "Bijoux Traditionnels", "prix": 8000, "desc": "Bijoux artisanaux inspirés de la culture locale.", "img": "assets/images/vitrine/bijoux.webp", "categorie": "Accessoires"},
        ];
        break;
      case "voiture":
        title = "Services de Transport";
        items = [
          {"nom": "Location Toyota Prado", "prix": 80000, "desc": "SUV confortable pour 7 passagers, avec chauffeur.", "img": "assets/images/voiture/toyota_prado.jpg", "categorie": "Location"},
          {"nom": "Mercedes Classe E", "prix": 120000, "desc": "Voiture de luxe avec tous les équipements premium.", "img": "assets/images/voiture/mercedes_classe_e.jpg", "categorie": "Location"},
          {"nom": "Transfert Aéroport", "prix": 15000, "desc": "Service de transfert vers/de l'aéroport.", "img": "assets/images/voiture/transfert_aeroport.jpg", "categorie": "Transport"},
          {"nom": "Tourisme Guidé", "prix": 50000, "desc": "Excursion d'une journée avec guide francophone.", "img": "assets/images/voiture/tourisme_guide.jpg", "categorie": "Tourisme"},
        ];
        break;
      case "services":
        title = "Services Additionnels";
        items = [
          {"nom": "Nettoyage Chambre", "prix": 5000, "desc": "Service de nettoyage complet de la chambre.", "img": "assets/images/services/nettoyage_chambre.jpg", "categorie": "Entretien"},
          {"nom": "Service en Chambre", "prix": 3000, "desc": "Service de repas directement dans votre chambre.", "img": "assets/images/services/room_service.jpg", "categorie": "Restauration"},
          {"nom": "Blanchisserie", "prix": 7000, "desc": "Service de lavage et repassage de vêtements.", "img": "assets/images/services/blanchisserie.jpg", "categorie": "Entretien"},
          {"nom": "Réveil Personnalisé", "prix": 1000, "desc": "Service de réveil téléphonique à l'heure demandée.", "img": "assets/images/services/reveil_personnalise.jpg", "categorie": "Service"},
        ];
        break;
      default:
        title = "Produits";
        items = [];
    }

    // Grouper les éléments par catégorie
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (var item in items) {
      final category = item['categorie'];
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Image d'en-tête selon le type
          Container(
            height: 120,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: _getHeaderImage(type),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Liste des éléments groupés par catégorie
          ...groupedItems.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9B4610),
                    ),
                  ),
                ),
                ...entry.value.map((item) => _buildItemCard(context, item)).toList(),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  ImageProvider _getHeaderImage(String type) {
    switch (type) {
      case "restaurant":
        return const AssetImage("assets/images/header_restaurant.jpg");
      case "vitrine":
        return const AssetImage("assets/images/header_vitrine.webp");
      case "voiture":
        return const AssetImage("assets/images/header_voiture.jpg");
      case "services":
        return const AssetImage("assets/images/header_services.jpg");
      default:
        return const AssetImage("assets/images/header_default.jpg");
    }
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FinaliserCommandePage(item: item)),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du produit
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: AssetImage(item["img"]),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      // En cas d'erreur de chargement d'image
                    },
                  ),
                ),
                child: item["img"].toString().contains("assets/") 
                  ? null 
                  : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: 10),
              // Détails du produit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["nom"],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item["desc"],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${item["prix"]} FCFA",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9B4610),
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton de commande
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FinaliserCommandePage(item: item)),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart, color: Color(0xFF9B4610), size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinaliserCommandePage extends StatefulWidget {
  final Map<String, dynamic> item;
  const FinaliserCommandePage({super.key, required this.item});

  @override
  State<FinaliserCommandePage> createState() => _FinaliserCommandePageState();
}

class _FinaliserCommandePageState extends State<FinaliserCommandePage> {
  int quantite = 1;
  String instructions = "";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notifications.initialize(initializationSettings);
  }

  Future<void> _enregistrerCommande() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vous devez être connecté pour commander")),
        );
        return;
      }

      final total = quantite * widget.item["prix"];
      final commandeRef = await _firestore.collection('commandes').add({
        'userId': user.uid,
        'userEmail': user.email,
        'item': widget.item["nom"],
        'description': widget.item["desc"],
        'prixUnitaire': widget.item["prix"],
        'quantite': quantite,
        'total': total,
        'instructions': instructions,
        'statut': 'en_attente',
        'date': FieldValue.serverTimestamp(),
        'type': 'commande',
      });

      // Créer une notification pour la réception
      await _firestore.collection('notifications').add({
        'titre': 'Nouvelle Commande',
        'message': '${user.email} a commandé: ${widget.item["nom"]}',
        'type': 'commande',
        'commandeId': commandeRef.id,
        'userId': user.uid,
        'statut': 'non_lu',
        'date': FieldValue.serverTimestamp(),
      });

      // Afficher une notification locale
      await _showNotification();

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Commande envoyée avec succès!"),
          backgroundColor: Colors.green,
        ),
      );

      // Naviguer vers la page de détails
      try {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DetailsCommandePage(commandeId: commandeRef.id),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'enregistrement: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'channel_id',
      'Commandes',
      channelDescription: 'Notifications pour les nouvelles commandes',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _notifications.show(
      0,
      'Commande Envoyée',
      'Votre commande de ${widget.item["nom"]} a été envoyée à la réception',
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = quantite * widget.item["prix"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Finaliser la commande"),
        backgroundColor: const Color(0xFF9B4610),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec image
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: AssetImage(widget.item["img"]),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {
                    // Gestion d'erreur d'image
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nom et description
            Text(
              widget.item["nom"],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.item["desc"],
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Prix unitaire
            Text(
              "Prix unitaire: ${widget.item["prix"]} FCFA",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // Sélecteur de quantité
            const Text(
              "Quantité:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (quantite > 1) setState(() => quantite--);
                  },
                  icon: const Icon(Icons.remove_circle, size: 28),
                  color: const Color(0xFF9B4610),
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$quantite",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => quantite++);
                  },
                  icon: const Icon(Icons.add_circle, size: 28),
                  color: const Color(0xFF9B4610),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Instructions spéciales
            const Text(
              "Instructions spéciales (optionnel):",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => instructions = value,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Ex: Sans sel, à livrer à 19h...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),

            // Total
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "$total FCFA",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9B4610),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bouton de confirmation
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _enregistrerCommande,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B4610),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Confirmer la commande",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}