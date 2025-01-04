import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'group_details_page.dart';
import '../widgets/reaction_picker.dart';
import '../models/message_builder.dart';

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

      final isGroup = chatDoc.data()?['isGroup'] ?? false;

      // Builder pattern kullanarak mesaj oluştur
      final message = MessageBuilder()
          .setText(_messageController.text.trim())
          .setSender(currentUser?.email ?? '')
          .setIsGroup(isGroup)
          .setTimestamp(DateTime.now())
          .build();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    }
  }

  // Mesaj silme dialog'unu göster
  Future<void> _showDeleteDialog(String chatId) async {
    // Seçili mesajların hepsi bana ait mi kontrol et
    bool allMine = true;
    for (var messageId in _selectedMessages) {
      final message = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      final data = message.data() as Map<String, dynamic>;
      if (data['senderId'] != currentUser?.email) {
        allMine = false;
        break;
      }
    }

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
            child: const Text(
              'İptal',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Benden sil',
              style: TextStyle(color: Colors.red),
            ),
          ),
          if (allMine) // Sadece mesajlar bana aitse herkesten silme seçeneği göster
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Herkesten sil',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );

    if (result != null) {
      await _deleteMessages(chatId, result);
    }
  }

  // Mesajları sil
  Future<void> _deleteMessages(String chatId, bool onlyForMe) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var messageId in _selectedMessages) {
        final messageRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId);

        // Mesaj sahibini kontrol et
        final message = await messageRef.get();
        final data = message.data() as Map<String, dynamic>;
        final isMyMessage = data['senderId'] == currentUser?.email;

        if (onlyForMe) {
          // Benden sil seçeneği için
          batch.update(messageRef, {
            'deletedFor': FieldValue.arrayUnion([currentUser?.email])
          });
        } else if (isMyMessage) {
          // Herkesten sil seçeneği için (sadece benim mesajlarımı sil)
          batch.delete(messageRef);
        }
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

  // Reaksiyon widget'larını oluşturan metod
  Widget _buildReactionsWidget(List? reactions, {bool isMe = false}) {
    if (reactions == null || reactions.isEmpty) return const SizedBox();

    final Map<String, int> reactionCounts = {};
    for (var reaction in reactions) {
      final emoji = reaction['emoji'] as String;
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactionCounts.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.1) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300]!,
                width: 0.5,
              ),
            ),
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
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
                    return const Text('Yükleniyor...');
                  }

                  final chatData =
                      chatSnapshot.data!.data() as Map<String, dynamic>;
                  final isGroup = chatData['isGroup'] ?? false;

                  return GestureDetector(
                    onTap: isGroup
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupDetailsPage(
                                  chatId: chatId,
                                  groupName: chatData['chatName'],
                                  members: List<String>.from(
                                      chatData['members'] ?? []),
                                  createdBy: chatData['createdBy'],
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          radius: 20,
                          child: isGroup
                              ? const Icon(Icons.group, color: Colors.white)
                              : Text(
                                  userEmail[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isGroup) ...[
                                Text(
                                  chatData['chatName'] ?? '',
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
                              ] else
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .where('email', isEqualTo: userEmail)
                                      .snapshots(),
                                  builder: (context, userSnapshot) {
                                    String displayName = userEmail;
                                    if (userSnapshot.hasData &&
                                        userSnapshot.data!.docs.isNotEmpty) {
                                      final userData =
                                          userSnapshot.data!.docs.first.data()
                                              as Map<String, dynamic>;
                                      displayName =
                                          userData['userName'] ?? userEmail;
                                    }
                                    return Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
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
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('İpuçları'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• Mesajı silmek için uzun basın'),
                            Text('• Reaksiyon eklemek için çift tıklayın'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tamam'),
                          ),
                        ],
                      ),
                    );
                  },
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
                          onDoubleTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => ReactionPicker(
                                onReactionSelected: (emoji) async {
                                  try {
                                    final messageRef = FirebaseFirestore
                                        .instance
                                        .collection('chats')
                                        .doc(chatId)
                                        .collection('messages')
                                        .doc(message.id);

                                    // Önce mevcut reaksiyonları kontrol et
                                    final messageDoc = await messageRef.get();
                                    final messageData = messageDoc.data()
                                        as Map<String, dynamic>;
                                    final reactions = List.from(
                                        messageData['reactions'] ?? []);

                                    // Kullanıcının önceki reaksiyonunu kaldır
                                    reactions.removeWhere((r) =>
                                        r['userId'] == currentUser?.email);

                                    // Yeni reaksiyonu ekle
                                    reactions.add({
                                      'emoji': emoji,
                                      'userId': currentUser?.email,
                                      'timestamp':
                                          DateTime.now().toIso8601String(),
                                    });

                                    // Reaksiyonları güncelle
                                    await messageRef
                                        .update({'reactions': reactions});

                                    if (mounted) {
                                      Navigator.pop(context);
                                    }
                                  } catch (e) {
                                    print('Reaksiyon eklenirken hata: $e');
                                  }
                                },
                              ),
                            );
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
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
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
                                                        .data()
                                                    as Map<String, dynamic>;
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 10,
                                                      backgroundColor:
                                                          Theme.of(context)
                                                              .primaryColor
                                                              .withOpacity(0.5),
                                                      child: Text(
                                                        (userData['userName'] ??
                                                                data[
                                                                    'senderId'])[0]
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
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                                      (data['senderId'] ??
                                                              '')[0]
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
                                                    data['senderId'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                            color: isMe
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: isMe
                                              ? MainAxisAlignment.spaceBetween
                                              : MainAxisAlignment.spaceBetween,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            if (!isMe)
                                              _buildReactionsWidget(
                                                data['reactions'] as List?,
                                                isMe: isMe,
                                              ),
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
                                            if (isMe)
                                              _buildReactionsWidget(
                                                data['reactions'] as List?,
                                                isMe: isMe,
                                              ),
                                          ],
                                        ),
                                      ],
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
