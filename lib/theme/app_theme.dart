import 'package:flutter/material.dart';

// ─── iOS system colour palette ────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Accent colours (identical in light and dark) ──
  static const Color blue   = Color(0xFF007AFF);
  static const Color teal   = Color(0xFF30B0C7);
  static const Color green  = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color red    = Color(0xFFFF3B30);
  static const Color purple = Color(0xFFAF52DE);
  static const Color indigo = Color(0xFF5856D6);
  static const Color pink   = Color(0xFFFF2D55);

  // ── Player level colours (beginner → competitive) ──
  static const List<Color> levelColors = [
    blue,
    teal,
    green,
    orange,
    red,
  ];
}