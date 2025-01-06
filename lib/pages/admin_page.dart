import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = const [
    Tab(text: 'Kullanıcılar'),
    Tab(text: 'Gruplar'),
    Tab(text: 'İstatistikler'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          isScrollable: false,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildGroupsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  // Kullanıcılar Sekmesi
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz kullanıcı yok'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            if (index >= snapshot.data!.docs.length) {
              return null;
            }

            final doc = snapshot.data!.docs[index];
            if (!doc.exists) {
              return const SizedBox.shrink();
            }

            try {
              final userData = doc.data() as Map<String, dynamic>;
              final userEmail = userData['email']?.toString() ?? '';
              final userName = userData['userName']?.toString() ?? 'İsimsiz Kullanıcı';
              final isAdmin = userData['isAdmin'] == true;
              final isBanned = userData['isBanned'] == true;

              if (userEmail.isEmpty) {
                return const SizedBox.shrink();
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: userData['profileImage'] != null 
                      ? NetworkImage(userData['profileImage'])
                      : null,
                  child: userData['profileImage'] == null
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(userName),
                subtitle: Text(userEmail),
                trailing: PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'admin',
                      child: Text(isAdmin ? 'Admin Yetkisini Kaldır' : 'Admin Yap'),
                    ),
                    PopupMenuItem<String>(
                      value: 'ban',
                      child: Text(isBanned ? 'Yasağı Kaldır' : 'Kullanıcıyı Yasakla'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'details',
                      child: Text('Kullanıcı Detayları'),
                    ),
                  ],
                  onSelected: (String value) async {
                    switch (value) {
                      case 'admin':
                        await _toggleAdminStatus(userEmail, !isAdmin);
                        break;
                      case 'ban':
                        await _toggleBanStatus(userEmail, !isBanned);
                        break;
                      case 'details':
                        _showUserDetails(context, userData);
                        break;
                    }
                  },
                ),
              );
            } catch (e) {
              print('Hata: $e');
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  // Gruplar Sekmesi
  Widget _buildGroupsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chats')
          .where('isGroup', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final groupData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final members = List<String>.from(groupData['members'] ?? []);
            final groupId = snapshot.data!.docs[index].id;

            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.group, color: Colors.white),
              ),
              title: Text(groupData['name'] ?? 'İsimsiz Grup'),
              subtitle: Text('${members.length} üye'),
              trailing: PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Grubu Sil'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'details',
                    child: Text('Grup Detayları'),
                  ),
                ],
                onSelected: (String value) async {
                  if (value == 'delete') {
                    await _deleteGroup(groupId);
                  } else if (value == 'details') {
                    _showGroupDetails(context, groupData, groupId);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // İstatistikler Sekmesi
  Widget _buildStatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('isGroup', isEqualTo: true)
              .snapshots(),
          builder: (context, groupsSnapshot) {
            if (!groupsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Kullanıcı istatistikleri
            final users = usersSnapshot.data!.docs;
            final adminCount = users.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isAdmin'] == true;
            }).length;
            
            final bannedCount = users.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isBanned'] == true;
            }).length;

            // Son 24 saat içinde aktif olan kullanıcıları say
            final yesterday = DateTime.now().subtract(const Duration(hours: 24));
            final activeUsers = users.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final lastSeen = data['lastSeen'] as Timestamp?;
              return lastSeen != null && lastSeen.toDate().isAfter(yesterday);
            }).length;

            // Grup istatistikleri
            final groups = groupsSnapshot.data!.docs;
            int totalMembers = 0;
            for (var group in groups) {
              final data = group.data() as Map<String, dynamic>;
              final members = List<String>.from(data['members'] ?? []);
              totalMembers += members.length;
            }
            final avgMembers = groups.isEmpty ? 0 : (totalMembers / groups.length).round();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Kullanıcı İstatistikleri
                const Text(
                  'Kullanıcı İstatistikleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Toplam\nKullanıcı',
                        users.length.toString(),
                        Icons.people,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Admin\nSayısı',
                        adminCount.toString(),
                        Icons.admin_panel_settings,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Aktif\nKullanıcılar',
                        activeUsers.toString(),
                        Icons.person,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Yasaklı\nKullanıcılar',
                        bannedCount.toString(),
                        Icons.block,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),

                // Grup İstatistikleri
                const SizedBox(height: 24),
                const Text(
                  'Grup İstatistikleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Toplam\nGrup',
                        groups.length.toString(),
                        Icons.groups,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Ortalama\nÜye Sayısı',
                        avgMembers.toString(),
                        Icons.person_add,
                      ),
                    ),
                  ],
                ),

                // Mesaj İstatistikleri
                const SizedBox(height: 24),
                const Text(
                  'Mesaj İstatistikleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('messages')
                      .snapshots(),
                  builder: (context, messagesSnapshot) {
                    if (!messagesSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allMessages = messagesSnapshot.data!.docs;
                    final today = DateTime.now().copyWith(
                      hour: 0,
                      minute: 0,
                      second: 0,
                      millisecond: 0,
                    );

                    final todayMessages = allMessages.where((doc) {
                      final timestamp = doc['timestamp'] as Timestamp?;
                      return timestamp != null && 
                             timestamp.toDate().isAfter(today);
                    }).length;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Bugün\nGönderilen',
                            todayMessages.toString(),
                            Icons.message,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Toplam\nMesaj',
                            allMessages.length.toString(),
                            Icons.chat,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // İstatistik kartı widget'ını güncelle
  Widget _buildStatCard(String title, String value, IconData icon, {Color? color}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color ?? Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // İstatistikleri getir fonksiyonunu güncelle
  Future<Map<String, dynamic>> _getStats() async {
    try {
      // Kullanıcı istatistikleri
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final adminCount = usersSnapshot.docs.where((doc) => doc.data()['isAdmin'] == true).length;
      final bannedCount = usersSnapshot.docs.where((doc) => doc.data()['isBanned'] == true).length;
      
      // Son 24 saat içinde aktif olan kullanıcıları say
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final activeUsers = usersSnapshot.docs.where((doc) {
        final lastSeen = doc.data()['lastSeen'] as Timestamp?;
        return lastSeen != null && lastSeen.toDate().isAfter(yesterday);
      }).length;

      // Grup istatistikleri
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('isGroup', isEqualTo: true)
          .get();
      
      // Ortalama grup üye sayısı hesapla
      int totalMembers = 0;
      for (var group in groupsSnapshot.docs) {
        final members = List<String>.from(group.data()['members'] ?? []);
        totalMembers += members.length;
      }
      final avgMembers = groupsSnapshot.docs.isEmpty 
          ? 0 
          : (totalMembers / groupsSnapshot.docs.length).round();

      // Mesaj istatistikleri
      final today = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
      
      // Bugünkü mesajları say
      final todayMessagesSnapshot = await FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(today))
          .get();

      // Toplam mesajları say
      final totalMessagesSnapshot = await FirebaseFirestore.instance
          .collectionGroup('messages')
          .get();

      return {
        'totalUsers': usersSnapshot.docs.length,
        'adminCount': adminCount,
        'activeUsers': activeUsers,
        'bannedUsers': bannedCount,
        'totalGroups': groupsSnapshot.docs.length,
        'avgGroupMembers': avgMembers,
        'todayMessages': todayMessagesSnapshot.docs.length,
        'totalMessages': totalMessagesSnapshot.docs.length,
      };
    } catch (e) {
      print('İstatistik hatası: $e');
      // Hata durumunda varsayılan değerler
      return {
        'totalUsers': 0,
        'adminCount': 0,
        'activeUsers': 0,
        'bannedUsers': 0,
        'totalGroups': 0,
        'avgGroupMembers': 0,
        'todayMessages': 0,
        'totalMessages': 0,
      };
    }
  }

  // Admin yetkisi verme/alma
  Future<void> _toggleAdminStatus(String userEmail, bool makeAdmin) async {
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userQuery.docs.first.id)
          .update({
        'isAdmin': makeAdmin,
      });
    }
  }

  // Kullanıcı yasaklama/yasağı kaldırma
  Future<void> _toggleBanStatus(String userEmail, bool ban) async {
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userQuery.docs.first.id)
          .update({
        'isBanned': ban,
      });
    }
  }

  // Grup silme
  Future<void> _deleteGroup(String groupId) async {
    // Silme onayı al
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grubu Sil'),
        content: const Text('Bu grubu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Önce grup mesajlarını sil
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .doc(groupId)
            .collection('messages')
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Sonra grubu sil
        batch.delete(FirebaseFirestore.instance.collection('chats').doc(groupId));
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grup başarıyla silindi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Grup silinirken hata oluştu: $e')),
          );
        }
      }
    }
  }

  // Grup detayları fonksiyonunu ekle
  void _showGroupDetails(BuildContext context, Map<String, dynamic> groupData, String groupId) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final updatedGroupData = snapshot.data!.data() as Map<String, dynamic>;
          final members = List<String>.from(updatedGroupData['members'] ?? []);
          final admins = List<String>.from(updatedGroupData['admins'] ?? []);
          final createdBy = updatedGroupData['createdBy'] as String?;
          final createdAt = updatedGroupData['createdAt'] as Timestamp?;

          return AlertDialog(
            title: const Text('Grup Detayları'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    title: Text(updatedGroupData['name'] ?? 'İsimsiz Grup'),
                    subtitle: Text('${members.length} üye'),
                  ),
                  const Divider(),
                  _buildDetailRow('Oluşturan', createdBy ?? 'Bilinmiyor'),
                  _buildDetailRow('Oluşturulma Tarihi', _formatDate(createdAt)),
                  _buildDetailRow('Toplam Üye', members.length.toString()),
                  _buildDetailRow('Yönetici Sayısı', admins.length.toString()),
                  const Divider(),
                  const Text(
                    'Üyeler:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...members.map((email) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          admins.contains(email) ? Icons.star : Icons.person,
                          size: 16,
                          color: admins.contains(email) ? Colors.amber : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(email)),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Kullanıcı detayları sayfasını güncelle
  void _showUserDetails(BuildContext context, Map<String, dynamic> userData) {
    final userEmail = userData['email'] as String;
    
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final updatedUserData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          
          return AlertDialog(
            title: const Text('Kullanıcı Detayları'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage: userData['profileImage'] != null 
                        ? NetworkImage(userData['profileImage'])
                        : null,
                    child: userData['profileImage'] == null
                        ? Text(
                            (updatedUserData['userName'] ?? 'İsimsiz')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  title: Text(updatedUserData['userName'] ?? 'İsimsiz Kullanıcı'),
                  subtitle: Text(updatedUserData['email'] ?? ''),
                ),
                const Divider(),
                _buildDetailRow(
                  'Hesap Durumu', 
                  updatedUserData['isBanned'] == true ? 'Yasaklı' : 'Aktif'
                ),
                _buildDetailRow(
                  'Yetki', 
                  updatedUserData['isAdmin'] == true ? 'Admin' : 'Kullanıcı'
                ),
                _buildDetailRow(
                  'Katılma Tarihi', 
                  _formatDate(updatedUserData['createdAt'])
                ),
                _buildDetailRow(
                  'Son Görülme', 
                  _formatDate(updatedUserData['lastSeen'])
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Yardımcı metodlar
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Belirtilmemiş';
    
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      // Saat ve dakikayı iki haneli formatta göster
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.day}/${date.month}/${date.year} $hour:$minute';
    }
    
    return 'Belirtilmemiş';
  }
} 