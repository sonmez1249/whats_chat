import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'group_details_page.dart';

class ChatPage extends StatefulWidget {
  final String userName;
  const ChatPage({super.key, required this.userName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  // Seçili mesajları tutmak için
  final Set<String> _selectedMessages = {};
  bool _isSelectionMode = false;

  Future<void> _sendMessage(String chatId) async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final isGroup = chatData['isGroup'] ?? false;
      final members = List<String>.from(chatData['members'] ?? []);
      final leftMembers = List<String>.from(chatData['leftMembers'] ?? []);

      // Eğer gruptan çıkmışsa veya üye değilse mesaj gönderemesin
      if (isGroup && !members.contains(currentUser?.email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu gruba artık mesaj gönderemezsiniz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': _messageController.text.trim(),
        'senderId': currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
        'isGroup': isGroup,
      });

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    }
  }

  // Mesaj silme dialog'unu göster
  Future<void> _showDeleteDialog(String chatId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Mesaj silinsin mi?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Mesajları silmek istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteMessages(chatId);
    }
  }

  // Mesajları sil
  Future<void> _deleteMessages(String chatId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var messageId in _selectedMessages) {
        final messageRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId);

        batch.delete(messageRef);
      }

      await batch.commit();

      setState(() {
        _selectedMessages.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesajlar silinemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    final chatId = arguments['chatId'] as String;
    final userEmail = arguments['userEmail'] as String;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedMessages.clear();
                    _isSelectionMode = false;
                  });
                },
              )
            : null,
        title: _isSelectionMode
            ? Text('${_selectedMessages.length} seçildi')
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .snapshots(),
                builder: (context, chatSnapshot) {
                  if (!chatSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final chatData =
                      chatSnapshot.data!.data() as Map<String, dynamic>;
                  final isGroup = chatData['isGroup'] ?? false;
                  final chatName = isGroup ? chatData['chatName'] : userEmail;

                  return GestureDetector(
                    onTap: () {
                      if (isGroup) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupDetailsPage(
                              chatId: chatId,
                              groupName: chatData['chatName'],
                              members:
                                  List<String>.from(chatData['members'] ?? []),
                              createdBy: chatData['createdBy'],
                            ),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(Icons.group, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chatName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${chatData['members']?.length ?? 0} üye',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteDialog(chatId),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .snapshots(),
              builder: (context, chatSnapshot) {
                if (!chatSnapshot.hasData) {
                  return const SizedBox();
                }

                final chatData =
                    chatSnapshot.data!.data() as Map<String, dynamic>;
                final isGroupChat = chatData['isGroup'] ?? false;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Hata: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Henüz mesaj yok'));
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final message = snapshot.data!.docs[index];
                        final data = message.data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == currentUser?.email;
                        final isDeleted = (data['deletedFor'] ?? [])
                            .contains(currentUser?.email);

                        // Silinmiş mesajları gösterme
                        if (isDeleted) return const SizedBox();

                        return GestureDetector(
                          onLongPress: () {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedMessages.add(message.id);
                            });
                          },
                          onTap: _isSelectionMode
                              ? () {
                                  setState(() {
                                    if (_selectedMessages
                                        .contains(message.id)) {
                                      _selectedMessages.remove(message.id);
                                      if (_selectedMessages.isEmpty) {
                                        _isSelectionMode = false;
                                      }
                                    } else {
                                      _selectedMessages.add(message.id);
                                    }
                                  });
                                }
                              : null,
                          child: Container(
                            color: _selectedMessages.contains(message.id)
                                ? Colors.blue.withOpacity(0.2)
                                : null,
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe && isGroupChat) ...[
                                      FutureBuilder<QuerySnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .where('email',
                                                isEqualTo: data['senderId'])
                                            .get(),
                                        builder: (context, userSnapshot) {
                                          if (userSnapshot.hasData &&
                                              userSnapshot.data != null &&
                                              userSnapshot
                                                  .data!.docs.isNotEmpty) {
                                            final userData = userSnapshot
                                                .data!.docs.first
                                                .data() as Map<String, dynamic>;
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .primaryColor
                                                          .withOpacity(0.5),
                                                  child: Text(
                                                    (userData['userName'] ??
                                                            data['senderId'])[0]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  userData['userName'] ??
                                                      data['senderId'],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircleAvatar(
                                                radius: 10,
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .primaryColor
                                                        .withOpacity(0.5),
                                                child: Text(
                                                  (data['senderId'] ?? '')[0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                data['senderId'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color:
                                            isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['timestamp'] != null
                                          ? '${(data['timestamp'] as Timestamp).toDate().hour}:${(data['timestamp'] as Timestamp).toDate().minute.toString().padLeft(2, '0')}'
                                          : '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yazın...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: () => _sendMessage(chatId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
