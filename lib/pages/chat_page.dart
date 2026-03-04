// ============================================================
// chat_page.dart
// Interface de chat client ↔ réception.
// Fonctionnalités : envoi de messages, indicateur "en train
// d'écrire", statut de lecture, horodatage, scroll auto.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  // ── Constantes de couleurs ───────────────────────────────────────────────
  static const _primary = Color(0xFF9B4610);
  static const _dark = Color(0xFF4A2A10);
  static const _bgLight = Color(0xFFF8F0E5);
  static const _msgUser = Color(0xFF9B4610);
  static const _msgReception = Color(0xFFEDE8E2);

  // ── Services ─────────────────────────────────────────────────────────────
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  // ── État ─────────────────────────────────────────────────────────────────
  late String _chatId;
  bool _isTyping = false; // L'utilisateur est-il en train de taper ?
  String? _clientProfileImage; // ✅ Photo de profil du client
  String _clientName = '';     // ✅ Nom du client

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatId = _user?.uid ?? 'default_chat';
    _initializeChat();
    _loadClientProfile(); // ✅ Charger photo profil
    _controller.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onTypingChanged);
    _controller.dispose();
    _scrollController.dispose();
    // Efface l'indicateur de frappe au quittage
    _setTypingStatus(false);
    super.dispose();
  }

  // ── Chargement profil client ─────────────────────────────────────────────

  Future<void> _loadClientProfile() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _clientProfileImage = data['profileImage'] as String?;
          _clientName = data['name'] ?? _user!.email?.split('@').first ?? '';
        });
        // Sauvegarde aussi la photo dans le document chat pour que la réception la voie
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId)
            .set({
          'clientProfileImage': data['profileImage'],
          'clientName': data['name'] ?? _user!.email,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // ── Initialisation du chat ───────────────────────────────────────────────

  Future<void> _initializeChat() async {
    final chatRef = _firestore.collection('chats').doc(_chatId);
    final doc = await chatRef.get();

    if (!doc.exists) {
      // Crée le document de chat s'il n'existe pas
      await chatRef.set({
        'userId': _user?.uid,
        'userEmail': _user?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasNewMessages': false,
        'isTypingClient': false,
        'isTypingReception': false,
      });
    }

    // Marque les messages comme lus côté client
    await chatRef.update({'hasNewMessages': false, 'clientUnread': 0});
  }

  // ── Indicateur de frappe ─────────────────────────────────────────────────

  void _onTypingChanged() {
    final isTyping = _controller.text.trim().isNotEmpty;
    if (isTyping != _isTyping) {
      _isTyping = isTyping;
      _setTypingStatus(isTyping);
    }
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    try {
      await _firestore.collection('chats').doc(_chatId).update({
        'isTypingClient': isTyping,
      });
    } catch (_) {}
  }

  // ── Envoi de message ─────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Vide le champ avant l'envoi pour un retour immédiat
    _controller.clear();
    _setTypingStatus(false);

    try {
      final batch = _firestore.batch();

      // Ajoute le message à la sous-collection
      final msgRef = _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc();

      batch.set(msgRef, {
        'senderId': _user?.uid,
        'senderEmail': _user?.email,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'sender': 'client',
      });

      // Met à jour le document de chat
      batch.update(_firestore.collection('chats').doc(_chatId), {
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasNewMessages': true,
        'receptionUnread': FieldValue.increment(1),
      });

      await batch.commit();

      // ✅ Créer notification pour la réception
      try {
        await _firestore.collection('notifications').add({
          'userId': 'reception',           // reçu par la réception
          'clientUid': _user?.uid ?? '',
          'clientEmail': _user?.email ?? '',
          'type': 'message',
          'title': 'Nouveau message',
          'message': '${_user?.email ?? 'Client'} : $text',
          'chatId': _chatId,
          'read': false,
          'status': 'unread',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {} // silencieux

      // Scroll vers le bas
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur d\'envoi : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Bandeau informatif
          _buildInfoBanner(),
          // Messages
          Expanded(
            child: _buildMessagesList(),
          ),
          // Indicateur "en train d'écrire" de la réception
          _buildReceptionTypingIndicator(),
          // Zone de saisie
          _buildInputArea(isWeb),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            radius: 18,
            child: const Icon(
                Icons.support_agent_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Réception FLOSTAY',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'En ligne',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  // ── Bandeau info ──────────────────────────────────────────────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _primary.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              size: 14, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Réponse en ~5 minutes • Disponible 8h–22h',
              style: TextStyle(
                  fontSize: 12, color: _primary.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Liste des messages ────────────────────────────────────────────────────

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(100) // Limite pour la performance
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        if (snapshot.hasError) {
          return _buildListError(snapshot.error.toString());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyChat();
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // Les nouveaux messages en bas
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final isMe = data['senderId'] == _user?.uid;
            final timestamp = data['timestamp'] as Timestamp?;

            // Vérifie si on doit afficher un séparateur de date
            final showDateSeparator = _shouldShowDate(docs, i);

            return Column(
              children: [
                if (showDateSeparator)
                  _buildDateSeparator(timestamp),
                _MessageBubble(
                  text: data['message'] ?? '',
                  isMe: isMe,
                  timestamp: timestamp,
                  isRead: data['read'] ?? false,
                  clientProfileImage: _clientProfileImage, // ✅
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Vérifie si un séparateur de date est nécessaire
  bool _shouldShowDate(List<QueryDocumentSnapshot> docs, int i) {
    if (i == docs.length - 1) return true; // Premier message affiché (dernier de la liste)
    final current =
        (docs[i].data() as Map)['timestamp'] as Timestamp?;
    final next =
        (docs[i + 1].data() as Map)['timestamp'] as Timestamp?;
    if (current == null || next == null) return false;
    final d1 = current.toDate();
    final d2 = next.toDate();
    return !DateUtils.isSameDay(d1, d2);
  }

  Widget _buildDateSeparator(Timestamp? ts) {
    if (ts == null) return const SizedBox.shrink();
    final date = ts.toDate();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (DateUtils.isSameDay(date, today)) {
      label = "Aujourd'hui";
    } else if (DateUtils.isSameDay(date, yesterday)) {
      label = 'Hier';
    } else {
      label = DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  // ── Indicateur de frappe réception ───────────────────────────────────────

  Widget _buildReceptionTypingIndicator() {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          _firestore.collection('chats').doc(_chatId).snapshots(),
      builder: (ctx, snap) {
        final isTyping =
            (snap.data?.data() as Map?)?['isTypingReception'] == true;
        if (!isTyping) return const SizedBox.shrink();

        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: _primary,
                child: Icon(Icons.support_agent_rounded,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _msgReception,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const _TypingDots(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Zone de saisie ────────────────────────────────────────────────────────

  Widget _buildInputArea(bool isWeb) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5F0),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8DDD5)),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Écrivez un message…',
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton envoyer
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _controller.text.trim().isNotEmpty
                  ? _primary
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.send_rounded,
                size: 20,
                color: _controller.text.trim().isNotEmpty
                    ? Colors.white
                    : Colors.grey.shade500,
              ),
              onPressed: _controller.text.trim().isNotEmpty
                  ? _sendMessage
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets utilitaires ───────────────────────────────────────────────────

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Démarrez la conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posez vos questions à notre équipe\nde réception',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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
            const Text(
              'Impossible de charger les messages',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _primary, size: 22),
            SizedBox(width: 8),
            Text('À propos du chat', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'Ce chat vous permet de communiquer directement avec '
          'notre équipe de réception.\n\n'
          '⏰ Disponible : 8h – 22h\n'
          '⚡ Temps de réponse : ~5 minutes\n\n'
          'Pour les urgences, contactez directement la réception.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

// ── Bulle de message ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Timestamp? timestamp;
  final bool isRead;
  final String? clientProfileImage; // ✅ Photo du client

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.isRead,
    this.clientProfileImage,
  });

  static const _primary = Color(0xFF9B4610);

  @override
  Widget build(BuildContext context) {
    final time = timestamp != null
        ? DateFormat('HH:mm').format(timestamp!.toDate())
        : '';

    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar réception
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _primary.withOpacity(0.1),
              child: const Icon(
                  Icons.support_agent_rounded,
                  size: 16,
                  color: _primary),
            ),
            const SizedBox(width: 6),
          ],
          // Bulle
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? _primary
                        : const Color(0xFFEDE8E2),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500),
                    ),
                    // Icône lu/envoyé pour les messages de l'utilisateur
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      Icon(
                        isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 12,
                        color: isRead
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Avatar utilisateur (avec vraie photo si disponible)
          if (isMe) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor: _primary.withOpacity(0.15),
              backgroundImage: clientProfileImage != null
                  ? NetworkImage(clientProfileImage!)
                  : null,
              child: clientProfileImage == null
                  ? const Icon(Icons.person_rounded,
                      size: 16, color: _primary)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Animation points de frappe ────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      final anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
      _controllers.add(ctrl);
      _animations.add(anim);

      // Délai décalé pour chaque point
      Future.delayed(Duration(milliseconds: i * 130), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 7,
            height: 7,
            transform: Matrix4.translationValues(
                0, _animations[i].value, 0),
            decoration: BoxDecoration(
              color: Colors.grey.shade500,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}