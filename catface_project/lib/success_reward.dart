import 'package:flutter/material.dart';

import 'config.dart';

class SuccessRewardPage extends StatelessWidget {
  final String userId;

  const SuccessRewardPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Yours Reward',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'ขอขอบคุณที่มีส่วนร่วมในการช่วยตามหาแมว\n ขอให้สนุกกับรางวัลของคุณ!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Image.network(
              '${Config.baseUrl}/uploads/QRCODE.png',
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                // Optional: You can add any further actions here
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text(
                'Go Back',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
