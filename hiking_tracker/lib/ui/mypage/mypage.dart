import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String _nickname = '등산러';
  String? _profileImagePath;
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  static const String _keyNickname = 'nickname';
  static const String _keyProfileImage = 'profile_image_path';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nickname = prefs.getString(_keyNickname) ?? '등산러';
      _profileImagePath = prefs.getString(_keyProfileImage);
    });
  }

  Future<void> _saveNickname(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, name.trim());
    setState(() => _nickname = name.trim());
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProfileImage, file.path);
      setState(() => _profileImagePath = file.path);
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  void _showPhotoBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.green),
                ),
                title: Text('사진 촬영', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600)),
                subtitle: Text('카메라로 새 사진 찍기', style: GoogleFonts.notoSansKr(fontSize: 12, color: Colors.grey)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Colors.blueAccent),
                ),
                title: Text('앨범에서 선택', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600)),
                subtitle: Text('갤러리에서 사진 불러오기', style: GoogleFonts.notoSansKr(fontSize: 12, color: Colors.grey)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNicknameDialog() {
    _nameController.text = _nickname;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('닉네임 변경', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _nameController,
          style: GoogleFonts.notoSansKr(),
          decoration: InputDecoration(
            hintText: '새 닉네임 입력',
            hintStyle: GoogleFonts.notoSansKr(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: GoogleFonts.notoSansKr(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _saveNickname(_nameController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('저장', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('마이페이지', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // ─── Profile Header ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                // Avatar with camera overlay
                GestureDetector(
                  onTap: _showPhotoBottomSheet,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.green.shade100,
                        backgroundImage: (_profileImagePath != null && File(_profileImagePath!).existsSync())
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: (_profileImagePath == null || !File(_profileImagePath!).existsSync())
                            ? Icon(Icons.person, size: 60, color: Colors.green.shade400)
                            : null,
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Nickname
                Text(
                  _nickname,
                  style: GoogleFonts.notoSansKr(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _showEditNicknameDialog,
                  icon: const Icon(Icons.edit, size: 14),
                  label: Text('닉네임 변경', style: GoogleFonts.notoSansKr(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── App Info Card ───────────────────────────────────────────────
          _buildSectionCard(
            children: [
              _buildInfoRow(Icons.info_outline, '앱 버전', 'v1.0'),
              const Divider(height: 1),
              _buildInfoRow(Icons.person_outline, '제작자', '김주형'),
              const Divider(height: 1),
              _buildInfoRow(Icons.email_outlined, '이메일', 'fylfot@naver.com'),
            ],
          ),

          const SizedBox(height: 12),

          // ─── App Concept Card ────────────────────────────────────────────
          _buildSectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.landscape, color: Colors.green.shade600, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BMT', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Busan Mountain Tracking', style: GoogleFonts.notoSansKr(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            '대한민국 산봉우리 13,000+개 데이터를 기반으로\n산행 경로와 정상 정복을 기록하는 도우미 앱입니다.',
                            style: GoogleFonts.notoSansKr(fontSize: 12, color: Colors.grey.shade600, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}

