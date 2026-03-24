import 'package:flutter/material.dart';
import '../ui/tracker/tracker_page.dart';
import '../ui/records/records_page.dart';
import '../ui/mypage/mypage.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const TrackerPage(),
    const RecordsPage(),
    const MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: const Color(0xFF44484F).withOpacity(0.3))),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0A0E14),
          selectedItemColor: const Color(0xFF6DDDFF),
          unselectedItemColor: const Color(0xFF72757D),
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_walk_rounded),
              label: '운동 시작',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: '운동 기록',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: '마이페이지',
            ),
          ],
        ),
      ),
    );
  }
}
