import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'select_photo_options_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

class RegisterCatPage extends StatefulWidget {
  final String userId;
  const RegisterCatPage({Key? key, required this.userId}) : super(key: key);

  @override
  _RegisterCatPageState createState() => _RegisterCatPageState();
}

class _RegisterCatPageState extends State<RegisterCatPage> {
  File? _image;
  OverlayEntry? overlayEntry;
  final _formKey = GlobalKey<FormState>();
  final List<XFile> _imageFiles = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _prominentPointController =
      TextEditingController();

  void showCustomOverlay(BuildContext context) {
    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: 100,
            left: 50,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'This is Pop-up',
                      style: TextStyle(color: Colors.white),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          overlayEntry?.remove();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  Future _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;
      File? img = File(image.path);
      img = await _cropImage(imageFile: img);
      if (img != null) {
        setState(() {
          _imageFiles.add(XFile(img!.path)); // Add cropped image to the list
        });
      }
      Navigator.of(context).pop();
    } on PlatformException catch (e) {
      print(e);
      Navigator.of(context).pop();
    }
  }

  Future<File?> _cropImage({required File imageFile}) async {
    CroppedFile? croppedImage = await ImageCropper().cropImage(
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
    if (croppedImage == null) return null;
    return File(croppedImage.path);
  }

  void _showSelectPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.28,
            maxChildSize: 0.4,
            minChildSize: 0.28,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: SelectPhotoOptionsScreen(onTap: _pickImage),
              );
            },
          ),
    );
  }

  Future<List<http.MultipartFile>> prepareImageFiles(List<XFile> files) async {
    return await Future.wait(
      files.map((xfile) async {
        final bytes = await xfile.readAsBytes();
        return http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: xfile.name,
          contentType: MediaType.parse('image/jpeg'),
        );
      }),
    );
  }

  Future<void> _registerCat() async {
    if (_formKey.currentState!.validate() && _imageFiles.length >= 5) {
      final String catName = _nameController.text.trim();
      final String catBreed = _breedController.text.trim();
      final String catColor = _colorController.text.trim();
      final String catProminentPoint = _prominentPointController.text.trim();

      final uri = Uri.parse('${Config.baseUrl}/register-cat');
      final request = http.MultipartRequest('POST', uri);

      // เพิ่มข้อมูลฟอร์ม
      request.fields['cat_name'] = catName;
      request.fields['cat_breed'] = catBreed;
      request.fields['cat_color'] = catColor;
      request.fields['cat_prominent_point'] = catProminentPoint;
      request.fields['user_id'] = widget.userId;

      for (var xfile in _imageFiles) {
        final bytes = await xfile.readAsBytes();
        final mimeType = 'image/jpeg'; // Change this based on actual file type

        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: xfile.name,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cat registered successfully! ')),
          );
          Navigator.pop(context);
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select at least 5 images.'),
        ),
      );
    }
  }

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

        // Align the label to the left
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon:
                icon != null
                    ? Icon(icon, color: Colors.white)
                    : null, // Set icon color to white
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[700],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Register Your Cat',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
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
              // Single container for both the image upload and form fields
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Images (at least 5)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          _imageFiles.isNotEmpty
                              ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _imageFiles.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Stack(
                                      children: [
                                        FutureBuilder(
                                          future:
                                              _imageFiles[index].readAsBytes(),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                    ConnectionState.done &&
                                                snapshot.hasData) {
                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  snapshot.data as Uint8List,
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                              );
                                            } else {
                                              return Container(
                                                width: 120,
                                                height: 120,
                                                alignment: Alignment.center,
                                                child:
                                                    const CircularProgressIndicator(),
                                              );
                                            }
                                          },
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _imageFiles.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                              : const Center(
                                child: Text(
                                  'อัพโหลดรูปแมวอย่างน้อย 5 รูป',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                    ),

                    // Center the button above the text fields
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: ElevatedButton(
                          onPressed: () => _showSelectPhotoOptions(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black, // Background color
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 32,
                            ), // Padding for the button
                          ),
                          child: Text(
                            'Add a Photo',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    // Add space between button and form
                    // Form fields inside the same container
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      placeholder: 'แมวตัวนี้ชื่ออะไร?',
                      icon: Icons.pets,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _breedController,
                      label: 'Breed',
                      placeholder: 'แมวตัวนี้สายพันธุ์อะไร?',
                      icon: Icons.pets,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _colorController,
                      label: 'Color',
                      placeholder: 'แมวตัวนี้สีอะไร?',
                      icon: Icons.color_lens_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _prominentPointController,
                      label: 'Prominent Point',
                      placeholder: 'แมวตัวนี้มีลักษณะเด่นตรงไหนบ้าง?',
                      icon: Icons.star,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: _registerCat,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 32,
                          ),
                          backgroundColor: Colors.black,
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
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
