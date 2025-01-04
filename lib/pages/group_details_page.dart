import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupDetailsPage extends StatefulWidget {
  final String chatId;
  final String groupName;
  final List<String> members;
  final String createdBy;

  const GroupDetailsPage({
    super.key,
    required this.chatId,
    required this.groupName,
    required this.members,
    required this.createdBy,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final _emailController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: Column(
        children: [
          // Üye ekleme kısmı
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'E-posta adresi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addMember,
                ),
              ],
            ),
          ),

          // Üye listesi
          Expanded(
            child: ListView.builder(
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final email = widget.members[index];
                return ListTile(
                  title: Text(email),
                  trailing: email != currentUser?.email
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.red,
                          onPressed: () => _removeMember(email),
                        )
                      : null,
                );
              },
            ),
          ),

          // Gruptan çık butonu
          if (widget.members.contains(currentUser?.email))
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _leaveGroup,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Gruptan Çık'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addMember() async {
    if (_emailController.text.isEmpty) return;

    try {
      // Kullanıcı kontrolü
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bulunamadı')),
        );
        return;
      }

      // Grup üye sayısı kontrolü
      if (widget.members.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup en fazla 5 üye olabilir')),
        );
        return;
      }

      // Kullanıcı zaten grupta mı kontrolü
      if (widget.members.contains(_emailController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı zaten grupta')),
        );
        return;
      }

      // Üye ekleme
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'members': FieldValue.arrayUnion([_emailController.text.trim()]),
      });

      // Grup üyeliği ekleme
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('groupMember')
          .add({
        'email': _emailController.text.trim(),
        'role': 'member',
      });

      _emailController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Üye eklenemedi: $e')),
      );
    }
  }

  Future<void> _removeMember(String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'members': FieldValue.arrayRemove([email]),
      });

      // Grup üyeliğini kaldır
      final memberQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('groupMember')
          .where('email', isEqualTo: email)
          .get();

      for (var doc in memberQuery.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Üye çıkarılamadı: $e')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    try {
      if (widget.createdBy == currentUser?.email) {
        // Grup kurucusu çıkmak istiyorsa
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Gruptan Çıkılamıyor'),
            content: const Text(
                'Grup kurucusu gruptan çıkamaz. Grubu silmek ister misiniz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .delete();
                  if (mounted) {
                    Navigator.pop(context); // Dialog'u kapat
                    Navigator.pop(context); // Detay sayfasını kapat
                    Navigator.pop(context); // Sohbet sayfasını kapat
                  }
                },
                child: const Text('Grubu Sil',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      } else {
        // Normal üye çıkıyor
        await _removeMember(currentUser?.email ?? '');
        if (mounted) {
          Navigator.pop(context); // Detay sayfasını kapat
          Navigator.pop(context); // Sohbet sayfasını kapat
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gruptan çıkılamadı: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
