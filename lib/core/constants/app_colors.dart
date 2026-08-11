import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette - 5 To Go Pop-Art
  static const Color brandGreen = Color(0xFF1F7A4D);
  static const Color brandRed = Color(0xFFE8402F);
  static const Color brandTurquoise = Color(0xFF2FB6C4);
  static const Color brandMustard = Color(0xFFF4B93C);
  static const Color brandPurple = Color(0xFF7A4FBF);

  // Backgrounds & Surfaces
  static const Color creamBackground = Color(0xFFFFFDF8);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFAFAFA);
  static const Color inputFill = Color(0xFFF5F5F7);
  
  // Text & UI elements
  static const Color textDark = Color(0xFF1A1A1A); // Almost black
  static const Color textLight = Color(0xFF757575);
  static const Color borderLight = Color(0xFFEEEEEE);
  static const Color shadowColor = Color(0x1A000000); // 10% black

  // Transparencies
  static const Color glassWhite = Color(0x40FFFFFF);
  static const Color glassWhiteStrong = Color(0x66FFFFFF);

  // Gradients - Updated to match new brand
  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF2FB6C4), Color(0xFF1F7A4D)], // Turquoise to Green
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFF4B93C), Color(0xFFE8402F)], // Mustard to Red
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF2FB6C4), Color(0xFF1F7A4D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Kept for backward compatibility while refactoring
  static const Color primaryPink = brandGreen;
  static const Color accentPink = brandGreen;
  static const Color softPink = Color(0xFFE0F5E9); // aliasing to a soft green
  static const Color offWhite = creamBackground;
  static const Color softYellow = brandMustard;
  static const Color softGreen = brandTurquoise;
  static const Color softPurple = brandPurple;
  static const Color softBlue = brandTurquoise;
  static const LinearGradient pinkGradient = greenGradient;
}
