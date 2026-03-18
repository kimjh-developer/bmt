import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyPage extends StatefulWidget {
  const MyPage({Key? key}) : super(key: key);

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String _nickname = 'HikerUser';
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nickname = prefs.getString('nickname') ?? 'HikerUser';
    });
  }

  Future<void> _saveNickname(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', name);
    setState(() {
      _nickname = name;
    });
  }

  void _showEditNicknameDialog() {
    _nameController.text = _nickname;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('닉네임 변경'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: '새 닉네임 입력'),
            maxLength: 20,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveNickname(_nameController.text);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('마이페이지'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(height: 20),
            const Center(
              child: CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _nickname,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _showEditNicknameDialog,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('닉네임 변경'),
              ),
            ),
            const Divider(height: 40),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('제작자 정보'),
              subtitle: Text('등산 트래커 v1.0\n제작: 김주형'),
            ),
            const Divider(),
          ],
        ));
  }
}
