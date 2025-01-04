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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    if (currentUser?.email == widget.createdBy) {
      setState(() {
        _isAdmin = true; // Grup kurucusu otomatik olarak admin
      });
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('groupMember')
        .where('email', isEqualTo: currentUser?.email)
        .where('role', isEqualTo: 'admin')
        .get();

    setState(() {
      _isAdmin = doc.docs.isNotEmpty;
    });
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

  Future<void> _toggleAdminStatus(String email) async {
    if (widget.createdBy != currentUser?.email)
      return; // Sadece grup kurucusu admin atayabilir

    try {
      final memberQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('groupMember')
          .where('email', isEqualTo: email)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        final doc = memberQuery.docs.first;
        final isAdmin = (doc.data() as Map<String, dynamic>)['role'] == 'admin';

        await doc.reference.update({
          'role': isAdmin ? 'member' : 'admin',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isAdmin ? 'Yönetici yetkisi alındı' : 'Yönetici atandı'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grup Detayları'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Grup adı
          Card(
            child: ListTile(
              leading: const Icon(Icons.group),
              title: Text(widget.groupName),
              subtitle: Text('${widget.members.length} üye'),
            ),
          ),
          const SizedBox(height: 16),

          // Üye ekleme (sadece admin için)
          if (_isAdmin) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Yeni Üye Ekle'),
                    const SizedBox(height: 8),
                    Row(
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Üye listesi
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Üyeler'),
                ),
                ...widget.members.map((email) => StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('email', isEqualTo: email)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();

                        final userData = snapshot.data?.docs.first.data()
                            as Map<String, dynamic>?;
                        final userName = userData?['userName'] ?? email;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(userName[0].toUpperCase()),
                          ),
                          title: Text(userName),
                          subtitle: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(widget.chatId)
                                .collection('groupMember')
                                .where('email', isEqualTo: email)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final isAdmin = snapshot.hasData &&
                                  snapshot.data?.docs.isNotEmpty == true &&
                                  (snapshot.data?.docs.first.data()
                                          as Map<String, dynamic>)?['role'] ==
                                      'admin';
                              return Text(email == widget.createdBy
                                  ? 'Yönetici'
                                  : isAdmin
                                      ? 'Yönetici'
                                      : 'Üye');
                            },
                          ),
                          trailing: (_isAdmin || email == widget.createdBy) &&
                                  email != currentUser?.email &&
                                  email != widget.createdBy
                              ? PopupMenuButton(
                                  icon: const Icon(Icons.more_vert),
                                  itemBuilder: (context) => [
                                    if (widget.createdBy ==
                                        currentUser?.email) ...[
                                      PopupMenuItem(
                                        child: StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('chats')
                                              .doc(widget.chatId)
                                              .collection('groupMember')
                                              .where('email', isEqualTo: email)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            final isAdmin = snapshot.hasData &&
                                                snapshot.data?.docs
                                                        .isNotEmpty ==
                                                    true &&
                                                (snapshot.data?.docs.first
                                                                .data()
                                                            as Map<String,
                                                                dynamic>)?[
                                                        'role'] ==
                                                    'admin';
                                            return ListTile(
                                              leading: Icon(
                                                isAdmin
                                                    ? Icons.remove_moderator
                                                    : Icons
                                                        .admin_panel_settings,
                                                color: isAdmin
                                                    ? Colors.red
                                                    : Colors.blue,
                                              ),
                                              title: Text(
                                                isAdmin
                                                    ? 'Yöneticilikten çıkar'
                                                    : 'Yönetici yap',
                                                style: TextStyle(
                                                  color: isAdmin
                                                      ? Colors.red
                                                      : Colors.blue,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        onTap: () => _toggleAdminStatus(email),
                                      ),
                                    ],
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        title: const Text(
                                          'Gruptan çıkar',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Üyeyi Çıkar'),
                                            content: Text(
                                                '$userName gruptan çıkarılsın mı?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('İptal'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _removeMember(email);
                                                },
                                                child: const Text(
                                                  'Çıkar',
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                )
                              : null,
                        );
                      },
                    )),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Gruptan çık butonu
          if (currentUser?.email != widget.createdBy)
            ElevatedButton.icon(
              onPressed: _leaveGroup,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Gruptan Çık'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
