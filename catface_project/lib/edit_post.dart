import 'package:flutter/material.dart';

class EditPostPage extends StatefulWidget {
  final Map<String, dynamic> postData;

  const EditPostPage({super.key, required this.postData});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController breedController;
  late TextEditingController colorController;
  late TextEditingController locationController;
  late TextEditingController timeController;

  final _formKey = GlobalKey<FormState>(); // สำหรับจัดการ Validation

  @override
  void initState() {
    super.initState();
    breedController = TextEditingController(text: widget.postData['breed'] ?? '');
    colorController = TextEditingController(text: widget.postData['color'] ?? '');
    locationController = TextEditingController(text: widget.postData['location'] ?? '');
    timeController = TextEditingController(text: widget.postData['time'] ?? '');
  }

  @override
  void dispose() {
    breedController.dispose();
    colorController.dispose();
    locationController.dispose();
    timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: const Color.fromARGB(255, 17, 17, 17),
      ),
      backgroundColor: const Color.fromARGB(255, 59, 59, 59),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Form(
            key: _formKey, // ใช้ Form และ key เพื่อ Validation
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.postData['title'] ?? 'Edit Post',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 135,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(
                        widget.postData['imageUrl'] ??
                            'https://cdn.sanity.io/images/5vm5yn1d/pro/e8901b37029ada974f945ce569a5643b511fb4a9-1499x1000.jpg?fm=webp&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField('Breed', breedController),
                _buildTextField('Color', colorController),
                _buildTextField('Location', locationController),
                _buildTextField('Time', timeController),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // เมื่อกดปุ่ม บันทึก จะเช็ค Validation ก่อน
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context, {
                        'breed': breedController.text,
                        'color': colorController.text,
                        'location': locationController.text,
                        'time': timeController.text,
                      });
                    } else {
                      // ⚡ ถ้า Validation ไม่ผ่าน แสดง SnackBar แจ้งเตือน
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ กรุณากรอกข้อมูลให้ครบทุกช่อง'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 17, 17, 17),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TextField พร้อม Validation
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '⚠️ กรุณากรอก $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
