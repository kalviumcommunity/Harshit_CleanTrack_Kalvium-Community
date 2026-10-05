import 'package:flutter/material.dart';
import 'package:cleantrack/screens/splash_screen.dart';

void main() {
  runApp(const CleanTrackApp());
}

class CleanTrackApp extends StatelessWidget {
  const CleanTrackApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
