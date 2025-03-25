import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'config.dart';
import 'find_with_ai.dart';
import 'Map.dart';

class FeedPage extends StatefulWidget {
  final String userId;
  final Future<http.StreamedResponse>? postCreationFuture;

  const FeedPage({Key? key, required this.userId, this.postCreationFuture})
    : super(key: key);

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _allPosts = [];
  final Map<String, dynamic> _userCache = {};
  String? _postBannerMessage;

  // Variables for search and filter
  String _searchQuery = '';
  bool _showLost = true;
  bool _showFound = true;
  double? _maxDistance; // in kilometers, null means no distance filter

  // ตัวแปรสำหรับตำแหน่งปัจจุบัน
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _fetchAllPosts();
    _getCurrentLocation();
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

  // ดึงตำแหน่งปัจจุบันด้วย Geolocator
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied.'),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
    });
  }

  Future<void> _fetchAllPosts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/get-all-posts'))
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
        allPosts.sort((a, b) {
          final aTime = DateTime.parse(a['time']);
          final bTime = DateTime.parse(b['time']);
          final compareTime = bTime.compareTo(aTime);
          if (compareTime != 0) {
            return compareTime;
          } else {
            return (a['post_id']).compareTo(b['post_id']);
          }
        });
        // ดึงข้อมูลผู้ใช้สำหรับแต่ละโพสต์
        for (var post in allPosts) {
          final userId = post['user_id'];
          if (!_userCache.containsKey(userId)) {
            final userData = await _fetchUserData(userId);
            _userCache[userId] = userData;
          }
        }
        setState(() {
          _allPosts = allPosts;
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
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _refreshPosts() async {
    await _fetchAllPosts();
  }

  // ฟังก์ชันคำนวณระยะทางด้วยสูตร Haversine
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // รัศมีโลกเป็นกิโลเมตร
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  // ฟังก์ชันกรองโพสต์ตามเงื่อนไขที่เลือก
  List<Map<String, dynamic>> _applyFilters() {
    return _allPosts.where((post) {
      final breed = (post['breed'] ?? '').toString().toLowerCase();
      final color = (post['color'] ?? '').toString().toLowerCase();
      final detail = (post['prominent_point'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty &&
          !breed.contains(query) &&
          !color.contains(query) &&
          !detail.contains(query)) {
        return false;
      }
      final postType = post['postType'] as String;
      if ((postType == 'lost' && !_showLost) ||
          (postType == 'found' && !_showFound)) {
        return false;
      }
      if (_maxDistance != null) {
        if (_currentLatitude == null || _currentLongitude == null) {
          return false;
        }
        final postLat = double.tryParse(post['latitude'] ?? '');
        final postLon = double.tryParse(post['longitude'] ?? '');
        if (postLat == null || postLon == null) {
          return false;
        }
        final distance = _calculateDistance(
          _currentLatitude!,
          _currentLongitude!,
          postLat,
          postLon,
        );
        if (distance > _maxDistance!) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.grey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหา',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FindWithAiPage(userId: widget.userId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text(
              'Find with AI',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _openFilterDialog,
            icon: const Icon(Icons.filter_list),
            color: Colors.black,
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันสร้าง Post Card สำหรับแต่ละโพสต์
  Widget _buildPostCard(Map<String, dynamic> post) {
    final postType = post['postType'] as String;
    final breed = post['breed'] ?? '';
    final color = post['color'] ?? '';
    final prominentPoint = post['prominent_point'] ?? '';
    final location = post['location'] ?? '';
    final timeStr = post['time'] ?? '';
    final dateTime = DateTime.tryParse(timeStr);
    final formattedTime =
        dateTime != null
            ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'
            : timeStr;
    final userId = post['user_id'];
    final userData = _userCache[userId] ?? {};
    final userName = userData['username'] ?? 'Unknown';
    final email = userData['email'] ?? '';
    final phoneNumber = userData['phone_number'] ?? '';
    final profileImagePath = userData['profile_image_path'] ?? '';
    final userImageProvider =
        profileImagePath.isNotEmpty
            ? NetworkImage('${Config.baseUrl}/$profileImagePath')
            : const AssetImage('assets/images/default_profile.png')
                as ImageProvider;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ข้อมูลผู้โพสต์
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 24, backgroundImage: userImageProvider),
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
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: postType == 'lost' ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  postType == 'lost' ? 'LOST' : 'FOUND',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // รูปโพสต์
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (firstImagePath != null && firstImagePath.isNotEmpty)
                Container(
                  width: 150,
                  height: 150,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 8),
                  color: Colors.grey[400],
                  child: const Icon(Icons.image, size: 50, color: Colors.white),
                ),
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
                            text: '$breed\n',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const TextSpan(
                            text: 'Color: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: '$color',
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
                            text: '$prominentPoint\n',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const TextSpan(
                            text: 'Location: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: '$location',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16, color: Colors.black),
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
                        const Icon(Icons.phone, size: 16, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(phoneNumber, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ปุ่ม View on Map ด้านล่างของ Card
          Align(
            alignment: Alignment.bottomLeft,
            child: TextButton.icon(
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
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    final filteredPosts = _applyFilters();

    return ListView.builder(
      itemCount: filteredPosts.length,
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        return _buildPostCard(post);
      },
    );
  }

  // ฟังก์ชันสำหรับเปิด Filter Dialog (โค้ดของคุณ)
  Future<void> _openFilterDialog() async {
    bool tempShowLost = _showLost;
    bool tempShowFound = _showFound;
    double? tempMaxDistance = _maxDistance;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'ตั้งค่าตัวกรอง',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text(
                      'แสดงโพสต์ LOST',
                      style: TextStyle(color: Colors.black),
                    ),
                    value: tempShowLost,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      setStateDialog(() {
                        tempShowLost = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'แสดงโพสต์ FOUND',
                      style: TextStyle(color: Colors.black),
                    ),
                    value: tempShowFound,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      setStateDialog(() {
                        tempShowFound = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'กรองโพสต์ตามระยะทาง',
                    style: TextStyle(color: Colors.black),
                  ),
                  DropdownButton<double?>(
                    value: tempMaxDistance,
                    hint: const Text(
                      'เลือกระยะทาง',
                      style: TextStyle(color: Colors.black),
                    ),
                    items:
                        <double?>[null, 1, 5, 10].map((distance) {
                          String text =
                              distance == null
                                  ? 'ทั้งหมด'
                                  : 'ไม่เกิน ${distance.toStringAsFixed(0)} กม.';
                          return DropdownMenuItem<double?>(
                            value: distance,
                            child: Text(
                              text,
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        tempMaxDistance = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('ตกลง', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                setState(() {
                  _showLost = tempShowLost;
                  _showFound = tempShowFound;
                  _maxDistance = tempMaxDistance;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(15.0),
        child: AppBar(backgroundColor: Colors.grey),
      ),
      backgroundColor: Colors.grey[300],
      body: Column(
        children: [
          _buildSearchBar(),
          if (_postBannerMessage != null)
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
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _refreshPosts,
                      child: _buildPostList(),
                    ),
          ),
        ],
      ),
    );
  }
}
