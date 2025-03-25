import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // สำหรับการจัดรูปแบบ timestamp
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'config.dart';
import 'notification_service.dart';
import 'Map.dart'; // Import MapPage ใหม่ที่รองรับ parameter

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationItem> get notifications =>
      NotificationRepository().notifications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body:
          notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.separated(
                itemCount: notifications.length,
                separatorBuilder:
                    (context, index) =>
                        const Divider(height: 1, color: Colors.grey),
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.body),
                    trailing: Text(
                      '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      setState(() {
                        item.read = true;
                      });

                      String lostPostId = '';
                      String foundPostId = '';
                      if (item is MyExtendedNotificationItem &&
                          item.data != null) {
                        lostPostId = item.data!['lostPostId'] ?? '';
                        foundPostId = item.data!['foundPostId'] ?? '';
                        print(
                          'Notification data: lostPostId=$lostPostId, foundPostId=$foundPostId',
                        );
                      }

                      if (foundPostId.isNotEmpty) {
                        await _showMatchDetailsDialog(
                          title: item.title,
                          body: item.body,
                          endpoint:
                              '${Config.baseUrl}/foundcatpost/$foundPostId',
                          detailLabel: 'Post Details',
                        );
                      } else if (lostPostId.isNotEmpty) {
                        await _showMatchDetailsDialog(
                          title: item.title,
                          body: item.body,
                          endpoint: '${Config.baseUrl}/lostcatpost/$lostPostId',
                          detailLabel: 'Post Details',
                        );
                      } else {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text(item.title),
                                content: Text(item.body),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Close',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      }
                    },
                  );
                },
              ),
    );
  }

  Future<void> _showMatchDetailsDialog({
    required String title,
    required String body,
    required String endpoint,
    required String detailLabel,
  }) async {
    try {
      print("Calling endpoint: $endpoint");
      final response = await http.get(Uri.parse(endpoint));
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      if (response.statusCode == 200) {
        final detailData = jsonDecode(response.body);
        // ใช้ element แรกจาก list
        final details = detailData.isNotEmpty ? detailData[0] : {};

        // ดึงข้อมูลโพสต์
        final String location = details['location'] ?? 'N/A';
        final String breed = details['breed'] ?? 'N/A';
        final String color = details['color'] ?? 'N/A';
        final String prominentPoint = details['prominent_point'] ?? 'N/A';
        final String timestamp = details['time'] ?? '';
        String formattedTime = 'N/A';
        if (timestamp.isNotEmpty) {
          try {
            final parsedTime = DateTime.parse(timestamp);
            formattedTime = DateFormat('d/M/yyyy HH:mm').format(parsedTime);
          } catch (e) {
            formattedTime = timestamp;
          }
        }

        // ดึงรูปแมวจากฟิลด์ images (เป็น array)
        String? catImagePath;
        if (details['images'] != null &&
            details['images'] is List &&
            (details['images'] as List).isNotEmpty) {
          final firstImage = (details['images'] as List)[0];
          if (firstImage['image_path'] != null) {
            catImagePath = firstImage['image_path'];
          }
        }
        print("catImagePath: $catImagePath");

        // ดึงข้อมูลผู้โพสต์จาก API
        final String userId = details['user_id'] ?? '';
        Map<String, dynamic> userData = {};
        if (userId.isNotEmpty) {
          final userResponse = await http.get(
            Uri.parse('${Config.baseUrl}/get-user-info/$userId'),
          );
          if (userResponse.statusCode == 200) {
            userData = jsonDecode(userResponse.body);
          }
        }
        final String userName = userData['username'] ?? 'Unknown';
        final String userProfilePath = userData['profile_image_path'] ?? '';

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ข้อมูลผู้โพสต์ด้านบน (ชิดซ้าย)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage:
                                  userProfilePath.isNotEmpty
                                      ? NetworkImage(
                                        '${Config.baseUrl}/$userProfilePath',
                                      )
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                        // รูปโพสต์ (แมว) ด้วยกรอบมน และขนาดถูกจำกัด
                        if (catImagePath != null && catImagePath.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              '${Config.baseUrl}/$catImagePath',
                              height: 180,
                              width: 350,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  width: 350,
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
                            height: 180,
                            width: 350,
                            color: Colors.grey,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 16),
                        // รายละเอียดโพสต์
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location: $location',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Breed: $breed',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Color: $color',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prominent Point: $prominentPoint',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  // ปุ่ม "View on Map" อยู่ด้านล่างซ้าย (ถ้ามีข้อมูลตำแหน่ง)
                  Builder(
                    builder: (context) {
                      final String latStr = details['latitude'] ?? '';
                      final String lonStr = details['longitude'] ?? '';
                      double? latitude = double.tryParse(latStr);
                      double? longitude = double.tryParse(lonStr);
                      return latitude != null && longitude != null
                          ? TextButton(
                            onPressed: () {
                              Navigator.pop(context); // ปิด dialog ก่อน
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => MapPage(
                                        initialLocation: LatLng(
                                          latitude,
                                          longitude,
                                        ),
                                      ),
                                ),
                              );
                            },
                            child: const Text(
                              'View on Map',
                              style: TextStyle(color: Colors.blue),
                            ),
                          )
                          : const SizedBox();
                    },
                  ),
                  // ปุ่ม Close
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
        );
      } else {
        _showErrorDialog(
          'Could not fetch details. (Status: ${response.statusCode})',
        );
      }
    } catch (error) {
      _showErrorDialog('Error: $error');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
    );
  }
}
