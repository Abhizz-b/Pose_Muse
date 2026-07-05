import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'screens/settings_screen.dart'; // themeNotifier yahan se aata hai
import 'services/notification_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PoseMuseApp());
}

class PoseMuseApp extends StatelessWidget {
  const PoseMuseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'PoseMuse',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,

          // ── Dark Theme ──
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9C6FFF),
              surface: Color(0xFF1A1A1A),
              onSurface: Color(0xFFF3F3F3),
            ),
            scaffoldBackgroundColor: const Color(0xFF0D0D0D),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1C1C1C),
            ),
            dividerColor: const Color(0xFF2A2A2A),
          ),

          // ── Light Theme ──
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9C6FFF),
              surface: Color(0xFFFFFFFF),
              onSurface: Color(0xFF111111),
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            dialogBackgroundColor: const Color(0xFFFFFFFF),
            dividerColor: const Color(0xFFE0E0E0),
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}
