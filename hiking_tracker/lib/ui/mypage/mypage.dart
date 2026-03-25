import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../database/database_helper.dart';
import '../../utils/file_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  int _thisMonthDistanceMeters = 0;
  double _thisMonthAltitudeMeters = 0;
  String _appVersion = '로딩중...';

  static const String _keyNickname = 'nickname';
  static const String _keyProfileImage = 'profile_image_path';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final workouts = await DatabaseHelper.instance.getAllWorkouts();
    
    final now = DateTime.now();
    int monthDist = 0;
    double monthAlt = 0.0;

    for (var w in workouts) {
      try {
        final wDate = DateTime.parse(w.startTime);
        if (wDate.year == now.year && wDate.month == now.month) {
          monthDist += w.totalDistanceMeters.toInt();
          monthAlt += w.maxAltitudeMeters;
        }
      } catch (_) {}
    }

    setState(() {
      _nickname = prefs.getString(_keyNickname) ?? '등산러';
      _profileImagePath = prefs.getString(_keyProfileImage);
      _thisMonthDistanceMeters = monthDist;
      _thisMonthAltitudeMeters = monthAlt;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = '버전 정보 없음';
        });
      }
    }
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
      final savedFileName = await FileUtils.saveImageToDocuments(file.path);
      await prefs.setString(_keyProfileImage, savedFileName);
      setState(() => _profileImagePath = savedFileName);
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  void _showPhotoBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1B2028),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 24, top: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF44484F),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF6DDDFF).withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6DDDFF)),
                  ),
                  title: Text('사진 촬영', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
                  subtitle: Text('카메라로 새 사진 찍기', style: GoogleFonts.notoSansKr(fontSize: 13, color: const Color(0xFFA8ABB3))),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF00C3EB).withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF00C3EB)),
                  ),
                  title: Text('앨범에서 선택', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
                  subtitle: Text('갤러리에서 사진 불러오기', style: GoogleFonts.notoSansKr(fontSize: 13, color: const Color(0xFFA8ABB3))),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                ),
                const SizedBox(height: 16),
              ],
            ),
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
        backgroundColor: const Color(0xFF1B2028),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('닉네임 변경', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
        content: TextField(
          controller: _nameController,
          style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC)),
          decoration: InputDecoration(
            hintText: '새 닉네임 입력',
            hintStyle: GoogleFonts.notoSansKr(color: const Color(0xFF72757D)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF44484F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6DDDFF), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3))),
          ),
          ElevatedButton(
            onPressed: () {
              _saveNickname(_nameController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6DDDFF),
              foregroundColor: const Color(0xFF002C37),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
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
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        title: Text('마이페이지', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0E14),
        foregroundColor: const Color(0xFFF1F3FC),
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // ─── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 16, bottom: 8),
            child: Text('BMT', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
          ),
          
          // ─── Profile Section ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showPhotoBottomSheet,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF6DDDFF).withOpacity(0.3), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF1B2028),
                          backgroundImage: (_profileImagePath != null && File(FileUtils.getFullImagePath(_profileImagePath!)).existsSync())
                              ? FileImage(File(FileUtils.getFullImagePath(_profileImagePath!)))
                              : null,
                          child: (_profileImagePath == null || !File(FileUtils.getFullImagePath(_profileImagePath!)).existsSync())
                              ? const Icon(Icons.person_rounded, size: 50, color: Color(0xFF44484F))
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6DDDFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0A0E14), width: 3),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0A0E14), size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nickname, style: GoogleFonts.notoSansKr(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
                      const SizedBox(height: 4),
                      Text('BMT 탐험가', style: GoogleFonts.notoSansKr(fontSize: 14, color: const Color(0xFF6DDDFF))),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _showEditNicknameDialog,
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: Text('프로필 수정', style: GoogleFonts.notoSansKr(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF1F3FC),
                          side: BorderSide(color: const Color(0xFF44484F).withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Monthly Stats ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2028),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이번 달 기록', style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF6DDDFF))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('이번 달 누적 거리', style: GoogleFonts.notoSansKr(fontSize: 12, color: const Color(0xFFA8ABB3))),
                          const SizedBox(height: 8),
                          Text(
                            '${(_thisMonthDistanceMeters / 1000).toStringAsFixed(2)} km',
                            style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('이번 달 누적 고도', style: GoogleFonts.notoSansKr(fontSize: 12, color: const Color(0xFFA8ABB3))),
                          const SizedBox(height: 8),
                          Text(
                            '${_thisMonthAltitudeMeters.toStringAsFixed(0)} m',
                            style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Service Intro ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2028),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF6DDDFF), size: 18),
                    const SizedBox(width: 8),
                    Text('BMT 서비스 소개', style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF6DDDFF))),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'BMT(Best Mountain Tracker)는 등산객과 트레일 러너를 위한 정밀 경로 추적 및 고도 분석 플랫폼입니다. 사용자의 실시간 위치를 기반으로 최적의 경로를 제안하며, 등반 데이터를 시각화하여 더 안전하고 스마트한 아웃도어 경험을 제공합니다. Feat. whiteTiger!',
                  style: GoogleFonts.notoSansKr(fontSize: 14, color: const Color(0xFFA8ABB3), height: 1.6),
                ),
              ],
            ),
          ),

          // ─── Dev Info ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2028),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildInfoRow('개발자', 'barco_the_Walrus'),
                _buildInfoRow('문의 이메일', 'fylfot@naver.com'),
                _buildInfoRow('앱 버전', _appVersion),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.notoSansKr(fontSize: 14, color: const Color(0xFFA8ABB3))),
          Text(value, style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
        ],
      ),
    );
  }
}
