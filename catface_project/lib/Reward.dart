import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'confirm_reward.dart';

class RewardPage extends StatefulWidget {
  final String userId;

  const RewardPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  bool _isLoading = false;
  Map<String, dynamic>?
  _userData; // { user_id, username, profile_image_path, point }

  // FIXED REWARDS (ไม่เปลี่ยนแปลง)
  final List<Map<String, dynamic>> _rewards = [
    {
      'reward_id': 'R001',
      'title': 'ส่วนลด Major Cineplex 50%',
      'description': 'รับส่วนลดตั๋วหนัง 50% ทุกสาขา',
      'required_points': 15,
      'detail_terms': '''
1) ใช้ได้ 1 ครั้งต่อบัญชี และต้องใช้ภายในระยะเวลาที่กำหนด
2) ใช้ผ่านแอปหรือหน้าเว็บ Major เท่านั้น
3) ไม่สามารถใช้ร่วมกับกิจกรรมพิเศษบางรายการหรือโปรโมชันอื่นๆ
4) ต้องใช้ก่อนวันหมดอายุ มิฉะนั้นส่วนลดจะหมดอายุโดยอัตโนมัติ
5) ส่วนลดนี้ไม่สามารถใช้ร่วมกับบัตรส่วนลดหรือโปรโมชันอื่นๆ ได้
6) ต้องแสดงบัตรประชาชนหรือข้อมูลส่วนตัวตามที่กำหนดเมื่อขอรับสิทธิ์
7) ใช้ได้เฉพาะในกรณีที่ซื้อตั๋วสำหรับภาพยนตร์ที่เข้าฉายในปัจจุบัน
8) หากมีการยกเลิกการจองหรือการรับสิทธิ์ส่วนลดจะไม่สามารถคืนหรือขยายเวลาหลังจากการใช้งาน
9) จำกัดจำนวนที่สามารถใช้ได้ในแต่ละสาขาต่อวัน
10) ต้องตรวจสอบเงื่อนไขการใช้งานเพิ่มเติมจากการประกาศของ Major Cineplex ทุกครั้ง
11) หากพบว่ามีการละเมิดเงื่อนไขการใช้โปรโมชันอาจจะถูกตัดสิทธิ์การใช้ในอนาคต
''',
    },
    {
      'reward_id': 'R002',
      'title': '100 Bath Gift Voucher',
      'description': 'บัตรกำนัลเงินสด 100 บาท สำหรับร้านอาหารร่วมรายการ',
      'required_points': 15,
      'detail_terms': '''
1) ใช้ได้ 1 ครั้งต่อใบเสร็จ
2) ไม่สามารถแลกเป็นเงินสดได้
3) ต้องใช้ภายในเวลาที่กำหนดเท่านั้น
4) ใช้ได้เฉพาะร้านอาหารที่ร่วมรายการและในสาขาที่กำหนด
5) ต้องแสดงบัตรกำนัลก่อนการสั่งอาหาร
6) หากมียอดซื้อไม่ถึงจำนวนที่กำหนด ผู้ใช้ต้องชำระเงินส่วนต่าง
7) ไม่สามารถใช้ในวันหยุดหรือวันพิเศษบางวันที่มีข้อกำหนดเฉพาะ
8) สามารถใช้ได้เพียงแค่หนึ่งบัตรต่อการใช้บริการหนึ่งครั้ง
9) กรณีบัตรหายหรือถูกขโมยไม่สามารถขอทดแทนหรือคืนได้
10) บัตรกำนัลนี้ไม่สามารถโอนสิทธิ์ให้ผู้อื่นได้
11) ในกรณีที่มีข้อสงสัยเกี่ยวกับการใช้บัตรกำนัล โปรดติดต่อฝ่ายบริการลูกค้าของร้านที่ร่วมรายการ
12) บัตรกำนัลนี้อาจไม่สามารถใช้ได้ในบางสาขาหรือร้านค้า
''',
    },
    {
      'reward_id': 'R003',
      'title': 'ส่วนลด 50 บาทใน 7-Eleven',
      'description': 'คูปองส่วนลด 50 บาท สำหรับซื้อสินค้าที่ 7-Eleven',
      'required_points': 10,
      'detail_terms': '''
1) ใช้ได้ครั้งเดียวต่อคูปอง
2) สินค้าบางรายการอาจไม่ร่วมโปรโมชั่น
3) หมดอายุภายใน 30 วันจากวันที่ได้รับ
4) ใช้ได้เฉพาะที่ร้าน 7-Eleven สาขาที่ร่วมรายการ
5) คูปองนี้ไม่สามารถใช้ร่วมกับโปรโมชันอื่นได้
6) คูปองนี้ไม่สามารถทอนเป็นเงินสดหรือแลกคืนได้
7) หากทำการซื้อสินค้าราคาต่ำกว่ามูลค่าคูปอง ผู้ใช้จะไม่ได้รับเงินทอน
8) ต้องแสดงคูปองและบัตรประชาชนในกรณีที่มีการตรวจสอบสิทธิ์
9) บริษัทขอสงวนสิทธิ์ในการยกเลิกหรือเปลี่ยนแปลงเงื่อนไขของคูปองนี้โดยไม่ต้องแจ้งล่วงหน้า
10) คูปองนี้สามารถใช้ได้ในบางช่วงเวลาเท่านั้น
11) กรณีการใช้คูปองผิดเงื่อนไข บริษัทขอสงวนสิทธิ์ในการยกเลิกการใช้คูปอง
''',
    },
    {
      'reward_id': 'R004',
      'title': 'Starbucks e-Coupon 100 บาท',
      'description': 'โค้ดใช้แทนเงินสดที่ Starbucks มูลค่า 100 บาท',
      'required_points': 20,
      'detail_terms': '''
1) ไม่สามารถแลกเป็นเงินสดได้
2) ใช้ได้เฉพาะสาขาที่ร่วมรายการ
3) ไม่สามารถทอนเป็นเงินสดได้
4) ใช้ได้เฉพาะการซื้อสินค้าทั่วไป ไม่รวมสินค้าราคาพิเศษหรือสินค้าภายในโปรโมชัน
5) สามารถใช้ได้เฉพาะในประเทศที่มีสาขาของ Starbucks
6) ต้องกรอกโค้ดที่หน้าชำระเงินผ่านแอปหรือเว็บไซต์เท่านั้น
7) ใช้ได้ตามวันและเวลาที่กำหนดโดย Starbucks เท่านั้น
8) หากไม่ได้ใช้โค้ดภายในระยะเวลาที่กำหนดจะถือว่าโค้ดหมดอายุโดยอัตโนมัติ
9) โค้ดนี้ไม่สามารถโอนสิทธิ์ให้กับผู้อื่นหรือขายต่อได้
10) ต้องใช้โค้ดนี้ในบิลที่มีจำนวนเงินที่สูงกว่ามูลค่าของโค้ด
11) หากมีการขอคืนเงินหลังจากการใช้โค้ด สิทธิ์การใช้โค้ดจะถูกยกเลิก
12) กรณีโค้ดหมดอายุหรือไม่สามารถใช้ได้ บริษัทขอสงวนสิทธิ์ในการไม่ออกโค้ดใหม่
''',
    },
    {
      'reward_id': 'R005',
      'title': 'Central Gift Card 200 บาท',
      'description': 'บัตรของขวัญสำหรับ Central มูลค่า 200 บาท',
      'required_points': 25,
      'detail_terms': '''
1) ใช้ได้เฉพาะสินค้าที่ร่วมรายการ
2) ไม่สามารถใช้ร่วมกับโปรโมชันอื่น
3) ใช้ภายใน 90 วันหลังจากได้รับบัตร
4) บัตรนี้ไม่สามารถแลกเปลี่ยนเป็นเงินสดหรือโอนให้ผู้อื่นได้
5) หากมียอดซื้อไม่ถึงมูลค่าของบัตร ผู้ใช้ต้องชำระเงินส่วนต่าง
6) บัตรนี้ใช้ได้เฉพาะในสาขาที่ร่วมรายการเท่านั้น
7) ใช้บัตรนี้ไม่สามารถทอนเป็นเงินสดหรือแปลงเป็นบัตรกำนัลอื่น
8) หากบัตรหายหรือเสียหายไม่สามารถออกบัตรทดแทนได้
9) ในกรณีที่ผู้ใช้ต้องการคืนสินค้าหลังจากการใช้บัตรกำนัล บริษัทจะไม่คืนเงินที่ใช้จากบัตร
10) คำขอเกี่ยวกับบัตรจะได้รับการพิจารณาตามนโยบายของร้านค้าหรือศูนย์การค้า
11) บัตรนี้ไม่สามารถใช้ในการซื้อสินค้าหรือบริการที่ไม่เกี่ยวข้องกับศูนย์การค้า
12) หากพบว่ามีการละเมิดเงื่อนไขการใช้บัตร บริษัทขอสงวนสิทธิ์ในการยกเลิกหรือระงับการใช้บัตรทันที
''',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  /// ดึงข้อมูลผู้ใช้จาก Endpoint: GET /user-profile/:user_id
  Future<void> _fetchUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final url = '${Config.baseUrl}/user-profile/${widget.userId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userData =
              data; // ควรมี key: user_id, username, profile_image_path, point
        });
      } else {
        debugPrint('Error fetching user profile: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _userData?['username'] ?? 'Unknown';
    final profilePath = _userData?['profile_image_path'] ?? '';
    // ใช้ key "point" ตามที่แก้ไขใน Backend
    final userPoint = _userData?['point'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800], // AppBar color set to black
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Back arrow color white
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildUserInfoSection(userName, profilePath, userPoint),
                  Expanded(
                    child: Container(
                      color:
                          Colors
                              .grey[200], // Set background color of ListView to gray
                      child: ListView.builder(
                        itemCount: _rewards.length,
                        itemBuilder: (context, index) {
                          final reward = _rewards[index];
                          return _buildRewardCard(reward, userPoint);
                        },
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildUserInfoSection(String userName, String profilePath, int point) {
    return Container(
      color: Colors.white, // User info section background color set to white
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // รูปโปรไฟล์
          CircleAvatar(
            radius: 40,
            backgroundImage:
                (profilePath.isNotEmpty)
                    ? NetworkImage('${Config.baseUrl}/$profilePath')
                    : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
          ),
          const SizedBox(width: 16),
          // ชื่อและคะแนน
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Bold black text
                ),
              ),
              Text(
                '$point point',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black, // Black text
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward, int userPoint) {
    final rewardId = reward['reward_id'] ?? '';
    final title = reward['title'] ?? '';
    final description = reward['description'] ?? '';
    final requiredPoints = reward['required_points'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.white, // Card background color set to white
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Black text for title
              ),
            ),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('แลกด้วย $requiredPoints point'),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, // Orange button
                  ),
                  onPressed: () {
                    if (userPoint < requiredPoints) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Point ของคุณไม่เพียงพอ')),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ConfirmRewardPage(
                                userId: _userData?['user_id'] ?? '',
                                userName: _userData?['username'] ?? '',
                                userPoint: userPoint,
                                rewardId: rewardId,
                                rewardTitle: title,
                                rewardPoints: requiredPoints,
                                rewardDetail: reward['detail_terms'] ?? '',
                              ),
                        ),
                      ).then((value) {
                        _fetchUserProfile();
                      });
                    }
                  },
                  child: const Text(
                    'Collect Reward',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color.fromARGB(255, 255, 255, 255), // Black text
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
