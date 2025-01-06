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
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Sohbet veya grup ara...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[300]),
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            prefixIcon: Icon(Icons.search, color: Colors.grey[300]),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          cursorColor: Colors.white,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('members', arrayContains: currentUser?.email)
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
            
            // Gizlenen sohbetleri filtrele
            if (hiddenFor.contains(currentUser?.email)) {
              return false;
            }

            if (data['isGroup'] ?? false) {
              // Grup sohbeti için grup adında ara
              final groupName = (data['name'] ?? '').toString().toLowerCase();
              return groupName.contains(_searchQuery);
            } else {
              // Kişisel sohbet için diğer kullanıcının adında ara
              final members = List<String>.from(data['members'] ?? []);
              final otherUserEmail = members.firstWhere(
                (email) => email != currentUser?.email,
                orElse: () => '',
              );
              return otherUserEmail.toLowerCase().contains(_searchQuery);
            }
          }).toList() ?? [];

          if (chats.isEmpty) {
            return const Center(child: Text('Sonuç bulunamadı'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final isGroup = data['isGroup'] ?? false;
              final members = List<String>.from(data['members'] ?? []);

              if (isGroup) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.group, color: Colors.white),
                  ),
                  title: Text(data['name'] ?? 'İsimsiz Grup'),
                  subtitle: Text('${members.length} üye'),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'chatId': chat.id,
                        'userEmail': data['name'],
                        'isGroup': true,
                      },
                    );
                  },
                );
              } else {
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
                    
                    if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                      final userData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                      displayName = userData['userName'] ?? otherUserEmail;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(displayName),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/chat',
                          arguments: {
                            'chatId': chat.id,
                            'userEmail': displayName,
                            'isGroup': false,
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
