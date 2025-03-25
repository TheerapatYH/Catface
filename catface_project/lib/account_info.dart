import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'config.dart';

class AccountInfoPage extends StatefulWidget {
  final String userId;

  const AccountInfoPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // เก็บ path รูปโปรไฟล์จากฐานข้อมูล (เช่น "uploads/user_profile/10000003.png")
  String? _profileImagePath;

  // ไฟล์รูปใหม่ที่ผู้ใช้เลือก (ถ้ามี)
  File? _newProfileImageFile;

  // Base URL ของ server
  final String baseUrl = '${Config.baseUrl}';

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  // ดึงข้อมูลผู้ใช้จาก API
  Future<void> _fetchUserInfo() async {
    try {
      final url = Uri.parse('${Config.baseUrl}/get-user-info/${widget.userId}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _nameController.text = data['username'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone_number'] ?? '';
          _profileImagePath = data['profile_image_path'] ?? '';
        });
      } else {
        print('Failed to load user info. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
  }

  // เลือกรูปจาก gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newProfileImageFile = File(pickedFile.path);
      });
    }
  }

  // ฟังก์ชันอัปเดตข้อมูลผู้ใช้
  Future<void> _updateUserInfo() async {
    try {
      final url = Uri.parse(
        '${Config.baseUrl}/update-user-info/${widget.userId}',
      );
      var request = http.MultipartRequest('POST', url);

      // ส่งฟิลด์ข้อความ
      request.fields['username'] = _nameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone_number'] = _phoneController.text;

      // หากมีไฟล์รูปใหม่ให้ใช้ไฟล์นั้น
      if (_newProfileImageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            _newProfileImageFile!.path,
          ),
        );
      }
      // กรณีที่ไม่ได้เลือกรูปใหม่ ให้ดึงไฟล์จาก URL ที่ได้จากฐานข้อมูล
      else if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
        final fullProfileUrl = '${Config.baseUrl}/$_profileImagePath';
        final response = await http.get(Uri.parse(fullProfileUrl));
        if (response.statusCode == 200) {
          // ดึงนามสกุลไฟล์จาก _profileImagePath
          String ext = p.extension(_profileImagePath!);
          request.files.add(
            http.MultipartFile.fromBytes(
              'profile_image',
              response.bodyBytes,
              filename: '${widget.userId}$ext',
            ),
          );
        } else {
          print(
            'Failed to download current profile image. Status code: ${response.statusCode}',
          );
        }
      }

      // ส่ง multipart request
      var responseStream = await request.send();
      if (responseStream.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        final respStr = await responseStream.stream.bytesToString();
        print('Update failed: ${responseStream.statusCode}, $respStr');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $respStr')));
      }
    } catch (e) {
      print('Error updating user info: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating user info: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: Colors.grey),
    );

    // สร้าง URL เต็มสำหรับรูปโปรไฟล์ (ถ้ามี)
    String? fullProfileUrl;
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      fullProfileUrl = '${Config.baseUrl}/$_profileImagePath';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Your Account',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.grey[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // รูปโปรไฟล์ (tap เพื่อเลือกรูปใหม่)
            InkWell(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage:
                    _newProfileImageFile != null
                        ? FileImage(_newProfileImageFile!)
                        : (fullProfileUrl != null
                                ? NetworkImage(fullProfileUrl)
                                : const NetworkImage(
                                  'https://via.placeholder.com/150',
                                ))
                            as ImageProvider,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(4.0),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.edit, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Name',
              controller: _nameController,
              outlineBorder: outlineBorder,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              label: 'Email',
              controller: _emailController,
              outlineBorder: outlineBorder,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              label: 'Phone',
              controller: _phoneController,
              outlineBorder: outlineBorder,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              onPressed: _updateUserInfo,
              child: const Text(
                'Confirm',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required OutlineInputBorder outlineBorder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: outlineBorder,
          enabledBorder: outlineBorder,
          focusedBorder: outlineBorder.copyWith(
            borderSide: const BorderSide(color: Colors.black),
          ),
        ),
      ),
    );
  }
}
