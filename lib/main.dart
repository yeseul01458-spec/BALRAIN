import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

void main() {
  runApp(const BalrainApp());
}

class BalrainApp extends StatelessWidget {
  const BalrainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BALRAIN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
