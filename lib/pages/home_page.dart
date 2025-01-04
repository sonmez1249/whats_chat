import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'search_page.dart';
import 'group_details_page.dart';

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

  Future<void> _showDeleteDialog(
      String chatId, String chatName, bool isGroup) async {
    if (isGroup) {
      // Grup sohbeti için çıkma ve silme dialog'u
      final result = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            '"$chatName" grubundan çıkmalısınız',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: const Text(
            'Grup sohbetini silmek için önce gruptan çıkmanız gerekir.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, 'leave'),
                    child: const Text(
                      'Gruptan Çık',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (result == 'leave') {
        // Gruptan çık
        await _leaveGroup(chatId);

        // Gruptan çıktıktan sonra sohbeti silmek isteyip istemediğini sor
        if (context.mounted) {
          final deleteResult = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Sohbet Silinsin mi?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Gruptan çıktınız. Sohbet geçmişini silmek ister misiniz?',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hayır'),
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

          if (deleteResult == true) {
            await _deleteChat(chatId);
          }
        }
      }
    } else {
      // Normal sohbet silme dialog'u
      final result = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            '"$chatName" ile olan sohbet silinsin mi?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: const Text(
            'Bu sohbetteki tüm mesajlar silinecek.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Sil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (result == true) {
        await _deleteChat(chatId);
      }
    }
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;

        await FirebaseFirestore.instance
            .collection('archivedChats')
            .doc(chatId)
            .set({
          ...chatData,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': FirebaseAuth.instance.currentUser?.email,
        });

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .delete();
      }

      setState(() {
        _selectedChats.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sohbet silinemedi: $e')),
      );
    }
  }

  // Gruptan çıkma fonksiyonu
  Future<void> _leaveGroup(String chatId) async {
    try {
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email;

      // Gruptan çıkar
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'members': FieldValue.arrayRemove([currentUserEmail]),
        'leftMembers':
            FieldValue.arrayUnion([currentUserEmail]), // Çıkan üyeleri takip et
      });

      // Grup üyeliğini güncelle
      final memberQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('groupMember')
          .where('email', isEqualTo: currentUserEmail)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        await memberQuery.docs.first.reference.update({
          'status': 'left',
          'leftAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gruptan çıkıldı')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gruptan çıkılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedChats.length} seçildi')
            : const Text('WhatsChat'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedChats.clear();
                    _isSelectionMode = false;
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    if (_selectedChats.length == 1) {
                      final chatId = _selectedChats.first;
                      final chatName = '';
                      _showDeleteDialog(chatId, chatName, false);
                    }
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SearchPage()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Kullanıcı Adı'),
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.email?[0] ?? "").toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              onTap: () {
                // Profil sayfasına git
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Sohbetler'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Çıkış Yap'),
              onTap: () => _signOut(context),
            ),
          ],
        ),
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz sohbet yok'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chat = snapshot.data!.docs[index];
              final data = chat.data() as Map<String, dynamic>;
              final isGroup = data['isGroup'] ?? false;
              final members = List<String>.from(data['members'] ?? []);

              String chatName = data['chatName'] ?? '';
              if (!isGroup && chatName.isEmpty) {
                chatName = members.firstWhere(
                  (member) => member != user?.email,
                  orElse: () => 'Bilinmeyen Kullanıcı',
                );
              }

              return GestureDetector(
                onLongPress: () {
                  final userName = isGroup
                      ? data['chatName']
                      : ((snapshot.data?.docs.first.data()
                              as Map<String, dynamic>)?['userName'] ??
                          chatName);
                  _showDeleteDialog(chat.id, userName, isGroup);
                },
                child: Card(
                  color: _selectedChats.contains(chat.id)
                      ? Colors.blue.withOpacity(0.1)
                      : null,
                  elevation: 0,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    onTap: _isSelectionMode
                        ? () {
                            setState(() {
                              if (_selectedChats.contains(chat.id)) {
                                _selectedChats.remove(chat.id);
                                if (_selectedChats.isEmpty) {
                                  _isSelectionMode = false;
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
                                'userEmail': chatName,
                              },
                            );
                          },
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(
                        isGroup ? Icons.group : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('email', isEqualTo: chatName)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text(chatName);
                        }

                        if (snapshot.hasData &&
                            snapshot.data?.docs.isNotEmpty == true) {
                          final userData = snapshot.data?.docs.first.data()
                              as Map<String, dynamic>;
                          return Text(userData['userName'] ?? chatName);
                        }
                        return Text(chatName);
                      },
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '12:00',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-chat');
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}
