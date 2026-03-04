import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flostay/pages/reservation_form.dart';

class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});

  // ✅ Tes chambres originales — INCHANGÉES
  final List<Map<String, dynamic>> rooms = const [
    {
      "title": "Chambre premium",
      "price": 48580,
      "image": "assets/images/premium.jpg",
      "description": "Idéale pour les courts séjours. Lit double, WiFi, salle de bain privée , Petit dejeuner et taxe de sejour inclus.",
      "features": ["Lit double", "Climatisation", "Wi-Fi", "Télévision"],
    },
    {
      "title": "Chambre Prestige",
      "price": 58580,
      "image": "assets/images/prestige.jpg",
      "description": "Spacieuse et confortable avec balcon privé et vue sur la ville, Petit dejeuner et taxe de sejour inclus.",
      "features": ["Lit Queen", "Balcon", "Wi-Fi", "Petit déjeuner inclus"],
    },
    {
      "title": "Chambre Deluxe",
      "price": 78580,
      "image": "assets/images/deluxe.jpg",
      "description": "Espace de vie séparé avec coin salon et équipements haut de gamme , Petit dejeuner et taxe de sejour inclus.",
      "features": ["Salon séparé", "Jacuzzi", "Service VIP", "Vue panoramique"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chambres Disponibles"),
        centerTitle: true,
        backgroundColor: const Color(0xFF9B4610),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F0E5), Color(0xFFFDF8F3)],
          ),
        ),
        // ✅ StreamBuilder pour récupérer les chambres admin en plus
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chambres')
              .where('disponible', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            // Chambres admin depuis Firestore
            final firestoreRooms = <Map<String, dynamic>>[];
            if (snap.hasData) {
              for (final doc in snap.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                firestoreRooms.add({
                  "title": d['nom'] ?? d['type'] ?? 'Chambre',
                  "price": (d['prix'] ?? 0) as num,
                  "imageUrl": d['imageUrl'] ?? '',  // URL Supabase
                  "image": '',                       // pas d'asset local
                  "description": d['description'] ?? '',
                  "features": (d['equipements'] as List?)?.cast<String>() ?? [],
                });
              }
            }

            // ✅ Tes chambres originales + nouvelles chambres admin
            final allRooms = [...rooms, ...firestoreRooms];

            return isWeb
                ? _buildWebLayout(context, allRooms)
                : _buildMobileLayout(context, allRooms);
          },
        ),
      ),
    );
  }

  // ── Exactement ton layout web original, juste allRooms en paramètre ──────
  Widget _buildWebLayout(BuildContext context, List<Map<String, dynamic>> allRooms) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Nos Chambres et Suites",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A2A10))),
          const SizedBox(height: 8),
          const Text("Découvrez notre sélection de chambres confortables et élégantes",
              style: TextStyle(fontSize: 16, color: Color(0xFF6D5D4F))),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.5,
              ),
              itemCount: allRooms.length,
              itemBuilder: (context, index) => _buildRoomCard(context, allRooms[index], true),
            ),
          ),
        ],
      ),
    );
  }

  // ── Exactement ton layout mobile original ────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, List<Map<String, dynamic>> allRooms) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allRooms.length,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: _buildRoomCard(context, allRooms[index], false),
      ),
    );
  }

  // ── Exactement ta carte originale — juste image réseau ajoutée ────────────
  Widget _buildRoomCard(BuildContext context, Map<String, dynamic> room, bool isWeb) {
    final imageUrl = room['imageUrl'] as String? ?? '';
    final imageAsset = room['image'] as String? ?? '';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                // ✅ Si URL Supabase → Image.network, sinon → Image.asset (original)
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: isWeb ? 220 : 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, prog) =>
                            prog == null ? child : _placeholder(isWeb),
                        errorBuilder: (_, __, ___) => _placeholder(isWeb),
                      )
                    : Image.asset(
                        imageAsset,
                        height: isWeb ? 220 : 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B4610).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${room["price"]} FCFA / nuit",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          // Infos — identiques à l'original
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room["title"],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4A2A10))),
                const SizedBox(height: 8),
                Text(room["description"],
                    style: const TextStyle(color: Color(0xFF6D5D4F), fontSize: 14, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: List.generate(
                    (room["features"] as List).length,
                    (i) => Chip(
                      label: Text(room["features"][i],
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9B4610))),
                      backgroundColor: const Color(0xFFF8E9DD),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservationFormPage(
                          roomTitle: room["title"] as String,
                          roomPrice: (room["price"] as num).toInt(),
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF9B4610),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Réserver maintenant",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(bool isWeb) {
    return Container(
      width: double.infinity,
      height: isWeb ? 220 : 180,
      color: const Color(0xFF9B4610).withOpacity(0.08),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_rounded, size: 48, color: Color(0xFF9B4610)),
          SizedBox(height: 6),
          Text('Chambre', style: TextStyle(color: Color(0xFF9B4610), fontSize: 12)),
        ],
      ),
    );
  }
}