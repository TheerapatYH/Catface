import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';

import 'config.dart';

class MapPage extends StatefulWidget {
  final LatLng? initialLocation; // เพิ่ม parameter นี้

  const MapPage({Key? key, this.initialLocation}) : super(key: key);
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  CameraPosition? _initialPosition;
  Set<Marker> _markers = {};

  // เก็บโพสต์ทั้งหมด (lost + found)
  List<Map<String, dynamic>> _allPosts = [];

  // เก็บข้อมูล User เพื่อไม่ต้องดึงซ้ำ (user_id -> userData)
  final Map<String, dynamic> _userCache = {};

  @override
  void initState() {
    super.initState();
    // ถ้า initialLocation ถูกส่งมาใช้เป็นตำแหน่งเริ่มต้น
    if (widget.initialLocation != null) {
      _initialPosition = CameraPosition(
        target: widget.initialLocation!,
        zoom: 15,
      );
    } else {
      _getCurrentLocation();
    }
    _fetchAllPosts();
  }

  // -------------------------------
  // 1) ดึงตำแหน่งปัจจุบันของผู้ใช้
  // -------------------------------
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
          const SnackBar(content: Text('Location permissions are denied.')),
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
      _initialPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 15,
      );
    });
  }

  // -------------------------------
  // 2) ดึงข้อมูลโพสต์จาก Backend
  // -------------------------------
  Future<void> _fetchAllPosts() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/get-all-posts'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lostPosts = data['lostPosts'] as List<dynamic>;
        final foundPosts = data['foundPosts'] as List<dynamic>;

        List<Map<String, dynamic>> allPosts = [];

        // ใส่ flag postType ให้โพสต์ lost
        for (var post in lostPosts) {
          final p = Map<String, dynamic>.from(post);
          p['postType'] = 'lost';
          allPosts.add(p);
        }
        // ใส่ flag postType ให้โพสต์ found
        for (var post in foundPosts) {
          final p = Map<String, dynamic>.from(post);
          p['postType'] = 'found';
          allPosts.add(p);
        }

        // ดึงข้อมูล User สำหรับแต่ละโพสต์
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

        // สร้าง Marker เมื่อได้ข้อมูลโพสต์ครบ
        _createMarkers();
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

  // ดึงข้อมูล user จาก API
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

  // ฟังก์ชัน Refresh รวม: อัปเดตตำแหน่ง + ดึงโพสต์ใหม่
  Future<void> _refreshData() async {
    await _getCurrentLocation();
    await _fetchAllPosts();
  }

  // -----------------------------------------
  // 3) สร้าง Marker Icon แบบกำหนดเองจากรูป
  // -----------------------------------------
  Future<BitmapDescriptor> _getCustomMarkerFromUrl(
    String imageUrl,
    String postType,
  ) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        final markerBytes = await _createMarkerImageWithCanvas(
          imageBytes,
          postType: postType,
          size: 110, // ปรับขนาด Marker ให้เล็กลงหน่อย
        );
        return BitmapDescriptor.fromBytes(markerBytes);
      } else {
        // fallback ถ้ารูปโหลดไม่ได้
        return _getDefaultMarker(postType);
      }
    } catch (e) {
      // fallback ถ้ามี error
      return _getDefaultMarker(postType);
    }
  }

  // สร้าง Icon เริ่มต้น (Marker สีแดง/สีน้ำเงินแบบปกติ)
  BitmapDescriptor _getDefaultMarker(String postType) {
    return postType == 'lost'
        ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
        : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  }

  // วาดรูปบน Canvas ให้เป็น “หมุด” + ใส่รูปแมว (วงกลม) ด้านบน
  Future<Uint8List> _createMarkerImageWithCanvas(
    Uint8List imageBytes, {
    required String postType,
    required int size,
  }) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: size,
      targetHeight: size,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image catImage = frame.image;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint bgPaint =
        Paint()..color = (postType == 'lost') ? Colors.red : Colors.blue;

    final double circleRadius = size / 2;
    final double pointerHeight = 36; // ลดความสูงหมุดลงเล็กน้อย
    final double totalHeight = size + pointerHeight;

    // วาดวงกลมพื้นหลัง
    canvas.drawCircle(
      Offset(circleRadius, circleRadius),
      circleRadius,
      bgPaint,
    );

    // Clip รูปแมวให้เป็นวงกลมเล็กลง
    final double margin = 8;
    final double clippedRadius = circleRadius - margin;
    final Path circlePath =
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(circleRadius, circleRadius),
            radius: clippedRadius,
          ),
        );

    canvas.save();
    canvas.clipPath(circlePath);

    // วาดรูปแมวลงในกรอบวงกลม
    final Rect srcRect = Rect.fromLTWH(
      0,
      0,
      catImage.width.toDouble(),
      catImage.height.toDouble(),
    );
    final Rect destRect = Rect.fromLTWH(
      margin,
      margin,
      size - margin * 2,
      size - margin * 2,
    );
    canvas.drawImageRect(catImage, srcRect, destRect, Paint());
    canvas.restore();

    // วาดหมุด (triangle) ด้านล่าง
    final Path pointerPath = Path();
    pointerPath.moveTo(circleRadius - 20, size.toDouble());
    pointerPath.lineTo(circleRadius, totalHeight);
    pointerPath.lineTo(circleRadius + 20, size.toDouble());
    pointerPath.close();
    canvas.drawPath(pointerPath, bgPaint);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image finalImage = await picture.toImage(
      size,
      totalHeight.toInt(),
    );

    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  // -----------------------------------------
  // 4) สร้าง Marker จากข้อมูลโพสต์ทั้งหมด
  // -----------------------------------------
  Future<void> _createMarkers() async {
    Set<Marker> markers = {};

    for (var post in _allPosts) {
      double? lat = double.tryParse(post['latitude'] ?? '');
      double? lon = double.tryParse(post['longitude'] ?? '');
      if (lat == null || lon == null) continue;

      String postType = post['postType'] ?? 'lost';

      // เอารูปแรกของโพสต์ (ถ้ามี)
      String? firstImageUrl;
      if (post['images'] != null &&
          post['images'] is List &&
          (post['images'] as List).isNotEmpty) {
        final firstImageObj = post['images'][0];
        if (firstImageObj is Map && firstImageObj.containsKey('image_path')) {
          final path = firstImageObj['image_path'];
          firstImageUrl = '${Config.baseUrl}/$path';
        }
      }

      // สร้าง Marker icon
      BitmapDescriptor customIcon;
      if (firstImageUrl != null) {
        customIcon = await _getCustomMarkerFromUrl(firstImageUrl, postType);
      } else {
        customIcon = _getDefaultMarker(postType);
      }

      // สร้าง Marker
      final markerId = MarkerId(post['post_id'].toString());
      Marker marker = Marker(
        markerId: markerId,
        position: LatLng(lat, lon),
        icon: customIcon,
        // กดที่ Marker -> โชว์ Dialog
        onTap: () {
          _showPostDialog(post);
        },
      );
      markers.add(marker);
    }

    setState(() {
      _markers = markers;
    });
  }

  // -----------------------------------------
  // 5) แสดง Dialog รายละเอียดโพสต์
  // -----------------------------------------
  void _showPostDialog(Map<String, dynamic> post) {
    final postType = post['postType'] ?? '';
    final location = post['location'] ?? '';
    final breed = post['breed'] ?? '';
    final color = post['color'] ?? '';
    final detail = post['prominent_point'] ?? '';
    final timestr = post['time'] ?? '';
    final datetime = DateTime.tryParse(timestr);
    final formattedTime =
        datetime != null
            ? '${datetime.day}/${datetime.month}/${datetime.year} ${datetime.hour.toString().padLeft(2, '0')}:${datetime.minute.toString().padLeft(2, '0')}'
            : timestr;
    final images = post['images'];

    // รูปแรก
    String? firstImageUrl;
    if (images != null && images is List && images.isNotEmpty) {
      final firstImageObj = images[0];
      if (firstImageObj is Map && firstImageObj.containsKey('image_path')) {
        firstImageUrl = '${Config.baseUrl}/${firstImageObj['image_path']}';
      }
    }

    // ดึงข้อมูลผู้โพสต์จาก cache
    final userId = post['user_id'];
    final userData = _userCache[userId] ?? {};
    final userName = userData['username'] ?? 'Unknown';
    final profileImagePath = userData['profile_image_path'] ?? '';

    final userProfileImg =
        profileImagePath.isNotEmpty
            ? '${Config.baseUrl}/$profileImagePath'
            : null; // ถ้าไม่มีรูปให้เป็น null

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Colors.white,
          content: Container(
            constraints: const BoxConstraints(maxWidth: 350, maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // แสดง LOST หรือ FOUND
                  Container(
                    width: 70,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: postType == 'lost' ? Colors.red : Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      postType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // รูปโปรไฟล์ + ชื่อคนโพสต์ พร้อม formattedTime ใต้ชื่อ
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                            (userProfileImg != null)
                                ? NetworkImage(userProfileImg)
                                : const AssetImage(
                                      'assets/images/default_profile.png',
                                    )
                                    as ImageProvider,
                      ),
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
                            const SizedBox(height: 2),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // รูปแมว (เล็กลง)
                  if (firstImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        firstImageUrl,
                        fit: BoxFit.cover,
                        height: 220,
                        width: 220,
                        errorBuilder: (ctx, error, stack) {
                          return Container(
                            height: 150,
                            color: Colors.grey,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      color: Colors.grey,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // รายละเอียดโพสต์ พร้อมทำให้คำ Label เป็นตัวหนา
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Location: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: location,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Breed: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: breed,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Color: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: color,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
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
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: detail,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('ปิด', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // -----------------------------------------
  // 6) สร้างหน้า Map + ปุ่ม Refresh
  // -----------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post Map',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshData();
            },
          ),
        ],
      ),
      body:
          _initialPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: _initialPosition!,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) => _mapController = controller,
              ),
    );
  }
}
