import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'Map.dart';
import 'config.dart';

/// หน้า Find with AI
class FindWithAiPage extends StatefulWidget {
  final String userId;

  const FindWithAiPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<FindWithAiPage> createState() => _FindWithAiPageState();
}

class _FindWithAiPageState extends State<FindWithAiPage> {
  bool _isLoadingCats = false;
  bool _isLoadingPosts = false;

  /// รายการแมวของผู้ใช้ (เฉพาะที่มีสถานะ lost)
  List<Map<String, dynamic>> _lostCats = [];

  /// catId ที่เลือกใน dropdown
  String? _selectedCatId;

  /// รายการโพสต์ที่ match กับแมวตัวที่เลือก (Found Posts)
  List<Map<String, dynamic>> _matchedPostsWithUserData = [];

  @override
  void initState() {
    super.initState();
    _fetchLostCats();
  }

  /// ดึงข้อมูลแมวสถานะ lost ของ user จาก endpoint
  Future<void> _fetchLostCats() async {
    setState(() {
      _isLoadingCats = true;
    });
    try {
      final url = '${Config.baseUrl}/user-cat-lost/${widget.userId}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _lostCats =
              data.map((item) {
                return {'cat_id': item['cat_id'], 'cat_name': item['cat_name']};
              }).toList();
        });
      } else {
        debugPrint('Error fetching lost cats: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() {
        _isLoadingCats = false;
      });
    }
  }

  /// เมื่อเลือกแมวจาก dropdown แล้ว ดึงข้อมูล matched posts (Found Posts)
  Future<void> _fetchMatchedPosts(String catId) async {
    setState(() {
      _isLoadingPosts = true;
    });
    try {
      final url = '${Config.baseUrl}/matched-posts/$catId';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Map<String, dynamic>> posts =
            data.map((item) {
              return {
                'found_post_id': item['found_post_id'],
                'distance': item['distance'],
                'user_id': item['user_id'],
                'location': item['location'],
                'time': item['time'],
                'breed': item['breed'],
                'color': item['color'],
                'prominent_point': item['prominent_point'],
                'latitude': item['latitude'],
                'longitude': item['longitude'],
                'images': item['images'] as List<dynamic>?,
              };
            }).toList();

        // ดึงข้อมูลผู้ใช้สำหรับแต่ละโพสต์
        for (var post in posts) {
          final userId = post['user_id'];
          final userData = await _fetchUserData(userId);
          post['userData'] = userData;
        }

        // Sort posts by distance
        posts.sort((a, b) {
          final ad = double.tryParse(a['distance'] ?? '999999') ?? 999999;
          final bd = double.tryParse(b['distance'] ?? '999999') ?? 999999;
          return ad.compareTo(bd);
        });

        setState(() {
          _matchedPostsWithUserData = posts;
        });
      } else {
        debugPrint('Error fetching matched posts: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  /// ฟังก์ชันเรียก API ยืนยันแมว โดยใช้ cat_id เพื่อค้นหา lost post ของแมวที่หาย
  Future<void> _confirmCat(String catId) async {
    final url = '${Config.baseUrl}/confirm-found-cat';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cat_id': catId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _matchedPostsWithUserData.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confirmed successfully!')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/get-user-info/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Error fetching user data: ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('Error: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Find with AI',
          style: TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Column(
          children: [
            _buildSelectCatSection(),
            Expanded(child: _buildMatchedPostsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectCatSection() {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text(
            'Select your cat  ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child:
                _isLoadingCats
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCatId,
                      hint: const Text('Select cat'),
                      items:
                          _lostCats.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat['cat_id'],
                              child: Text(cat['cat_name'] ?? 'Unnamed'),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCatId = value;
                        });
                        if (value != null) {
                          _fetchMatchedPosts(value);
                        }
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// ฟังก์ชันแสดงรายการ matched posts
  Widget _buildMatchedPostsList() {
    if (_selectedCatId == null) {
      return const Center(child: Text('Please select a cat.'));
    }

    if (_isLoadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_matchedPostsWithUserData.isEmpty) {
      return const Center(child: Text('No matched posts found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: _matchedPostsWithUserData.length,
      itemBuilder: (context, index) {
        final post = _matchedPostsWithUserData[index];
        return _buildMatchCard(post, index);
      },
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> post, int index) {
    final timeStr = post['time'] ?? '';
    final dateTime = DateTime.tryParse(timeStr);
    final formattedTime =
        dateTime != null
            ? '${dateTime.day}/${dateTime.month}/${dateTime.year} '
                '${dateTime.hour.toString().padLeft(2, '0')}:'
                '${dateTime.minute.toString().padLeft(2, '0')}'
            : timeStr;

    final images = post['images'] as List<dynamic>?;
    String? firstImagePath;
    if (images != null && images.isNotEmpty) {
      firstImagePath = images.first as String?;
    }

    final userData = post['userData'] ?? {};
    final userName = userData['username'] ?? 'Unknown';
    final email = userData['email'] ?? '';
    final phoneNumber = userData['phone_number'] ?? '';
    final profileImagePath = userData['profile_image_path'] ?? '';
    final userImageProvider =
        profileImagePath.isNotEmpty
            ? NetworkImage('${Config.baseUrl}/$profileImagePath')
            : const AssetImage('assets/images/default_profile.png')
                as ImageProvider;

    return InkWell(
      onTap: () => _showConfirmDialog(post),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------- ส่วนข้อมูลผู้โพสต์ + เวลา -------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(radius: 22, backgroundImage: userImageProvider),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ------------------- ส่วนรูปแมว + รายละเอียด -------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // รูปแมวฝั่งซ้าย
                if (firstImagePath != null && firstImagePath.isNotEmpty)
                  Container(
                    width: 130,
                    height: 130,
                    margin: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${Config.baseUrl}/$firstImagePath',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: 150,
                    height: 150,
                    margin: const EdgeInsets.only(right: 12),
                    color: Colors.grey[400],
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),

                // รายละเอียดต่าง ๆ ฝั่งขวา
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Breed: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: '${post['breed'] ?? '-'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Color: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: '${post['color'] ?? '-'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Detail: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: '${post['prominent_point'] ?? '-'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Location: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: '${post['location'] ?? '-'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ข้อมูลติดต่อผู้โพสต์
                      Row(
                        children: [
                          const Icon(
                            Icons.email,
                            size: 16,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              email,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phoneNumber,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ------------------- ปุ่ม View on Map -------------------
            // หากต้องการให้ปุ่มอยู่ด้านซ้าย ใต้รูปแมวพอดี
            // อาจใช้ Align(alignment: Alignment.centerLeft, child: ...)
            TextButton.icon(
              onPressed: () {
                final lat = double.tryParse(post['latitude'] ?? '');
                final lon = double.tryParse(post['longitude'] ?? '');
                if (lat != null && lon != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              MapPage(initialLocation: LatLng(lat, lon)),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.map, color: Colors.blue),
              label: const Text(
                'View on Map',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(Map<String, dynamic> post) {
    final catId = _selectedCatId;
    if (catId == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Confirm this cat?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('ยืนยันว่านี่คือแมวของคุณใช่มั้ย?')],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.blue,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _confirmCat(catId);
              },
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
