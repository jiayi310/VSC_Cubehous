import 'package:flutter/material.dart';

class Mycolor {
  // ── Brand (do not change) ─────────────────────
  static const Color backEndWebsiteColor = Color(0xFF153D81);
  static const Color logoColor = Color(0xFFFF9700);

  // ── App Palette ───────────────────────────────
  // Primary: navy derived from backend website color
  static const Color primary = Color(0xFF153D81);
  // Secondary/accent: amber derived from logo color
  static const Color secondary = Color(0xFFFF9700);

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF4F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardSurface = Color(0xFFFFFFFF);

  // Dark theme surfaces — navy-tinted dark, not pure black
  static const Color darkPrimary = Color(0xFF5B8FD4);   // lightened navy, readable on dark
  static const Color darkTabLabel = Color(0xFF90CAF9);  // bright blue for tab text on dark
  static const Color darkBackground = Color(0xFF0F1923);
  static const Color darkSurface = Color(0xFF1A2740);
  static const Color darkCardSurface = Color(0xFF1E2F4A);

  static const Color discountTextColor = Color.fromARGB(255, 255, 25, 0);
  static const Color taxTextColor = Color.fromARGB(255, 2, 125, 0);
}