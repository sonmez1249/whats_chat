import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'search_page.dart';
import 'user_settings_page.dart';
import '../services/theme_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Set<String> _selectedChats = {};
  bool _isSelectionMode = false;

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çıkış yapılırken bir hata oluştu')),
      );
    }
  }

  // Seçim modunu aç/kapa
  void _toggleSelectionMode(bool enable) {
    setState(() {
      _isSelectionMode = enable;
      if (!enable) {
        _selectedChats.clear();
      }
    });
  }

  // Seçili sohbetleri sil
  Future<void> _deleteSelectedChats() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbetleri Sil'),
        content: Text('${_selectedChats.length} sohbeti silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // Seçili sohbetler için hiddenFor array'ine current user'ı ekle
        final batch = FirebaseFirestore.instance.batch();
        for (var chatId in _selectedChats) {
          final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
          batch.update(chatRef, {
            'hiddenFor': FieldValue.arrayUnion([currentUser.email])
          });
        }
        await batch.commit();

        if (mounted) {
          _toggleSelectionMode(false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sohbetler silindi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user?.email)
              .snapshots(),
          builder: (context, snapshot) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserSettingsPage(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: snapshot.hasData && 
                                  snapshot.data!.docs.isNotEmpty && 
                                  snapshot.data!.docs.first['profileImage'] != null
                      ? NetworkImage(snapshot.data!.docs.first['profileImage'])
                      : null,
                  child: (!snapshot.hasData || 
                         snapshot.data!.docs.isEmpty || 
                         snapshot.data!.docs.first['profileImage'] == null)
                      ? Text(
                          (user?.email?[0] ?? '').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
        title: _isSelectionMode 
            ? Text('${_selectedChats.length} seçildi')
            : const Text('WhatsChat'),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedChats.isEmpty ? null : _deleteSelectedChats,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SearchPage()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.light
                        ? Icons.dark_mode
                        : Icons.light_mode,
                  ),
                  onPressed: () {
                    final themeService = ThemeService();
                    themeService.toggleTheme();
                  },
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.person),
                          SizedBox(width: 8),
                          Text('Profil'),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(
                          const Duration(seconds: 0),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserSettingsPage(),
                            ),
                          ),
                        );
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.exit_to_app),
                          SizedBox(width: 8),
                          Text('Çıkış Yap'),
                        ],
                      ),
                      onTap: () => _signOut(context),
                    ),
                  ],
                ),
              ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('members', arrayContains: user?.email)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data?.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);
            return !hiddenFor.contains(user?.email); // Gizlenen sohbetleri filtrele
          }).toList() ?? [];

          if (chats.isEmpty) {
            return const Center(child: Text('Henüz sohbet yok'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final isGroup = data['isGroup'] ?? false;
              final members = List<String>.from(data['members'] ?? []);

              // Grup değilse diğer kullanıcının email'ini al
              final otherUserEmail = !isGroup
                  ? members.firstWhere(
                      (member) => member != user?.email,
                      orElse: () => 'Bilinmeyen Kullanıcı',
                    )
                  : null;

              return InkWell(
                onLongPress: () {
                  if (!_isSelectionMode) {
                    _toggleSelectionMode(true);
                    setState(() {
                      _selectedChats.add(chat.id);
                    });
                  }
                },
                onTap: _isSelectionMode
                    ? () {
                        setState(() {
                          if (_selectedChats.contains(chat.id)) {
                            _selectedChats.remove(chat.id);
                            if (_selectedChats.isEmpty) {
                              _toggleSelectionMode(false);
                            }
                          } else {
                            _selectedChats.add(chat.id);
                          }
                        });
                      }
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/chat',
                          arguments: {
                            'chatId': chat.id,
                            'userEmail': isGroup ? data['name'] : otherUserEmail,
                            'isGroup': isGroup,
                          },
                        );
                      },
                child: Card(
                  color: _selectedChats.contains(chat.id)
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : null,
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Icon(
                            isGroup ? Icons.group : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        if (_isSelectionMode)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              child: Icon(
                                _selectedChats.contains(chat.id)
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: isGroup
                        ? Text(data['name'] ?? 'İsimsiz Grup')
                        : FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .where('email', isEqualTo: otherUserEmail)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                final userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                                return Text(userData['userName'] ?? otherUserEmail ?? 'Bilinmeyen Kullanıcı');
                              }
                              return Text(otherUserEmail ?? 'Bilinmeyen Kullanıcı');
                            },
                          ),
                    trailing: !_isSelectionMode
                        ? StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chat.id)
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .limit(1)
                                .snapshots(),
                            builder: (context, snapshot) {
                              String time = '';
                              int unreadCount = 0;

                              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                final lastMessage = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                                final timestamp = lastMessage['timestamp'] as Timestamp?;
                                
                                if (timestamp != null) {
                                  final messageTime = timestamp.toDate();
                                  final now = DateTime.now();
                                  
                                  // Bugünün mesajı ise saat, değilse tarih göster
                                  if (messageTime.year == now.year && 
                                      messageTime.month == now.month && 
                                      messageTime.day == now.day) {
                                    time = '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
                                  } else {
                                    time = '${messageTime.day}/${messageTime.month}';
                                  }
                                }
                              }

                              // Okunmamış mesaj sayısını hesapla
                              return FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(chat.id)
                                    .collection('messages')
                                    .where('readBy', arrayContains: user?.email)
                                    .get(),
                                builder: (context, unreadSnapshot) {
                                  if (unreadSnapshot.hasData) {
                                    unreadCount = unreadSnapshot.data!.docs.length;
                                  }

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        time,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (unreadCount > 0) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create-chat');
              },
              child: const Icon(Icons.chat),
            ),
    );
  }
}
