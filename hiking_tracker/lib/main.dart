import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/database_helper.dart';
import 'database/database_helper.dart';
import 'ui/main_page.dart';
import 'providers/tracker_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.loadMountainsIfEmpty();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TrackerProvider()),
      ],
      child: MaterialApp(
        title: '등산 트래커',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        ),
        home: MainPage(),
      ),
    );
  }
}
