import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Sohbet veya grup ara...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
          ),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('members', arrayContains: currentUser?.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final isGroup = data['isGroup'] ?? false;

            if (isGroup) {
              // Grup sohbetlerinde grup adına göre ara
              final groupName = (data['chatName'] as String).toLowerCase();
              return groupName.contains(_searchQuery);
            } else {
              // Birebir sohbetlerde diğer kullanıcının adına göre ara
              final members = List<String>.from(data['members'] ?? []);
              final otherUserEmail = members.firstWhere(
                (email) => email != currentUser?.email,
                orElse: () => '',
              );
              return otherUserEmail.toLowerCase().contains(_searchQuery);
            }
          }).toList();

          if (chats.isEmpty) {
            return const Center(
              child: Text('Sonuç bulunamadı'),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final isGroup = data['isGroup'] ?? false;

              if (isGroup) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.group, color: Colors.white),
                  ),
                  title: Text(data['chatName'] ?? ''),
                  subtitle: Text('${data['members']?.length ?? 0} üye'),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'chatId': chat.id,
                        'userEmail': data['chatName'],
                      },
                    );
                  },
                );
              } else {
                final members = List<String>.from(data['members'] ?? []);
                final otherUserEmail = members.firstWhere(
                  (email) => email != currentUser?.email,
                  orElse: () => '',
                );

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: otherUserEmail)
                      .get(),
                  builder: (context, userSnapshot) {
                    String displayName = otherUserEmail;
                    if (userSnapshot.hasData &&
                        userSnapshot.data!.docs.isNotEmpty) {
                      final userData = userSnapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                      displayName = userData['userName'] ?? otherUserEmail;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(displayName[0].toUpperCase()),
                      ),
                      title: Text(displayName),
                      subtitle: const Text('Kişisel Sohbet'),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/chat',
                          arguments: {
                            'chatId': chat.id,
                            'userEmail': otherUserEmail,
                          },
                        );
                      },
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
