// ============================================================
// alert_page.dart
// Gestion des alertes : le client soumet une alerte,
// la réception / l'admin peut y répondre et la résoudre.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage>
    with SingleTickerProviderStateMixin {
  // ── Couleurs ─────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);

  // ── Services ──────────────────────────────────────────────────────────────
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── État ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isStaff = false; // admin ou réceptionniste
  String? _userId;
  String? _userName;

  // Formulaire de soumission d'alerte
  final _messageController = TextEditingController();
  String _selectedType = 'proprete';
  bool _isSubmitting = false;

  // Onglets
  late TabController _tabController;

  // Types d'alertes
  static const _alertTypes = {
    'urgence': ('Urgence', Icons.emergency_rounded, Colors.red),
    'proprete': ('Propreté', Icons.cleaning_services_rounded, Colors.orange),
    'technique': ('Technique', Icons.build_rounded, Colors.blue),
    'securite': ('Sécurité', Icons.security_rounded, Colors.purple),
    'autre': ('Autre', Icons.more_horiz_rounded, Colors.grey),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ── Chargement des infos utilisateur ─────────────────────────────────────

  Future<void> _loadUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      _userId = user.uid;

      final doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final role = data['role'] ?? 'client';
        setState(() {
          _isStaff = role == 'admin' || role == 'receptionist';
          _userName = data['name'] ?? user.email?.split('@').first ?? 'Utilisateur';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── Soumission d'une alerte (client) ─────────────────────────────────────

  Future<void> _submitAlert() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      _showSnack('Veuillez décrire votre problème.', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Récupère la chambre actuelle du client si disponible
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userRoom =
          userDoc.data()?['currentRoom'] ?? 'Non spécifiée';

      final typeInfo = _alertTypes[_selectedType]!;

      // Enregistre l'alerte dans Firestore
      final alertRef = await _firestore.collection('alerts').add({
        'userId': user.uid,
        'userEmail': user.email,
        'userName': _userName,
        'userRoom': userRoom,
        'alertType': _selectedType,
        'alertTypeLabel': typeInfo.$1,
        'message': msg,
        'status': 'new',
        'priority':
            _selectedType == 'urgence' ? 'high' : 'normal',
        'responses': [],
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notification push pour le staff (collection notifications)
      await _firestore.collection('notifications').add({
        'type': 'alert',
        'alertId': alertRef.id,
        'title': 'Alerte : ${typeInfo.$1}',
        'message':
            '$_userName (Chambre $userRoom) : $msg',
        'priority':
            _selectedType == 'urgence' ? 'high' : 'normal',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _messageController.clear();
      _showSnack('Alerte envoyée ! Nous intervenons au plus vite.', Colors.green);

      // Passe à l'onglet "Mes alertes"
      _tabController.animateTo(1);
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: _primary)),
      );
    }

    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(_isStaff ? 'Gestion des alertes' : 'Mes alertes'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: _isStaff
            ? null // Le staff voit juste la liste
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(text: 'Nouvelle alerte'),
                  Tab(text: 'Mes alertes'),
                ],
              ),
      ),
      body: _isStaff
          ? _buildStaffView(isWeb)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildClientForm(isWeb),
                _buildAlertsList(isStaff: false),
              ],
            ),
    );
  }

  // ── Vue staff ─────────────────────────────────────────────────────────────

  Widget _buildStaffView(bool isWeb) {
    return Column(
      children: [
        // Filtres rapides
        _buildStaffFilters(),
        Expanded(child: _buildAlertsList(isStaff: true)),
      ],
    );
  }

  // Filtre par statut pour le staff
  String _staffFilter = 'all';

  Widget _buildStaffFilters() {
    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in [
              ('all', 'Toutes', null),
              ('new', 'Nouvelles', Colors.red),
              ('in_progress', 'En cours', Colors.orange),
              ('resolved', 'Résolues', Colors.green),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f.$2),
                  selected: _staffFilter == f.$1,
                  onSelected: (_) =>
                      setState(() => _staffFilter = f.$1),
                  selectedColor: f.$3 ?? _primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _staffFilter == f.$1
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Formulaire client ─────────────────────────────────────────────────────

  Widget _buildClientForm(bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _dark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Signaler un problème',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Notre équipe intervient au plus vite',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sélection du type
              const Text(
                'Type de problème',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _dark,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _alertTypes.entries.map((entry) {
                  final isSelected = _selectedType == entry.key;
                  final info = entry.value;
                  return ChoiceChip(
                    avatar: Icon(info.$2,
                        size: 16,
                        color: isSelected ? Colors.white : info.$3),
                    label: Text(info.$1),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedType = entry.key),
                    selectedColor: info.$3,
                    backgroundColor: info.$3.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color:
                          isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Description du problème',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _dark,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                maxLines: 5,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText:
                      'Décrivez le problème en détail…',
                  hintStyle:
                      TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: _primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),

              // Bouton envoyer
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitAlert,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'Envoi en cours…'
                        : 'Envoyer l\'alerte',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Liste des alertes ─────────────────────────────────────────────────────

  Widget _buildAlertsList({required bool isStaff}) {
    // Construit la requête selon le rôle
    Query query = _firestore
        .collection('alerts')
        .orderBy('timestamp', descending: true);

    if (!isStaff) {
      // Client : voit uniquement ses propres alertes
      query = query.where('userId', isEqualTo: _userId);
    } else if (_staffFilter != 'all') {
      // Staff : filtre par statut
      query = query.where('status', isEqualTo: _staffFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }
        if (snapshot.hasError) {
          return _buildListError(snapshot.error.toString());
        }

        final alerts = snapshot.data?.docs ?? [];

        if (alerts.isEmpty) {
          return _buildEmptyList(isStaff);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: alerts.length,
          itemBuilder: (ctx, i) {
            final data = alerts[i].data() as Map<String, dynamic>;
            return _AlertCard(
              alertId: alerts[i].id,
              data: data,
              isStaff: isStaff,
              onUpdate: () {}, // Le StreamBuilder se rechargera automatiquement
            );
          },
        );
      },
    );
  }

  // ── Widgets d'état ────────────────────────────────────────────────────────

  Widget _buildEmptyList(bool isStaff) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isStaff
                ? 'Aucune alerte pour le moment'
                : 'Vous n\'avez aucune alerte',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte d'alerte ────────────────────────────────────────────────────────────

class _AlertCard extends StatefulWidget {
  final String alertId;
  final Map<String, dynamic> data;
  final bool isStaff;
  final VoidCallback onUpdate;

  const _AlertCard({
    required this.alertId,
    required this.data,
    required this.isStaff,
    required this.onUpdate,
  });

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);

  final _responseController = TextEditingController();
  bool _isUpdating = false;
  bool _showResponseField = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  // Mise à jour du statut de l'alerte
  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('alerts')
          .doc(widget.alertId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.email ?? 'Staff',
        if (status == 'resolved')
          'resolvedAt': FieldValue.serverTimestamp(),
      });
      _showSnack(
        status == 'resolved'
            ? 'Alerte marquée comme résolue'
            : 'Statut mis à jour',
        Colors.green,
      );
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // Envoi d'une réponse du staff
  Future<void> _sendResponse() async {
    final msg = _responseController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      final staffName =
          userDoc.data()?['name'] ?? user?.email ?? 'Staff';

      await FirebaseFirestore.instance
          .collection('alerts')
          .doc(widget.alertId)
          .update({
        'responses': FieldValue.arrayUnion([
          {
            'staffId': user?.uid,
            'staffName': staffName,
            'message': msg,
            'timestamp': Timestamp.now(),
          }
        ]),
        'status': 'in_progress',
        'assignedTo': user?.uid,
        'assignedToName': staffName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notifie le client
      if (widget.data['userId'] != null) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
          'type': 'alert_response',
          'userId': widget.data['userId'],
          'title': 'Réponse à votre alerte',
          'message': '$staffName a répondu : $msg',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      _responseController.clear();
      setState(() => _showResponseField = false);
      _showSnack('Réponse envoyée', Colors.green);
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // Couleur et label selon le statut
  (Color, String) _statusStyle(String status) {
    switch (status) {
      case 'new':
        return (Colors.red, 'Nouveau');
      case 'in_progress':
        return (Colors.orange, 'En cours');
      case 'resolved':
        return (Colors.green, 'Résolu');
      default:
        return (Colors.grey, 'Inconnu');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = data['status'] ?? 'new';
    final alertType = data['alertType'] ?? 'autre';
    final typeInfo = _AlertPageState._alertTypes[alertType] ??
        ('Autre', Icons.more_horiz_rounded, Colors.grey);
    final timestamp = data['timestamp'] as Timestamp?;
    final timeStr = timestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
        : 'Date inconnue';
    final responses =
        List<Map<String, dynamic>>.from(data['responses'] ?? []);

    final (statusColor, statusLabel) = _statusStyle(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeInfo.$3.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(typeInfo.$2, size: 18, color: typeInfo.$3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeInfo.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _dark,
                        ),
                      ),
                      if (widget.isStaff)
                        Text(
                          '${data['userName'] ?? 'Client'} • Chambre ${data['userRoom'] ?? '?'}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                // Badge statut
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Corps ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message
                Text(
                  data['message'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 8),
                // Heure
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),

                // ── Réponses existantes ────────────────────────────────
                if (responses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text(
                    'Réponses',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...responses.map(
                    (r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.support_agent_rounded,
                              size: 16, color: _primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['staffName'] ?? 'Staff',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: _primary,
                                  ),
                                ),
                                Text(
                                  r['message'] ?? '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Actions staff ──────────────────────────────────────
                if (widget.isStaff && !_isUpdating) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Champ de réponse
                  if (_showResponseField) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _responseController,
                            decoration: InputDecoration(
                              hintText: 'Votre réponse…',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sendResponse,
                          icon: const Icon(Icons.send_rounded,
                              color: _primary),
                          tooltip: 'Envoyer',
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _showResponseField = false),
                          icon: Icon(Icons.close_rounded,
                              color: Colors.grey[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Boutons d'action
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Répondre
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _showResponseField = true),
                        icon: const Icon(Icons.reply_rounded, size: 15),
                        label: const Text('Répondre'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: const BorderSide(color: _primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      // Prendre en charge
                      if (status == 'new')
                        ElevatedButton.icon(
                          onPressed: () =>
                              _updateStatus('in_progress'),
                          icon: const Icon(Icons.play_arrow_rounded,
                              size: 15),
                          label: const Text('Prendre en charge'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      // Résoudre
                      if (status == 'in_progress')
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus('resolved'),
                          icon: const Icon(Icons.check_circle_rounded,
                              size: 15),
                          label: const Text('Marquer résolu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      // Rouvrir si déjà résolu
                      if (status == 'resolved')
                        OutlinedButton.icon(
                          onPressed: () =>
                              _updateStatus('in_progress'),
                          icon: const Icon(Icons.refresh_rounded,
                              size: 15),
                          label: const Text('Rouvrir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(
                                color: Colors.orange),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],

                if (_isUpdating)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}