import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'edit_cat_info.dart';
import 'feed.dart';
import 'post.dart';
import 'account.dart';
import 'register.dart';
import 'Map.dart';
import 'my_posts.dart';
import 'notification_service.dart';
import 'notification_page.dart';

class HomePage extends StatefulWidget {
  final String userId;
  final Future<http.StreamedResponse>? postCreationFuture;
  const HomePage({Key? key, required this.userId, this.postCreationFuture})
    : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Map<String, String>> _cats = [];
  String username = '';
  String profileImagePath = '';
  String? _postBannerMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    if (widget.postCreationFuture != null) {
      setState(() {
        _postBannerMessage = "กำลังสร้างโพสต์...";
      });
      widget.postCreationFuture!
          .then((response) async {
            if (response.statusCode == 201) {
              setState(() {
                _postBannerMessage = "โพสต์สร้างเสร็จสมบูรณ์";
              });
            } else {
              setState(() {
                _postBannerMessage = "เกิดข้อผิดพลาดในการสร้างโพสต์";
              });
            }
            await Future.delayed(const Duration(seconds: 3));
            setState(() {
              _postBannerMessage = null;
            });
          })
          .catchError((error) {
            setState(() {
              _postBannerMessage = "เกิดข้อผิดพลาด";
            });
            Future.delayed(const Duration(seconds: 3), () {
              setState(() {
                _postBannerMessage = null;
              });
            });
          });
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final userResponse = await http.get(
        Uri.parse('${Config.baseUrl}/get-user/${widget.userId}'),
      );
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        final catsResponse = await http.get(
          Uri.parse('${Config.baseUrl}/get-cats/${widget.userId}'),
        );
        if (catsResponse.statusCode == 200) {
          final catsData = jsonDecode(catsResponse.body);
          setState(() {
            username = userData['username'];
            profileImagePath = userData['profile_image_path'];
            _cats.clear();
            for (var cat in catsData) {
              _cats.add({
                'cat_id': cat['cat_id'].toString(),
                'name': cat['cat_name'],
                'breed': cat['cat_breed'],
                'color': cat['cat_color'],
                'prominent_point': cat['cat_prominent_point'],
                'state': cat['state'],
                'image_path': cat['image_path'],
              });
            }
          });
        } else {
          setState(() {
            _cats.clear();
          });
        }
      } else {
        setState(() {
          username = 'Unknown';
          _cats.clear();
        });
      }
    } catch (e) {
      setState(() {
        username = 'Error';
        _cats.clear();
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _fetchUserData();
    }
    if (index == 4) {
      _fetchUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      FeedPage(userId: widget.userId),
      MapPage(),
      PostPage(userId: widget.userId),
      AccountPage(userId: widget.userId),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 223, 223),
      body: Column(
        children: [
          if (widget.postCreationFuture != null && _postBannerMessage != null)
            Container(
              width: double.infinity,
              color: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  _postBannerMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(child: IndexedStack(index: _selectedIndex, children: pages)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey, width: 1.0)),
        ),
        child: BottomAppBar(
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.home,
                  size: 32,
                  color: _selectedIndex == 0 ? Colors.blue : Colors.grey[800],
                ),
                onPressed: () => _onItemTapped(0),
              ),
              IconButton(
                icon: Icon(
                  Icons.search,
                  size: 32,
                  color: _selectedIndex == 1 ? Colors.blue : Colors.grey[800],
                ),
                onPressed: () => _onItemTapped(1),
              ),
              IconButton(
                icon: Icon(
                  Icons.public,
                  size: 32,
                  color: _selectedIndex == 2 ? Colors.blue : Colors.grey[800],
                ),
                onPressed: () => _onItemTapped(2),
              ),
              IconButton(
                icon: Icon(
                  Icons.post_add,
                  size: 32,
                  color: _selectedIndex == 3 ? Colors.blue : Colors.grey[800],
                ),
                onPressed: () => _onItemTapped(3),
              ),
              // Bottom navigation icon for Account with badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.account_circle, size: 32),
                    color: _selectedIndex == 4 ? Colors.blue : Colors.grey[800],
                    onPressed: () => _onItemTapped(4),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child:
                        NotificationRepository().unreadCount > 0
                            ? Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${NotificationRepository().unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                            : const SizedBox(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Cat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildCatList(),
                  const SizedBox(height: 8),
                  _buildAddCatButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage:
                profileImagePath.isNotEmpty
                    ? NetworkImage('${Config.baseUrl}/$profileImagePath')
                    : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
            backgroundColor: Colors.grey[400],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              'Hi, $username',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ปุ่ม notifications บน top bar
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, size: 28),
                onPressed: () {
                  Navigator.pushNamed(context, '/notification').then((_) {
                    setState(() {}); // รีเฟรช badge เมื่อกลับมา
                  });
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child:
                    NotificationRepository().unreadCount > 0
                        ? Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${NotificationRepository().unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                        : const SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatList() {
    if (_cats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No cats registered yet. Add one now!',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    return Column(children: _cats.map((cat) => _buildCatCard(cat)).toList());
  }

  Widget _buildCatCard(Map<String, String> cat) {
    final isLost = (cat['state'] ?? '').toLowerCase() == 'lost';
    final stateLabel = isLost ? 'LOST' : 'HOME';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => EditCatInfoPage(
                  catId: cat['cat_id']!,
                  userId: widget.userId,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image:
                          cat['image_path'] != null &&
                                  cat['image_path']!.isNotEmpty
                              ? NetworkImage(
                                '${Config.baseUrl}/${cat['image_path']}',
                              )
                              : const AssetImage(
                                    'assets/images/default_cat.png',
                                  )
                                  as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Breed: ${cat['breed'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Color: ${cat['color'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLost ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stateLabel,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCatButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterCatPage(userId: widget.userId),
          ),
        );
        if (result != null && result is Map<String, String?>) {
          final newCat = result.map((key, value) => MapEntry(key, value ?? ''));
          setState(() {
            _cats.add(newCat);
          });
        }
      },
      child: Container(
        height: 100,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add, size: 40, color: Colors.black),
            SizedBox(height: 8),
            Text(
              'Add more cat',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
