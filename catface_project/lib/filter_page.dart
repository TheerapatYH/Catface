import 'package:flutter/material.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  // ตัวแปรสำหรับเก็บสถานะของ Checkbox
  bool _isLostPost = false;
  bool _isFoundPost = false;
  bool _age1to5 = false;
  bool _age6to10 = false;
  bool _age11to15 = false;
  bool _ageAbove15 = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ตัวเลือก Lost/Found
            const Text(
              'Post Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: const Text('Lost Post'),
              value: _isLostPost,
              onChanged: (value) {
                setState(() {
                  _isLostPost = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Found Post'),
              value: _isFoundPost,
              onChanged: (value) {
                setState(() {
                  _isFoundPost = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            // ตัวเลือกช่วงอายุ
            const Text(
              'Age Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: const Text('1-5'),
              value: _age1to5,
              onChanged: (value) {
                setState(() {
                  _age1to5 = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('6-10'),
              value: _age6to10,
              onChanged: (value) {
                setState(() {
                  _age6to10 = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('11-15'),
              value: _age11to15,
              onChanged: (value) {
                setState(() {
                  _age11to15 = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Above 15'),
              value: _ageAbove15,
              onChanged: (value) {
                setState(() {
                  _ageAbove15 = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            // ปุ่ม Apply และ Cancel
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, null); // ปิด Popup โดยไม่ส่งข้อมูล
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // ส่งค่าตัวเลือกกลับไป
                    Navigator.pop(context, {
                      'isLostPost': _isLostPost,
                      'isFoundPost': _isFoundPost,
                      'ageRanges': {
                        '1-5': _age1to5,
                        '6-10': _age6to10,
                        '11-15': _age11to15,
                        'Above 15': _ageAbove15,
                      },
                    });
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
