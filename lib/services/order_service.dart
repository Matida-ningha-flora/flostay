import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addOrder({
    required String type,
    required String name,
    required double price,
    required String description,
    required String imageUrl,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("Utilisateur non connecté !");
    }

    await _db.collection("orders").add({
      "userId": user.uid,
      "type": type, // Restaurant, Produit, Voiture
      "name": name,
      "price": price,
      "description": description,
      "imageUrl": imageUrl,
      "status": "En attente",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
