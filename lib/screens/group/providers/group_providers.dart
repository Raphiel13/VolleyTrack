import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

// ─── Pomocnicze ───────────────────────────────────────────────────────────────

/// Paleta kolorów awatarów — deterministyczna na podstawie hasha uid użytkownika
const kGroupAvatarColors = <Color>[
  AppColors.blue,
  AppColors.teal,
  AppColors.green,
  AppColors.orange,
  AppColors.purple,
  Color(0xFF5856D6), // indygo
  Color(0xFFFF2D55), // różowy
];

/// Kolor awatara wyznaczony deterministycznie na podstawie uid — ten sam uid
/// zawsze daje ten sam kolor, co ułatwia rozpoznawanie uczestników
Color groupAvatarColor(String uid) =>
    kGroupAvatarColors[uid.hashCode.abs() % kGroupAvatarColors.length];
