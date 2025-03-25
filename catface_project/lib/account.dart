import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'Reward.dart';
import 'account_info.dart';
import 'my_posts.dart';
import 'sign_in.dart';

class AccountPage extends StatefulWidget {
  final String userId; // รับ user_id จากหน้าอื่น

  const AccountPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String username = '';
  String profileImagePath = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // เรียก API /get-user/<userId> เพื่อดึงข้อมูลผู้ใช้
      final userResponse = await http.get(
        Uri.parse('${Config.baseUrl}/get-user/${widget.userId}'),
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);

        setState(() {
          username = userData['username'] ?? 'Unknown';
          profileImagePath = userData['profile_image_path'] ?? '';
        });
      } else {
        setState(() {
          username = 'Unknown';
        });
      }
    } catch (e) {
      setState(() {
        username = 'Error';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300], // สีพื้นหลังเทาเข้ม
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Account', style: TextStyle(color: Colors.white)),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  const SizedBox(height: 30),
                  // รูปโปรไฟล์
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage:
                          profileImagePath.isNotEmpty
                              ? NetworkImage(
                                '${Config.baseUrl}/$profileImagePath',
                              )
                              : const AssetImage(
                                    'assets/images/default_profile.png',
                                  )
                                  as ImageProvider,
                      backgroundColor: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ชื่อผู้ใช้ ตรงกลาง
                  Center(
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // รายการเมนู
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      children: [
                        _buildMenuItem(
                          icon: Icons.person,
                          text: 'Account Info',
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        AccountInfoPage(userId: widget.userId),
                              ),
                            );

                            // ถ้าผลลัพธ์เป็น true ให้รีเฟรชข้อมูล
                            if (result == true) {
                              _fetchUserData(); // รีเฟรชข้อมูลหลังจากอัพเดตแล้ว
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildMenuItem(
                          icon: Icons.post_add,
                          text: 'My Posts',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        MyPostsPage(userId: widget.userId),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildMenuItem(
                          icon:
                              Icons.card_giftcard, // หรือ Icons.post_add ก็ได้
                          text: 'Reward',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        RewardPage(userId: widget.userId),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildMenuItem(
                          icon: Icons.logout,
                          text: 'Log Out',
                          onTap: () {
                            _showLogoutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(text, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        dense: true,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด Dialog
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => SignInPage()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
