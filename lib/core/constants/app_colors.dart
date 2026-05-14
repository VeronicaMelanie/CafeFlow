import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color primaryPink = Color(0xFFFF6B9B);
  static const Color accentPink = Color(0xFFF791A9);
  static const Color softPink = Color(0xFFFFF0F5);
  static const Color offWhite = Color(0xFFFDFBF7);
  static const Color pureWhite = Color(0xFFFFFFFF);
  
  // Secondary / Stat Colors
  static const Color softYellow = Color(0xFFFFE5B4);
  static const Color softGreen = Color(0xFFE0F5E9);
  static const Color softPurple = Color(0xFFE6E6FA);
  static const Color softBlue = Color(0xFFE0F2F4);
  
  // Text & UI
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textLight = Color(0xFF8E8E93);
  static const Color borderLight = Color(0xFFF2F2F7);
  static const Color shadowColor = Color(0x1A000000); // 10% black
  
  // Gradients
  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFFF6B9B), Color(0xFFF791A9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
