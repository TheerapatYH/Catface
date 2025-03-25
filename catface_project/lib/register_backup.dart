// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_catface/widget/common_buttons.dart' show CommonButtons;
// import 'package:flutter_catface/widget/re_usable_select_photo_button.dart';
// import 'package:image_cropper/image_cropper.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'config.dart';
// import 'select_photo_options_screen.dart';
// import 'package:flutter/foundation.dart';
// import 'package:http_parser/http_parser.dart';

// class RegisterCatPage extends StatefulWidget {
//   final String userId;
//   const RegisterCatPage({Key? key, required this.userId}) : super(key: key);

//   @override
//   _RegisterCatPageState createState() => _RegisterCatPageState();
// }

// class _RegisterCatPageState extends State<RegisterCatPage> {
//   File? _image;
//   final _formKey = GlobalKey<FormState>();
//   final List<XFile> _imageFiles = [];
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _breedController = TextEditingController();
//   final TextEditingController _colorController = TextEditingController();
//   final TextEditingController _prominentPointController =
//       TextEditingController();

//   // Future<void> _pickImages() async {
//   //   final picker = ImagePicker();
//   //   final pickedFiles = await picker.pickMultiImage();
//   //   if (pickedFiles != null && pickedFiles.isNotEmpty) {
//   //     setState(() {
//   //       _imageFiles.addAll(pickedFiles);
//   //     });
//   //   }
//   // }

// //--------------------------------------------------------------------------------//

//   // Future _pickImage(ImageSource source) async {
//   //   try {
//   //     final image = await ImagePicker().pickImage(source: source);
//   //     if (image == null) return;
//   //     File? img = File(image.path);
//   //     img = await _cropImage(imageFile: img);
//   //     setState(() {
//   //       _image = img;
//   //       Navigator.of(context).pop();
//   //     });
//   //   } on PlatformException catch (e) {
//   //     print(e);
//   //     Navigator.of(context).pop();
//   //   }
//   // }
//   // Update the _pickImage function
// Future _pickImage(ImageSource source) async {
//   try {
//     final image = await ImagePicker().pickImage(source: source);
//     if (image == null) return;
//     File? img = File(image.path);
//     img = await _cropImage(imageFile: img);
//     if (img != null) {
//       setState(() {
//         _imageFiles.add(XFile(img!.path)); // Add cropped image to the list
//       });
//     }
//     Navigator.of(context).pop();
//   } on PlatformException catch (e) {
//     print(e);
//     Navigator.of(context).pop();
//   }
// }

// // Remove the conflicting onTap function (if present)
// // Ensure the _image variable is removed since it's no longer used

//   Future<File?> _cropImage({required File imageFile}) async {
//     CroppedFile? croppedImage =
//         await ImageCropper().cropImage(sourcePath: imageFile.path);
//     if (croppedImage == null) return null;
//     return File(croppedImage.path);
//   }

//     void _showSelectPhotoOptions(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(
//           top: Radius.circular(25.0),
//         ),
//       ),
//       builder: (context) => DraggableScrollableSheet(
//           initialChildSize: 0.28,
//           maxChildSize: 0.4,
//           minChildSize: 0.28,
//           expand: false,
//           builder: (context, scrollController) {
//             return SingleChildScrollView(
//               controller: scrollController,
//               child: SelectPhotoOptionsScreen(
//                 onTap: _pickImage,
//               ),
//             );
//           }),
//     );
//   }

// Future<List<http.MultipartFile>> prepareImageFiles(List<XFile> files) async {
//   return await Future.wait(files.map((xfile) async {
//     final bytes = await xfile.readAsBytes();
//     return http.MultipartFile.fromBytes(
//       'images', bytes,
//       filename: xfile.name,
//       contentType: MediaType.parse('image/jpeg'),
//     );
//   }));
// }

// // ----------------------------------------------------------------------------------- //

//   Future<void> _registerCat() async {
//     if (_formKey.currentState!.validate() && _imageFiles.length >= 5) {
//       final String catName = _nameController.text.trim();
//       final String catBreed = _breedController.text.trim();
//       final String catColor = _colorController.text.trim();
//       final String catProminentPoint = _prominentPointController.text.trim();

//       final uri = Uri.parse('${Config.baseUrl}/register-cat');
//       final request = http.MultipartRequest('POST', uri);

//       // เพิ่มข้อมูลฟอร์ม
//       request.fields['cat_name'] = catName;
//       request.fields['cat_breed'] = catBreed;
//       request.fields['cat_color'] = catColor;
//       request.fields['cat_prominent_point'] = catProminentPoint;
//       request.fields['user_id'] = widget.userId;

//       // เพิ่มไฟล์รูปภาพ (สำหรับ Flutter Web)
//       // for (var xfile in _imageFiles) {
//       //   final bytes = await xfile.readAsBytes();
//       //   request.files.add(
//       //     http.MultipartFile.fromBytes('images', bytes, filename: xfile.name),
//       //   );
//       // }
//       for (var xfile in _imageFiles) {
//         final bytes = await xfile.readAsBytes();
//         final mimeType = 'image/jpeg'; // Change this based on actual file type

//         request.files.add(
//           http.MultipartFile.fromBytes(
//             'images',
//             bytes,
//             filename: xfile.name,
//             contentType: MediaType.parse(mimeType),
//           ),
//         );
//       }

//       try {
//         final streamedResponse = await request.send();
//         final response = await http.Response.fromStream(streamedResponse);
//         if (response.statusCode == 201) {
//           final responseBody = jsonDecode(response.body);
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'Cat registered successfully! Cat ID: ${responseBody['cat_id']}',
//               ),
//             ),
//           );
//           Navigator.pop(context);
//         } else {
//           ScaffoldMessenger.of(
//             context,
//           ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
//         }
//       } catch (e) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error: $e')));
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please fill all fields and select at least 5 images.'),
//         ),
//       );
//     }
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required String placeholder,
//   }) {
//     return TextFormField(
//       controller: controller,
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Please enter $label';
//         }
//         return null;
//       },
//       style: const TextStyle(color: Colors.white),
//       decoration: InputDecoration(
//         labelText: label,
//         hintText: placeholder,
//         hintStyle: const TextStyle(color: Colors.grey),
//         labelStyle: const TextStyle(color: Colors.white),
//         filled: true,
//         fillColor: Colors.grey[800],
//         floatingLabelBehavior: FloatingLabelBehavior.always,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: BorderSide.none,
//         ),
//       ),
//     );
//   }

// //-------------------------------------------------------------------------------------//

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Register Your Cat'),
//         backgroundColor: const Color.fromARGB(255, 17, 17, 17),
//       ),
//       backgroundColor: const Color.fromARGB(255, 17, 17, 17),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Upload Images (at least 5)',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               // GestureDetector(
//               //   onTap: _pickImages,
//               //   child: Container(
//               //     width: double.infinity,
//               //     height: 200,
//               //     decoration: BoxDecoration(
//               //       color: Colors.grey[300],
//               //       borderRadius: BorderRadius.circular(10),
//               //     ),
//               //     child:
//               //         _imageFiles.isNotEmpty
//               //             ? ListView.builder(
//               //               scrollDirection: Axis.horizontal,
//               //               itemCount: _imageFiles.length,
//               //               itemBuilder: (context, index) {
//               //                 return FutureBuilder(
//               //                   future: _imageFiles[index].readAsBytes(),
//               //                   builder: (context, snapshot) {
//               //                     if (snapshot.connectionState ==
//               //                             ConnectionState.done &&
//               //                         snapshot.hasData) {
//               //                       return Padding(
//               //                         padding: const EdgeInsets.all(8.0),
//               //                         child: Image.memory(
//               //                           snapshot.data as Uint8List,
//               //                           fit: BoxFit.cover,
//               //                         ),
//               //                       );
//               //                     } else {
//               //                       return Container(
//               //                         width: 100,
//               //                         height: 100,
//               //                         child: const Center(
//               //                           child: CircularProgressIndicator(),
//               //                         ),
//               //                       );
//               //                     }
//               //                   },
//               //                 );
//               //               },
//               //             )
//               //             : const Center(
//               //               child: Icon(Icons.add_photo_alternate, size: 50),
//               //             ),
//               //   ),
//               // ),
//               //========================================== test
//             Container(
//                 width: double.infinity,
//                 height: 100,
//                 decoration: BoxDecoration(
//                   color: Colors.grey[300],
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: _imageFiles.isNotEmpty
//                     ? ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         itemCount: _imageFiles.length,
//                         itemBuilder: (context, index) {
//                           return FutureBuilder(
//                             future: _imageFiles[index].readAsBytes(),
//                             builder: (context, snapshot) {
//                               if (snapshot.connectionState == ConnectionState.done &&
//                                   snapshot.hasData) {
//                                 return Padding(
//                                   padding: const EdgeInsets.all(8.0),
//                                   child: Image.memory(
//                                     snapshot.data as Uint8List,
//                                     fit: BoxFit.cover,
//                                   ),
//                                 );
//                               } else {
//                                 return Container(
//                                   width: 100,
//                                   height: 100,
//                                   child: const Center(
//                                     child: CircularProgressIndicator(),
//                                   ),
//                                 );
//                               }
//                             },
//                           );
//                         },
//                       )
//                     : const Center(
//                         child: Text(
//                           'No images uploaded',
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.grey,
//                           ),
//                         ),
//                       ),
//               ),
// -------------------------------------------------------------------------------------------------- //

//               // Padding(
//               //   padding: const EdgeInsets.all(28.0),
//               //   child: Center(
//               //     child: Container(
//               //       height: 200.0,
//               //       width: double.infinity,
//               //       decoration: BoxDecoration(
//               //         borderRadius: BorderRadius.circular(10),
//               //         color: Colors.grey.shade200,
//               //       ),
//               //       child: _imageFiles.isEmpty
//               //           ? const Center(
//               //               child: Text(
//               //                 'No images selected',
//               //                 style: TextStyle(fontSize: 20),
//               //               ),
//               //             )
//               //           : GridView.builder(
//               //               shrinkWrap: true,
//               //               physics: const NeverScrollableScrollPhysics(),
//               //               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               //                 crossAxisCount: 3, // Adjust as needed
//               //                 crossAxisSpacing: 8,
//               //                 mainAxisSpacing: 8,
//               //               ),
//               //               itemCount: _imageFiles.length,
//               //               itemBuilder: (context, index) {
//               //                 return Stack(
//               //                   children: [
//               //                     ClipRRect(
//               //                       borderRadius: BorderRadius.circular(10),
//               //                       child: FutureBuilder(
//               //                         future: _imageFiles[index].readAsBytes(),
//               //                         builder: (context, snapshot) {
//               //                           if (snapshot.connectionState == ConnectionState.done &&
//               //                               snapshot.hasData) {
//               //                             return Image.memory(
//               //                               snapshot.data as Uint8List,
//               //                               fit: BoxFit.cover,
//               //                               width: double.infinity,
//               //                               height: double.infinity,
//               //                             );
//               //                           } else {
//               //                             return const Center(
//               //                               child: CircularProgressIndicator(),
//               //                             );
//               //                           }
//               //                         },
//               //                       ),
//               //                     ),
//               //                     Positioned(
//               //                       top: 5,
//               //                       right: 5,
//               //                       child: GestureDetector(
//               //                         onTap: () {
//               //                           setState(() {
//               //                             _imageFiles.removeAt(index); // Remove image from list
//               //                           });
//               //                         },
//               //                         child: Container(
//               //                           decoration: BoxDecoration(
//               //                             color: Colors.black54,
//               //                             shape: BoxShape.circle,
//               //                           ),
//               //                           padding: const EdgeInsets.all(4),
//               //                           child: const Icon(
//               //                             Icons.close,
//               //                             color: Colors.white,
//               //                             size: 18,
//               //                           ),
//               //                         ),
//               //                       ),
//               //                     ),
//               //                   ],
//               //                 );
//               //               },
//               //             ),
//               //     ),
//               //   ),
//               // ),
// // ----------------------------------------------------------------------- //
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   CommonButtons(
//                     onTap: () => _showSelectPhotoOptions(context),
//                     backgroundColor: Colors.black,
//                     textColor: Colors.white,
//                     textLabel: 'Add a Photo',
//                   ),
//                 ],
//               ),
// // --------------------------------------------------------------------------------- //
//               const SizedBox(height: 20),
//               _buildTextField(
//                 controller: _nameController,
//                 label: 'Name',
//                 placeholder: 'What is the cat\'s name?',
//               ),
//               const SizedBox(height: 10),
//               _buildTextField(
//                 controller: _breedController,
//                 label: 'Breed',
//                 placeholder: 'What breed is it?',
//               ),
//               const SizedBox(height: 10),
//               _buildTextField(
//                 controller: _colorController,
//                 label: 'Color',
//                 placeholder: 'What color is it?',
//               ),
//               const SizedBox(height: 10),
//               _buildTextField(
//                 controller: _prominentPointController,
//                 label: 'Prominent Point',
//                 placeholder: 'What is the cat\'s prominent feature?',
//               ),
//               const SizedBox(height: 20),
//               Center(
//                 child: ElevatedButton(
//                   onPressed: _registerCat,
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 12,
//                       horizontal: 24,
//                     ),
//                   ),
//                   child: const Text('Register', style: TextStyle(fontSize: 16)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
