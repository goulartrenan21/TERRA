import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const coral  = Color(0xFFFF4A2E);
  static const amber  = Color(0xFFFF7B14);
  static const sage   = Color(0xFF7A9E82);
  static const tinta  = Color(0xFF16161A);
  static const papel  = Color(0xFFECE4DC);

  // Backgrounds
  static const bgLight = Color(0xFFF4F1EC);
  static const bgDark  = Color(0xFF16161A);

  // Surface variants
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark  = Color(0xFF1E1E24);
  static const cardDark     = Color(0xFF242429);

  // Text
  static const textPrimary   = tinta;
  static const textSecondary = Color(0xFF6B6B72);
  static const textOnDark    = Color(0xFFF4F1EC);
  static const textOnCoral   = Color(0xFFFFFFFF);

  // Status
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error   = Color(0xFFE53935);

  // Territory colors (for other users — derived from hash of user id)
  static const List<Color> territoryPalette = [
    Color(0xFF5B8DD9),
    Color(0xFF9C5BDB),
    Color(0xFF5BBD7E),
    Color(0xFFD9A45B),
    Color(0xFF5BC8D9),
    Color(0xFFDB5B9C),
  ];

  static Color territoryColorForUser(String userId) {
    final hash = userId.codeUnits.fold(0, (a, b) => a + b);
    return territoryPalette[hash % territoryPalette.length];
  }
}
