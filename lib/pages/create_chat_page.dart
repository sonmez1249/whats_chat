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

  Future<void> _createChat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final firestore = FirebaseFirestore.instance;

      if (_isGroup) {
        // Grup sohbeti oluştur
        final chatDoc = await firestore.collection('chats').add({
          'chatName': _groupNameController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.email,
          'isGroup': true,
        });

        await firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('groupMember')
            .add({
          'email': currentUser.email,
          'role': 'admin',
        });
      } else {
        // Birebir sohbet oluştur
        final otherUserEmail = _emailController.text.trim();

        // Kullanıcının kendisiyle sohbet oluşturmasını engelle
        if (otherUserEmail == currentUser.email) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kendinizle sohbet oluşturamazsınız')),
          );
          return;
        }

        // Kullanıcının varlığını kontrol et
        final userQuery = await firestore
            .collection('users')
            .where('email', isEqualTo: otherUserEmail)
            .get();

        if (userQuery.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kullanıcı bulunamadı')),
            );
          }
          return;
        }

        // Önceki sohbeti kontrol et
        final existingChatQuery = await firestore
            .collection('chats')
            .where('isGroup', isEqualTo: false)
            .where('members',
                arrayContainsAny: [currentUser.email, otherUserEmail]).get();

        String chatId;

        if (existingChatQuery.docs.isNotEmpty) {
          final existingChat = existingChatQuery.docs.first;
          final members = existingChat['members'] as List;
          if (members.contains(currentUser.email) &&
              members.contains(otherUserEmail)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Bu kullanıcıyla zaten bir sohbetiniz var')),
              );
            }
            return;
          }
        }

        // Yeni sohbet oluştur
        final chatDoc = await firestore.collection('chats').add({
          'chatName': '',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.email,
          'isGroup': false,
          'members': [currentUser.email, otherUserEmail],
        });

        chatId = chatDoc.id;
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
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
        title: Text(_isGroup ? 'Grup Oluştur' : 'Yeni Sohbet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Sohbet türü seçimi
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
                  });
                },
              ),
              const SizedBox(height: 24),

              // Grup adı veya kullanıcı e-posta alanı
              if (_isGroup)
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
                )
              else
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
