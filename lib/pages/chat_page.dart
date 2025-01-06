import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'group_details_page.dart';
import '../widgets/reaction_picker.dart';
import '../models/messages/message.dart';
import '../models/messages/chat_message_factory.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'user_details_page.dart';

class ChatPage extends StatefulWidget {
  final String userName;
  final bool isGroup;

  const ChatPage({
    Key? key,
    required this.userName,
    this.isGroup = false,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  final _messageFactory = ChatMessageFactory();

  // Seçili mesajları tutmak için
  final Set<String> _selectedMessages = {};
  bool _isSelectionMode = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _sendMessage(String chatId, Message message) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    }
  }

  void _sendTextMessage(String chatId) {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageFactory.createTextMessage(
      senderId: currentUser?.email ?? '',
      text: _messageController.text.trim(),
    );

    _sendMessage(chatId, message);
    _messageController.clear();
  }

  void _sendImageMessage(String chatId, String imageUrl) {
    final message = _messageFactory.createImageMessage(
      senderId: currentUser?.email ?? '',
      imageUrl: imageUrl,
    );

    _sendMessage(chatId, message);
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

    String deleteOption = 'me'; // Varsayılan olarak 'Benden sil'

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Mesaj silinsin mi?'),
        content: const Text('Mesajları herkesten veya yalnızca kendinizden silebilirsiniz.'),
        actions: [
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Benden sil'),
                    value: 'me',
                    groupValue: deleteOption,
                    onChanged: (value) {
                      setState(() => deleteOption = value!);
                    },
                  ),
                  // Sadece tüm mesajlar bana aitse "Herkesten sil" seçeneğini göster
                  if (allMine)
                    RadioListTile<String>(
                      title: const Text('Herkesten sil'),
                      value: 'everyone',
                      groupValue: deleteOption,
                      onChanged: (value) {
                        setState(() => deleteOption = value!);
                      },
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, deleteOption),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (result != null) {
      await _deleteMessages(chatId, result == 'me');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesajlar silinemedi: $e')),
        );
      }
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

  // Resim seçme ve yükleme fonksiyonu
  Future<void> _pickAndUploadImage(String chatId) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Yükleme başladı bildirimi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resim yükleniyor...')),
      );

      // Storage'a yükle
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      // Mesaj olarak gönder
      final message = _messageFactory.createImageMessage(
        senderId: currentUser?.email ?? '',
        imageUrl: imageUrl,
      );

      await _sendMessage(chatId, message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resim gönderildi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim yüklenemedi: $e')),
      );
    }
  }

  Future<void> _pickAndUploadImageFromCamera(String chatId) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf yükleniyor...')),
      );

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      final message = _messageFactory.createImageMessage(
        senderId: currentUser?.email ?? '',
        imageUrl: imageUrl,
      );

      await _sendMessage(chatId, message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf gönderildi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf yüklenemedi: $e')),
      );
    }
  }

  // Eklenti butonuna tıklandığında gösterilecek menü
  void _showAttachmentOptions(String chatId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Galeri'),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadImage(chatId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Kamera'),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadImageFromCamera(chatId);
            },
          ),
        ],
      ),
    );
  }

  // Mesaj içeriğini gösteren widget
  Widget _buildMessageContent(Map<String, dynamic> data, bool isMe) {
    switch (data['type']) {
      case 'image':
        return _buildImageMessage(data['imageUrl']);
      default: // text message
        return Text(
          data['text'] ?? '',
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
          ),
        );
    }
  }

  Widget _buildImageMessage(String imageUrl) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              imageUrl,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[200],
                  child: const Icon(Icons.error),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final chatId = args['chatId'] as String;
    final isGroup = args['isGroup'] as bool? ?? false;
    final displayName = args['userEmail'] as String;

    return Scaffold(
      appBar: AppBar(
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
            : Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Icon(
                      isGroup ? Icons.group : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
        leadingWidth: _isSelectionMode ? 56 : 96,
        title: _isSelectionMode
            ? Text('${_selectedMessages.length} seçildi')
            : GestureDetector(
                onTap: () {
                  if (isGroup) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailsPage(
                          chatId: chatId,
                          groupName: displayName,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailsPage(
                          chatId: chatId,
                          userEmail: args['userEmail'],
                        ),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (isGroup)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          final members = List<String>.from(data?['members'] ?? []);
                          return Text(
                            '${members.length} üye',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                  ],
                ),
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteDialog(chatId),
                ),
              ]
            : [
                if (isGroup) 
                  IconButton(
                    icon: const Icon(Icons.videocam),
                    onPressed: () {
                      // Grup görüntülü arama işlevi
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () {
                    // Arama işlevi
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Diğer seçenekler menüsü
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
                                              String displayName = data['senderId'] ?? '';
                                              String? profileImage;
                                              
                                              if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                                                final userData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                                                displayName = userData['userName'] ?? displayName;
                                                profileImage = userData['profileImage'];
                                              }

                                              return CircleAvatar(
                                                backgroundColor: Theme.of(context).primaryColor,
                                                backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                                                child: profileImage == null
                                                    ? Text(
                                                        displayName[0].toUpperCase(),
                                                        style: const TextStyle(color: Colors.white),
                                                      )
                                                    : null,
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        _buildMessageContent(data, isMe),
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
                  onPressed: () => _showAttachmentOptions(chatId),
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
                  onPressed: () => _sendTextMessage(chatId),
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
