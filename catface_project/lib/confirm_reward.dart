import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'success_reward.dart'; // Adjust the import if the file is located elsewhere
import 'config.dart';

class ConfirmRewardPage extends StatefulWidget {
  final String userId;
  final String userName;
  final int userPoint;
  final String rewardId;
  final String rewardTitle;
  final int rewardPoints;
  final String rewardDetail;

  const ConfirmRewardPage({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userPoint,
    required this.rewardId,
    required this.rewardTitle,
    required this.rewardPoints,
    required this.rewardDetail,
  }) : super(key: key);

  @override
  State<ConfirmRewardPage> createState() => _ConfirmRewardPageState();
}

class _ConfirmRewardPageState extends State<ConfirmRewardPage> {
  bool _isLoading = false;

  Future<void> _confirmRedeem() async {
    // Double-check: ถ้า userPoint ที่ส่งมาจากหน้า RewardPage ไม่เพียงพอ ให้แจ้งเตือน
    if (widget.userPoint < widget.rewardPoints) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Point ของคุณไม่เพียงพอ')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final url = '${Config.baseUrl}/redeem-reward';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'reward_id': widget.rewardId,
        }),
      );
      if (response.statusCode == 200) {
        // Redeemed successfully, navigate to the SuccessRewardPage
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Redeemed successfully!')));

        // Navigate to the SuccessRewardPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessRewardPage(userId: widget.userId),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${errorData['error']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = widget.userPoint;
    final needPoint = widget.rewardPoints;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Confirm Your Reward',
          style: const TextStyle(color: Colors.white),
        ),

        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // AppBar color set to black
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                color:
                    Colors.white, // Set background color of the body to white
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        widget.rewardTitle.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Container for "Point ของคุณ" with a top border
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left-aligned text: "Point ของคุณ"
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                'Point ของคุณ:',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Right-aligned value
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                '$userPoint',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Container for "Point ที่ต้องใช้" with a bottom border
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left-aligned text: "Point ที่ต้องใช้"
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                'Point ที่ต้องใช้:',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Right-aligned value
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                '$needPoint',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Center the "เงื่อนไขการใช้งาน" text
                      Center(
                        child: Text(
                          'เงื่อนไขการใช้งาน:',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Align widget.rewardDetail text to the left
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.rewardDetail,
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _confirmRedeem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
