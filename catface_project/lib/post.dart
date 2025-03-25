import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_catface/Home.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart'; // ใช้ image_picker
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'config.dart';
import 'map_for_post_page.dart'; // Import หน้า MapForPostPage

class PostPage extends StatefulWidget {
  final String userId;

  const PostPage({Key? key, required this.userId}) : super(key: key);

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _userCats = [];
  String _postType = 'Found cat'; // ตั้งต้นเป็น Found cat
  String? _selectedCatId;

  // เปลี่ยนเป็น "Location Detail" ให้ผู้ใช้กรอกเอง
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _prominentPointController =
      TextEditingController();

  List<String> _catImages = []; // สำหรับ Lost cat
  List<XFile> _pickedImages = []; // สำหรับ Found cat

  // ตัวแปรสำหรับตำแหน่งที่เลือก (จะใช้แทนตำแหน่งปัจจุบัน)
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _fetchUserCats();
    _getCurrentLocation();
  }

  // ดึงตำแหน่งปัจจุบัน (ใช้สำหรับค่าเริ่มต้น)
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
      // ไม่เติมค่าใน _locationController เพราะให้ผู้ใช้กรอกเองเป็น Location Detail
    });
  }

  Future<void> _fetchUserCats() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/get-user-cats/${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> formattedData =
            data.map((cat) => Map<String, dynamic>.from(cat)).toList();
        setState(() {
          _userCats.clear();
          _userCats.addAll(formattedData);
        });
      } else {
        debugPrint('Failed to fetch user cats: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching user cats: $e');
    }
  }

  // ฟังก์ชันสำหรับครอปรูป (ใช้ ImageCropper)
  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );
    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  // ฟังก์ชันเลือกภาพที่มีการครอปทีละภาพ
  Future<void> _pickImages() async {
    final ImagePicker _picker = ImagePicker();
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      List<XFile> croppedImages = [];
      for (var image in images) {
        File? cropped = await _cropImage(File(image.path));
        if (cropped != null) {
          croppedImages.add(XFile(cropped.path));
        } else {
          // ถ้าครอปถูกยกเลิก ให้เพิ่มภาพเดิมเข้าไป (หรือสามารถเลือกไม่เพิ่มก็ได้)
          croppedImages.add(image);
        }
      }
      setState(() {
        _pickedImages = croppedImages;
      });
    }
  }

  Future<void> _loadCatImages(String catId) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/get-cat-images/$catId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _catImages =
              data.map((item) => item['image_path'].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching images: $e');
    }
  }

  Future<void> _submitPost() async {
    if (_currentLatitude == null || _currentLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถดึงตำแหน่งที่เลือกได้')),
      );
      return;
    }
    if (_formKey.currentState!.validate() &&
        ((_postType == 'Found cat' && _pickedImages.isNotEmpty) ||
            (_postType == 'Lost cat' && _selectedCatId != null))) {
      try {
        final localTime = DateTime.now().toUtc().add(const Duration(hours: 7));
        final formattedTime = DateFormat(
          "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        ).format(localTime);

        final uri = Uri.parse(
          '${Config.baseUrl}/${_postType == 'Lost cat' ? 'lost-cat-post' : 'found-cat-post'}',
        );
        final request = http.MultipartRequest('POST', uri);
        request.fields['user_id'] = widget.userId;
        // ใช้ Location Detail ที่ผู้ใช้กรอกเอง
        request.fields['location'] = _locationController.text;
        request.fields['breed'] = _breedController.text;
        request.fields['color'] = _colorController.text;
        request.fields['prominent_point'] = _prominentPointController.text;
        request.fields['time'] = formattedTime;

        // ส่งตำแหน่งที่ผู้ใช้เลือกใน MapForPostPage
        request.fields['latitude'] = _currentLatitude.toString();
        request.fields['longitude'] = _currentLongitude.toString();

        if (_postType == 'Lost cat' && _selectedCatId != null) {
          request.fields['cat_id'] = _selectedCatId!;
          for (String imagePath in _catImages) {
            final url = '${Config.baseUrl}/$imagePath';
            final imageResponse = await http.get(Uri.parse(url));
            if (imageResponse.statusCode == 200) {
              final filename = imagePath.split('/').last;
              request.files.add(
                http.MultipartFile.fromBytes(
                  'images',
                  imageResponse.bodyBytes,
                  filename: filename,
                ),
              );
            }
          }
        } else if (_postType == 'Found cat') {
          for (final image in _pickedImages) {
            final bytes = await image.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'images',
                bytes,
                filename: image.name,
              ),
            );
          }
        }

        final postCreationFuture = request.send();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => HomePage(
                  userId: widget.userId,
                  postCreationFuture: postCreationFuture,
                ),
          ),
        );
      } catch (e) {
        debugPrint('Error: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'กรุณากรอกข้อมูลให้ครบถ้วน และสำหรับ Lost Cat ให้เลือกแมวจากรายการ\nสำหรับ Found Cat ให้เลือกอัปโหลดรูปอย่างน้อย 1 รูป',
          ),
        ),
      );
    }
  }

  // --- UI Widgets ---

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        value: _postType,
        items:
            ['Found cat', 'Lost cat'].map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _postType = newValue!;
          });
          if (_postType == 'Lost cat') {
            _fetchUserCats();
          }
        },
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                _pickedImages.isNotEmpty
                    ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pickedImages.length,
                      itemBuilder: (context, index) {
                        final image = _pickedImages[index];
                        return Container(
                          margin: const EdgeInsets.all(8),
                          width: 120,
                          height: 120,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(image.path),
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _pickedImages.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a cat image from Gallery\nJPEG, JPG, PNG formats, up to 50MB',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _pickImages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                          ),
                          child: const Text(
                            'Browse Image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildLostCatDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Cat',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_userCats.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              'No cats available for Lost Post',
              style: TextStyle(color: Colors.red),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCatId,
              items:
                  _userCats.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['cat_id'].toString(),
                      child: Text(cat['cat_name'] ?? 'Unnamed'),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCatId = newValue;
                });
                if (_selectedCatId != null) {
                  _loadCatImages(_selectedCatId!);
                }
              },
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        if (_catImages.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _catImages.length,
              itemBuilder: (context, index) {
                final imgPath = _catImages[index];
                return Container(
                  margin: const EdgeInsets.all(8),
                  child: Image.network(
                    '${Config.baseUrl}/$imgPath',
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
      ],
    );
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator:
              (value) =>
                  (value == null || value.isEmpty)
                      ? 'Please enter $label'
                      : null,
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: icon != null ? Icon(icon) : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
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
        backgroundColor: Colors.grey[800],
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Post lost/found cat',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select type of post',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTypeDropdown(),
              const SizedBox(height: 16),
              if (_postType == 'Found cat') _buildImageUploadSection(),
              if (_postType == 'Lost cat') _buildLostCatDropdown(),
              const SizedBox(height: 16),
              // ปุ่มสำหรับเลือกตำแหน่งจากแผนที่ (นำไปยัง MapForPostPage แยกไฟล์)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Colors.grey[800],
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => MapForPostPage(
                            initialLat: _currentLatitude,
                            initialLng: _currentLongitude,
                          ),
                    ),
                  );
                  if (result != null && result is LatLng) {
                    setState(() {
                      _currentLatitude = result.latitude;
                      _currentLongitude = result.longitude;
                      // ไม่อัปเดตค่าใน _locationController เพราะผู้ใช้จะกรอก "Location Detail" ด้วยตนเอง
                    });
                  }
                },
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text(
                  "Select Location on Map",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              // เปลี่ยน label เป็น "Location Detail" ให้ผู้ใช้กรอกเอง
              _buildTextField(
                controller: _locationController,
                label: 'Location Detail',
                placeholder:
                    _postType == 'Lost cat'
                        ? 'ระบุรายละเอียดสถานที่ที่แมวหาย'
                        : 'ระบุรายละเอียดสถานที่ที่พบแมว',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _breedController,
                label: 'Breed',
                placeholder: 'แมวตัวนี้สายพันธุ์อะไร',
                icon: Icons.pets,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _colorController,
                label: 'Color',
                placeholder: 'แมวตัวนี้สีอะไร',
                icon: Icons.color_lens_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _prominentPointController,
                label: 'Post Detail',
                placeholder: 'รายละเอียดเพิ่มเติม เช่น ลักษณะเด่นแมว',
                icon: Icons.description_outlined,
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.grey[800],
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
