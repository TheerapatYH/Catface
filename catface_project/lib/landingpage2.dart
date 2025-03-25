import 'package:flutter/material.dart';
import 'sign_up.dart';

class LandingPage2 extends StatelessWidget {
  const LandingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color.fromARGB(255, 17, 17, 17), // พื้นหลังสีดำ
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Center(
              child: Text(
                'Our Machine Learning can find your cat',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIndicator(0, 2), // จุดแรก
                const SizedBox(width: 10),
                _buildIndicator(1, 2), // จุดที่สอง
                const SizedBox(width: 10),
                _buildIndicator(2, 2), // จุดที่สาม
              ],
            ),
            const Spacer(), // เว้นระยะตรงกลาง
            Padding(
              padding: const EdgeInsets.only(
                bottom: 50,
                left: 16,
                right: 16,
              ), // เว้นระยะห่างจากขอบล่าง
              child: SizedBox(
                width: double.infinity, // ปรับปุ่มให้กว้างเต็มหน้าจอ
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ), // เพิ่มความสูงของปุ่ม
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ), // ขนาดตัวอักษร
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => SignUpPage()),
                    );
                  },
                  child: const Text('CONTINUE'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(int index, int currentIndex) {
    bool isActive = index == currentIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 20 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.grey,
        borderRadius: BorderRadius.circular(isActive ? 4 : 50),
      ),
    );
  }
}
