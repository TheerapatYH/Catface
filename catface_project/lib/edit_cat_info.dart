import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_catface/config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http_parser/http_parser.dart';

class EditCatInfoPage extends StatefulWidget {
  final String catId;
  final String userId;
  const EditCatInfoPage({Key? key, required this.catId, required this.userId})
    : super(key: key);

  @override
  _EditCatInfoPageState createState() => _EditCatInfoPageState();
}

class _EditCatInfoPageState extends State<EditCatInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _prominentPointController =
      TextEditingController();

  // รายการ URL รูปที่ได้จาก DB
  List<String> currentImageUrls = [];
  // รายการรูปใหม่ที่ผู้ใช้เพิ่ม (XFile)
  final List<XFile> newImageFiles = [];
  // รายการรูปที่ผู้ใช้ต้องการลบ
  List<String> imagesToDelete = [];

  @override
  void initState() {
    super.initState();
    _fetchCatInfo();
  }

  Future<void> _fetchCatInfo() async {
    try {
      final url = Uri.parse('${Config.baseUrl}/get-cat-info/${widget.catId}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _nameController.text = data['cat_name'] ?? '';
          _breedController.text = data['cat_breed'] ?? '';
          _colorController.text = data['cat_color'] ?? '';
          _prominentPointController.text = data['cat_prominent_point'] ?? '';
          currentImageUrls = List<String>.from(data['images'] ?? []);
        });
      } else {
        print('Failed to load cat info');
      }
    } catch (e) {
      print('Error fetching cat info: $e');
    }
  }

  // เลือกรูปจาก gallery แล้ว crop
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) return;
      File? cropped = await _cropImage(File(pickedFile.path));
      if (cropped != null) {
        setState(() {
          newImageFiles.add(XFile(cropped.path));
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'กรุณาครอปให้เหลือแค่หน้าแมว',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'กรุณาครอปให้เหลือแค่หน้าแมว'),
      ],
    );
    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  // ลบรูปที่มีอยู่ใน currentImageUrls
  void _removeCurrentImage(String imageUrl) {
    setState(() {
      imagesToDelete.add(imageUrl);
      currentImageUrls.remove(imageUrl);
    });
  }

  // ส่งข้อมูลไป update cat info
  Future<void> _updateCatInfo() async {
    if (_formKey.currentState!.validate()) {
      try {
        final uri = Uri.parse(
          '${Config.baseUrl}/update-cat-info/${widget.catId}',
        );
        final request = http.MultipartRequest('POST', uri);

        // ส่งข้อมูลฟอร์ม
        request.fields['cat_name'] = _nameController.text;
        request.fields['cat_breed'] = _breedController.text;
        request.fields['cat_color'] = _colorController.text;
        request.fields['cat_prominent_point'] = _prominentPointController.text;
        request.fields['images_to_delete'] = jsonEncode(imagesToDelete);
        request.fields['cat_id'] = widget.catId;
        request.fields['user_id'] = widget.userId;

        // ส่งรูปใหม่ถ้ามี
        for (var xfile in newImageFiles) {
          final bytes = await xfile.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'new_images',
              bytes,
              filename: xfile.name,
              contentType: MediaType.parse('image/jpeg'),
            ),
          );
        }

        final responseStream = await request.send();
        final response = await http.Response.fromStream(responseStream);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cat info updated successfully!')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update failed: ${response.body}')),
          );
        }
      } catch (e) {
        print('Error updating cat info: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating cat info: $e')));
      }
    }
  }

  // ฟังก์ชันสร้าง TextFormField ที่มี label อยู่เหนือกล่อง
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator:
              (value) =>
                  value == null || value.isEmpty ? 'Please enter $label' : null,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: icon != null ? Icon(icon, color: Colors.black54) : null,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // แสดงรูปที่มีอยู่พร้อมปุ่มลบ
  Widget _buildCurrentImages() {
    return currentImageUrls.isNotEmpty
        ? SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: currentImageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = currentImageUrls[index];
              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage('${Config.baseUrl}/$imageUrl'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => _removeCurrentImage(imageUrl),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        )
        : const Text('No images');
  }

  // แสดงรูปใหม่ที่เพิ่มเข้ามาพร้อมปุ่มลบ
  Widget _buildNewImages() {
    return newImageFiles.isNotEmpty
        ? SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: newImageFiles.length,
            itemBuilder: (context, index) {
              final file = newImageFiles[index];
              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(file.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          newImageFiles.removeAt(index);
                        });
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        )
        : const SizedBox();
  }

  // ปุ่มเพิ่มรูปใหม่
  Widget _buildAddImageButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, // Background color
      ),
      onPressed: () => _pickImage(ImageSource.gallery),
      child: const Text('Add New Image', style: TextStyle(color: Colors.blue)),
    );
  }

  // ฟังก์ชันสำหรับแสดง dialog ยืนยันการลบแมว
  Future<void> _confirmDeleteCat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Confirm Delete Cat'),
          content: const Text('คุณแน่ใจว่าจะลบแมวตัวนี้ใช่มั้ย?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancle', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      _deleteCat();
    }
  }

  // ฟังก์ชันเรียก backend เพื่อลบแมวออกจากฐานข้อมูล
  Future<void> _deleteCat() async {
    final url = Uri.parse('${Config.baseUrl}/delete-cat/${widget.catId}');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cat deleted successfully!')),
        );
        Navigator.pop(context, true); // ปิดหน้า Edit หลังลบสำเร็จ
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting cat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Cat Info',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[300],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Cat Name',
                placeholder: 'Enter cat name',
                icon: Icons.pets,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _breedController,
                label: 'Breed',
                placeholder: 'Enter cat breed',
                icon: Icons.pets,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _colorController,
                label: 'Color',
                placeholder: 'Enter cat color',
                icon: Icons.color_lens_outlined,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _prominentPointController,
                label: 'Prominent Point',
                placeholder: 'Enter cat prominent feature',
                icon: Icons.star,
              ),
              const SizedBox(height: 20),
              const Text(
                'Current Images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              _buildCurrentImages(),
              const SizedBox(height: 10),
              const Text(
                'New Images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              _buildNewImages(),
              Center(child: _buildAddImageButton()),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _confirmDeleteCat,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 30),
                    ElevatedButton(
                      onPressed: _updateCatInfo,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.grey[800],
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
