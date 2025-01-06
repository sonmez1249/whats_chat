import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupDetailsPage extends StatelessWidget {
  final String chatId;
  final String groupName;

  const GroupDetailsPage({
    Key? key,
    required this.chatId,
    required this.groupName,
  }) : super(key: key);

  // Yeni üye ekleme fonksiyonu
  Future<void> _addNewMember(BuildContext context, List<String> currentMembers) async {
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AddMemberDialog(currentMembers: currentMembers),
      );

      if (result != null) {
        // Üyeyi gruba ekle
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'members': FieldValue.arrayUnion([result])
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Üye eklenirken hata oluştu: $e')),
        );
      }
    }
  }

  // Üyeyi yönetici yapma fonksiyonu
  Future<void> _makeAdmin(String userEmail) async {
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'admins': FieldValue.arrayUnion([userEmail])
    });
  }

  // Üyeyi gruptan çıkarma fonksiyonu
  Future<void> _removeMember(String userEmail) async {
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'members': FieldValue.arrayRemove([userEmail]),
      'admins': FieldValue.arrayRemove([userEmail])
    });
  }

  // Gruptan çıkma fonksiyonu
  Future<void> _leaveGroup(BuildContext context, String currentUserEmail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruptan Çık'),
        content: const Text('Gruptan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çık', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'members': FieldValue.arrayRemove([currentUserEmail]),
        'admins': FieldValue.arrayRemove([currentUserEmail])
      });
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grup Bilgileri'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final members = List<String>.from(data['members'] ?? []);
          final admins = List<String>.from(data['admins'] ?? []);
          final createdBy = data['createdBy'] as String?;
          final currentUser = FirebaseAuth.instance.currentUser;
          final isAdmin = admins.contains(currentUser?.email) || currentUser?.email == createdBy;

          return ListView(
            children: [
              const SizedBox(height: 20),
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(
                    Icons.group,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${members.length} üye',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _addNewMember(context, members),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Üye Ekle'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Grup Üyeleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final memberEmail = members[index];
                  final isCurrentUser = memberEmail == currentUser?.email;
                  final isMemberAdmin = admins.contains(memberEmail) || memberEmail == createdBy;

                  return FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: memberEmail)
                        .get(),
                    builder: (context, userSnapshot) {
                      String userName = memberEmail;
                      String? profileImage;
                      
                      if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                        final userData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        userName = userData['userName'] ?? memberEmail;
                        profileImage = userData['profileImage'];
                      }
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                          child: profileImage == null
                              ? Text(
                                  userName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          userName,
                          style: TextStyle(
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: isMemberAdmin
                            ? const Text(
                                'Grup Yöneticisi',
                                style: TextStyle(color: Colors.blue),
                              )
                            : null,
                        trailing: isAdmin && !isCurrentUser
                            ? PopupMenuButton(
                                itemBuilder: (context) => [
                                  if (!isMemberAdmin)
                                    PopupMenuItem(
                                      child: const Text('Yönetici Yap'),
                                      onTap: () => _makeAdmin(memberEmail),
                                    ),
                                  PopupMenuItem(
                                    child: const Text(
                                      'Gruptan Çıkar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    onTap: () => _removeMember(memberEmail),
                                  ),
                                ],
                              )
                            : isCurrentUser
                                ? const Text('Sen', style: TextStyle(color: Colors.grey))
                                : null,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () => _leaveGroup(context, currentUser?.email ?? ''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Gruptan Çık'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

// Yeni üye ekleme dialog'u
class AddMemberDialog extends StatefulWidget {
  final List<String> currentMembers;

  const AddMemberDialog({
    Key? key,
    required this.currentMembers,
  }) : super(key: key);

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Üye Ekle'),
      content: TextField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: 'E-posta adresi',
          hintText: 'ornek@email.com',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () async {
            final email = _emailController.text.trim();
            if (email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lütfen bir e-posta adresi girin')),
              );
              return;
            }

            if (widget.currentMembers.contains(email)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bu kullanıcı zaten grupta')),
              );
              return;
            }

            try {
              // Kullanıcının varlığını kontrol et
              final userQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .get();

              if (userQuery.docs.isNotEmpty) {
                if (context.mounted) {
                  Navigator.pop(context, email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Üye başarıyla eklendi')),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kullanıcı bulunamadı')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata oluştu: $e')),
                );
              }
            }
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
