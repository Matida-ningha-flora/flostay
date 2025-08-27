import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  late String chatId;

  // Palette de couleurs avec #9B4610 comme couleur principale
  final Color _primaryColor = const Color(0xFF9B4610);
  final Color _secondaryColor = const Color(0xFFE27D35);
  final Color _accentColor = const Color(0xFFF4A261);
  final Color _backgroundColor = const Color(0xFFF8F4E9);
  final Color _receptionMessageColor = const Color(0xFFE8E2D6);
  final Color _userMessageColor = const Color(0xFF9B4610);
  final Color _textColorLight = Colors.white;
  final Color _textColorDark = const Color(0xFF3A3A3A);
  final Color _hintColor = const Color(0xFF8A8A8A);
  final Color _timeColor = const Color(0xFF6B6B6B);
  final Color _infoBackgroundColor = const Color(0xFFF1E6D9);

  @override
  void initState() {
    super.initState();
    // Utilisation de l'UID de l'utilisateur comme ID de conversation
    chatId = user?.uid ?? "default_chat";
    _initializeChat();
  }

  void _initializeChat() async {
    // Créer le document chat s'il n'existe pas déjà
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final doc = await chatDoc.get();
    
    if (!doc.exists) {
      await chatDoc.set({
        'userId': user?.uid,
        'userEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }
  }

  void sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    
    final message = _controller.text.trim();
    
    // Ajouter le message à la sous-collection
    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': user?.uid,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'senderEmail': user?.email,
    }).then((_) {
      // Mettre à jour le document chat avec le dernier message
      FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      
      // Faire défiler vers le bas après l'envoi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
    
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat avec la réception"),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: _textColorLight,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("À propos du chat"),
                  content: const Text(
                    "Ce chat vous permet de communiquer directement avec notre équipe de réception. "
                    "Nous répondons généralement dans les 5 minutes pendant nos heures d'ouverture (8h-22h).",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("OK", style: TextStyle(color: _primaryColor)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryColor.withOpacity(0.08),
              _backgroundColor,
            ],
          ),
        ),
        child: Column(
          children: [
            // En-tête informatif
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: _infoBackgroundColor,
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Notre équipe répond généralement dans les 5 minutes",
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Liste des messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: _primaryColor,
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 50, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            "Erreur: ${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textColorDark),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 80, color: _hintColor),
                          const SizedBox(height: 16),
                          Text(
                            "Aucun message",
                            style: TextStyle(
                              fontSize: 18,
                              color: _hintColor,
                            ),
                          ),
                          Text(
                            "Envoyez votre premier message à la réception",
                            style: TextStyle(color: _hintColor),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == user?.uid;
                      final timestamp = data['timestamp'] as Timestamp?;
                      final time = timestamp != null
                          ? DateFormat.Hm().format(timestamp.toDate())
                          : '';
                      final sender = isMe ? "Vous" : "Réception";

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(docs[index].id),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                CircleAvatar(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: _textColorLight,
                                  child: Icon(Icons.support_agent, size: 20),
                                ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sender,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isMe 
                                            ? _primaryColor 
                                            : _textColorDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? _userMessageColor
                                            : _receptionMessageColor,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: isMe
                                              ? const Radius.circular(20)
                                              : const Radius.circular(4),
                                          bottomRight: isMe
                                              ? const Radius.circular(4)
                                              : const Radius.circular(20),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        data['message'],
                                        style: TextStyle(
                                          color: isMe
                                              ? _textColorLight
                                              : _textColorDark,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Text(
                                        time,
                                        style: TextStyle(
                                          color: _timeColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: _secondaryColor,
                                  foregroundColor: _textColorLight,
                                  child: Icon(Icons.person, size: 20),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Zone de saisie
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _receptionMessageColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Écrire un message...",
                          hintStyle: TextStyle(color: _hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close, color: _hintColor),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => setState(() {}),
                        onSubmitted: (value) => sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _controller.text.trim().isNotEmpty
                          ? _primaryColor
                          : const Color(0xFFD3D3D3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send,
                          color: _controller.text.trim().isNotEmpty
                              ? _textColorLight
                              : const Color(0xFF8A8A8A)),
                      onPressed: _controller.text.trim().isNotEmpty
                          ? sendMessage
                          : null,
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
}