import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database/database_helper.dart';
import 'ui/splash_screen.dart';
import 'providers/tracker_provider.dart';import 'utils/file_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileUtils.init();
  await DatabaseHelper.instance.loadMountainsIfEmpty();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0E14),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6DDDFF),
        secondary: Color(0xFFD7E2FF),
        surface: Color(0xFF0A0E14),
      ),
      useMaterial3: true,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TrackerProvider()),
      ],
      child: MaterialApp(
        title: 'BMT',
        theme: base.copyWith(
          textTheme: GoogleFonts.notoSansKrTextTheme(base.textTheme).apply(
            bodyColor: const Color(0xFFF1F3FC),
            displayColor: const Color(0xFFF1F3FC),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
