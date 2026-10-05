import 'package:flutter/material.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const CleanTrackApp());
}

class CleanTrackApp extends StatelessWidget {
  const CleanTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleanTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      initialRoute: '/register',
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
