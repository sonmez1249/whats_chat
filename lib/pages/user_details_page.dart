import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDetailsPage extends StatelessWidget {
  final String userEmail;
  final String chatId;

  const UserDetailsPage({
    Key? key,
    required this.userEmail,
    required this.chatId,
  }) : super(key: key);

  // Sohbeti silme fonksiyonu
  Future<void> _deleteChat(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti Sil'),
        content: const Text('Bu sohbeti silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'hiddenFor': FieldValue.arrayUnion([currentUser.email])
        });
        if (context.mounted) {
          Navigator.popUntil(context, ModalRoute.withName('/home'));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişi Bilgisi'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Kullanıcı bulunamadı'));
          }

          final userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final userName = userData['userName'] ?? userEmail;

          return ListView(
            children: [
              const SizedBox(height: 20),
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    userName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Engelle'),
                onTap: () {
                  // Engelleme işlevi eklenebilir
                },
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Şikayet Et'),
                onTap: () {
                  // Şikayet işlevi eklenebilir
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Sohbeti Sil',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _deleteChat(context),
              ),
            ],
          );
        },
      ),
    );
  }
} 