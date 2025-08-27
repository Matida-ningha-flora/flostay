import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        throw FirebaseAuthException(
          code: 'empty-fields',
          message: 'Tous les champs sont requis',
        );
      }

      if (password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Le mot de passe doit contenir au moins 6 caractères',
        );
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await _firestore.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "email": email,
          "name": name,
          "role": "client",
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'registration-failed',
        message: 'Erreur lors de l\'inscription: $e',
      );
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Erreur lors de la connexion: $e',
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(uid).get();

      if (userDoc.exists) {
        Map<String, dynamic> data =
            userDoc.data() as Map<String, dynamic>? ?? {};
        return data["role"] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<Map<String, dynamic>> getUserData(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(uid).get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection("users")
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Erreur lors de la mise à jour du profil: $e");
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception("Erreur lors de la réinitialisation du mot de passe: $e");
    }
  }

  Future<User?> createUserWithRole({
    required String email,
    required String password,
    required String name,
    required String role,
    required String currentUserId,
  }) async {
    try {
      String? currentUserRole = await getUserRole(currentUserId);
      if (currentUserRole != "admin") {
        throw Exception("Seuls les administrateurs peuvent créer des comptes avec des rôles spécifiques");
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await _firestore.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "email": email,
          "name": name,
          "role": role,
          "createdBy": currentUserId,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception("Erreur lors de la création du compte: $e");
    }
  }
}