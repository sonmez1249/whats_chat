import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateChatPage extends StatefulWidget {
  const CreateChatPage({super.key});

  @override
  State<CreateChatPage> createState() => _CreateChatPageState();
}

class _CreateChatPageState extends State<CreateChatPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _groupNameController = TextEditingController();
  bool _isGroup = false;
  bool _isLoading = false;
  List<String> _selectedEmails = []; // Seçilen kullanıcıların emailleri
  List<String> selectedUsers = [];

  Future<void> _addUserToGroup() async {
    if (_emailController.text.isEmpty) return;
    final email = _emailController.text.trim();

    // Kendini eklemeyi engelle
    if (email == FirebaseAuth.instance.currentUser?.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendinizi ekleyemezsiniz')),
      );
      return;
    }

    // Maksimum 4 kullanıcı kontrolü
    if (_selectedEmails.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En fazla 4 kullanıcı ekleyebilirsiniz')),
      );
      return;
    }

    // Kullanıcının varlığını kontrol et
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (userQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı bulunamadı')),
      );
      return;
    }

    setState(() {
      if (!_selectedEmails.contains(email)) {
        _selectedEmails.add(email);
      }
      _emailController.clear();
    });
  }

  Future<void> _createChat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final firestore = FirebaseFirestore.instance;

      if (_isGroup) {
        // Grup sohbeti oluşturma kodu...
      } else {
        // Kişisel sohbet için kullanıcıyı kontrol et
        final userQuery = await firestore
            .collection('users')
            .where('email', isEqualTo: _emailController.text.trim())
            .get();

        if (userQuery.docs.isEmpty) {
          throw 'Kullanıcı bulunamadı';
        }

        // Mevcut sohbeti kontrol et
        final existingChatQuery = await firestore
            .collection('chats')
            .where('members', arrayContains: currentUser.email)
            .get();

        // Aynı kullanıcılarla mevcut bir sohbet var mı kontrol et
        for (var doc in existingChatQuery.docs) {
          final members = List<String>.from(doc.data()['members'] ?? []);
          if (members.length == 2 &&
              members.contains(_emailController.text.trim()) &&
              members.contains(currentUser.email)) {
            if (mounted) {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'chatId': doc.id,
                  'userEmail': _emailController.text.trim(),
                },
              );
            }
            return;
          }
        }

        // Yeni kişisel sohbet oluştur
        final chatDoc = await firestore.collection('chats').add({
          'members': [
            currentUser.email,
            _emailController.text.trim(),
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'isGroup': false,
        });

        if (mounted) {
          Navigator.pop(context);
          Navigator.pushNamed(
            context,
            '/chat',
            arguments: {
              'chatId': chatDoc.id,
              'userEmail': _emailController.text.trim(),
            },
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup adı boş olamaz')),
      );
      return;
    }

    if (_selectedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir kullanıcı seçmelisiniz')),
      );
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Grup üyelerine current user'ı da ekle
      final members = [..._selectedEmails, currentUser.email!];

      // Grubu chats koleksiyonunda oluştur
      final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
        'name': _groupNameController.text.trim(),
        'members': members,
        'createdBy': currentUser.email,
        'createdAt': FieldValue.serverTimestamp(),
        'isGroup': true,
        'lastMessage': null,
        'lastMessageTime': null
      });

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatId': chatDoc.id,
            'userEmail': _groupNameController.text.trim(),
            'isGroup': true,
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grup oluşturulurken hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sohbet Oluştur'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kişisel Sohbet'),
              Tab(text: 'Grup Sohbeti'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Kişisel sohbet sekmesi
            _buildPersonalChat(),
            // Grup sohbeti sekmesi
            _buildGroupChat(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChat() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Grup adı girişi
          TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(
              labelText: 'Grup Adı',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 16),

          // E-posta girişi
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı E-postası',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
              hintText: 'Eklemek istediğiniz kullanıcının e-postası',
            ),
          ),
          const SizedBox(height: 8),

          // Ekle butonu
          ElevatedButton.icon(
            onPressed: _addUserToGroup,
            icon: const Icon(Icons.add),
            label: const Text('Kullanıcı Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Seçili kullanıcılar başlığı
          if (_selectedEmails.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Seçili Kullanıcılar (${_selectedEmails.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Seçili kullanıcılar listesi
          Expanded(
            child: _selectedEmails.isEmpty
                ? Center(
                    child: Text(
                      'Henüz kullanıcı eklenmedi',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _selectedEmails.length,
                    itemBuilder: (context, index) {
                      final email = _selectedEmails[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(email),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                            onPressed: () {
                              setState(() {
                                _selectedEmails.remove(email);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Oluştur butonu
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedEmails.isEmpty ? null : createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Grup Oluştur',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mevcut kişisel sohbet widget'ı
  Widget _buildPersonalChat() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı E-postası',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen bir e-posta adresi girin';
                }
                if (!value.contains('@')) {
                  return 'Geçerli bir e-posta adresi girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _createChat,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Sohbet Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }
}
