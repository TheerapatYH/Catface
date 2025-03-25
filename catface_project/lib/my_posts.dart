import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
// import 'edit_post_page.dart'; // ถ้าต้องการหน้าแก้ไข
// import 'post_model.dart'; // ถ้าต้องการสร้าง Model

class MyPostsPage extends StatefulWidget {
  final String userId;

  const MyPostsPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _myPosts = [];

  @override
  void initState() {
    super.initState();
    _fetchUserPosts();
  }

  Future<void> _fetchUserPosts() async {
    setState(() => _isLoading = true);
    try {
      final url = '${Config.baseUrl}/get-user-posts/${widget.userId}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lostPosts = data['lostPosts'] as List<dynamic>;
        final foundPosts = data['foundPosts'] as List<dynamic>;

        List<Map<String, dynamic>> allPosts = [];
        for (var post in lostPosts) {
          final p = Map<String, dynamic>.from(post);
          p['postType'] = 'lost';
          allPosts.add(p);
        }
        for (var post in foundPosts) {
          final p = Map<String, dynamic>.from(post);
          p['postType'] = 'found';
          allPosts.add(p);
        }

        // เรียงตาม time DESC (หรือ post_id)
        allPosts.sort((a, b) {
          final aTime = DateTime.parse(a['time']);
          final bTime = DateTime.parse(b['time']);
          return bTime.compareTo(aTime); // DESC
        });

        setState(() {
          _myPosts = allPosts;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// เรียกใช้ endpoint ลบโพสต์ (update DB)
  Future<void> _deletePost(Map<String, dynamic> post) async {
    final postId = post['post_id'];
    final postType = post['postType']; // 'lost' or 'found'

    try {
      final deleteUrl =
          (postType == 'lost')
              ? '${Config.baseUrl}/delete-lost-post/$postId'
              : '${Config.baseUrl}/delete-found-post/$postId';

      final response = await http.delete(Uri.parse(deleteUrl));
      if (response.statusCode == 200) {
        // ลบสำเร็จ => ลบออกจาก List
        setState(() {
          _myPosts.remove(post);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete Error: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete Error: $e')));
    }
  }

  void _editPost(Map<String, dynamic> post) {
    _showEditDialog(post);
  }

  void _showEditDialog(Map<String, dynamic> post) {
    // รับค่าเริ่มต้นจาก post
    final TextEditingController breedController = TextEditingController(
      text: post['breed'] ?? '',
    );
    final TextEditingController colorController = TextEditingController(
      text: post['color'] ?? '',
    );
    final TextEditingController detailController = TextEditingController(
      text: post['prominent_point'] ?? '',
    );
    final TextEditingController locationController = TextEditingController(
      text: post['location'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            post['postType'] == 'lost'
                ? 'Edit Lost Cat Post'
                : 'Edit Found Cat Post',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: breedController,
                  decoration: const InputDecoration(labelText: 'Breed'),
                ),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(labelText: 'Color'),
                ),
                TextField(
                  controller: detailController,
                  decoration: const InputDecoration(labelText: 'Detail'),
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _updatePost(
                  post,
                  breedController.text,
                  colorController.text,
                  detailController.text,
                  locationController.text,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePost(
    Map<String, dynamic> post,
    String breed,
    String color,
    String detail,
    String location,
  ) async {
    final postId = post['post_id'];
    final postType = post['postType'];
    final updateUrl =
        (postType == 'lost')
            ? '${Config.baseUrl}/update-lost-post/$postId'
            : '${Config.baseUrl}/update-found-post/$postId';

    try {
      final response = await http.put(
        Uri.parse(updateUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'breed': breed,
          'color': color,
          'prominent_point': detail,
          'location': location,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully')),
        );
        _fetchUserPosts(); // รีเฟรชรายการโพสต์
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update Error: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: const Text('My Posts', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPostList(),
    );
  }

  Widget _buildPostList() {
    if (_myPosts.isEmpty) {
      return const Center(child: Text('No posts yet.'));
    }

    return ListView.builder(
      itemCount: _myPosts.length,
      itemBuilder: (context, index) {
        final post = _myPosts[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final postType = post['postType'] as String; // 'lost' or 'found'
    final postLabel = (postType == 'lost') ? 'LOST' : 'FOUND';
    final colorLabel = (postType == 'lost') ? Colors.red : Colors.blue;

    final location = post['location'] ?? '';
    final breed = post['breed'] ?? '';
    final color = post['color'] ?? '';
    final detail = post['prominent_point'] ?? '';
    final timeStr = post['time'] ?? '';
    final dateTime = DateTime.tryParse(timeStr);
    final formattedTime =
        (dateTime != null)
            ? '${dateTime.day}/${dateTime.month}/${dateTime.year} '
                '${dateTime.hour.toString().padLeft(2, '0')}:'
                '${dateTime.minute.toString().padLeft(2, '0')}'
            : timeStr;

    // Extract first image from the post
    String? firstImagePath;
    if (post['images'] != null &&
        post['images'] is List &&
        (post['images'] as List).isNotEmpty) {
      final firstImageObj = post['images'][0];
      if (firstImageObj is Map && firstImageObj.containsKey('image_path')) {
        firstImagePath = firstImageObj['image_path'] as String?;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Top row: label (LOST CAT / FOUND CAT) + edit/delete buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Post Type in a rectangular box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorLabel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  postLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editPost(post),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePost(post),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Image section
          Row(
            children: [
              // Image on the left
              if (firstImagePath != null && firstImagePath.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              const SizedBox(width: 16),
              // Details section (Location, Breed, Color, Detail)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Breed: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '$breed'),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Color: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '$color'),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Detail: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '$detail'),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Location: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '$location'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Timestamp: $formattedTime',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
