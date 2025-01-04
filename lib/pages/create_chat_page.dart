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
    if (_isGroup && _selectedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir kullanıcı ekleyin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final firestore = FirebaseFirestore.instance;

      if (_isGroup) {
        // Grup üyelerini hazırla
        final members = [currentUser.email!, ..._selectedEmails];

        // Grup sohbeti oluştur
        final chatDoc = await firestore.collection('chats').add({
          'chatName': _groupNameController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.email,
          'isGroup': true,
          'members': members,
        });

        // Grup yöneticisini ekle
        await chatDoc.collection('groupMember').add({
          'email': currentUser.email,
          'role': 'admin',
        });

        // Diğer üyeleri ekle
        for (var email in _selectedEmails) {
          await chatDoc.collection('groupMember').add({
            'email': email,
            'role': 'member',
          });
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // Birebir sohbet oluşturma kodları aynı kalacak
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGroup ? 'Grup Oluştur' : 'Kişisel Sohbet'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Grup/Kişisel seçimi
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Kişisel Sohbet'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Grup Sohbeti'),
                  icon: Icon(Icons.group),
                ),
              ],
              selected: {_isGroup},
              onSelectionChanged: (Set<bool> selected) {
                setState(() {
                  _isGroup = selected.first;
                  _selectedEmails.clear();
                });
              },
            ),
            const SizedBox(height: 24),

            if (_isGroup) ...[
              // Grup adı alanı
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Grup Adı',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen grup adı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kullanıcı ekleme alanı
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı E-postası',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addUserToGroup,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Seçilen kullanıcılar listesi
              ..._selectedEmails.map((email) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(email),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        setState(() {
                          _selectedEmails.remove(email);
                        });
                      },
                    ),
                  )),
            ] else ...[
              // Birebir sohbet için email alanı
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı E-postası',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen e-posta girin';
                  }
                  if (!value.contains('@')) {
                    return 'Geçerli bir e-posta girin';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),

            // Oluştur butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createChat,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Oluştur'),
              ),
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
