import 'package:flostay/pages/chat_admin_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


class ChatAdminList extends StatefulWidget {
  const ChatAdminList({Key? key}) : super(key: key);

  @override
  State<ChatAdminList> createState() => _ChatAdminListState();
}

class _ChatAdminListState extends State<ChatAdminList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: "Rechercher une conversation",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final chats = snapshot.data!.docs;

                if (chats.isEmpty) {
                  return const Center(
                    child: Text("Aucune conversation trouvée"),
                  );
                }

                final filteredChats = chats.where((chat) {
                  final data = chat.data() as Map<String, dynamic>;
                  final userEmail = data['userEmail'] ?? "";
                  return userEmail.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  );
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredChats[index].data() as Map<String, dynamic>;
                    final chatId = filteredChats[index].id;
                    final lastMessage = data['lastMessage'] ?? "";
                    final userEmail = data['userEmail'] ?? "";
                    final lastMessageTime = data['lastMessageTime'] != null
                        ? DateFormat('dd/MM HH:mm').format(
                            (data['lastMessageTime'] as Timestamp).toDate(),
                          )
                        : "";
                    final hasNewMessages = data['hasNewMessages'] ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: Colors.white,
                      elevation: 4,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF9B4610),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          userEmail,
                          style: const TextStyle(color: Colors.black),
                        ),
                        subtitle: Text(
                          lastMessage,
                          style: const TextStyle(color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lastMessageTime,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            if (hasNewMessages)
                              const Icon(
                                Icons.circle,
                                color: Colors.red,
                                size: 12,
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatAdminPage(
                                chatId: chatId,
                                userEmail: userEmail,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}