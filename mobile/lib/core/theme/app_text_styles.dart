import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// Archivo → UI, body, titles
// Oswald  → ALL numbers and metrics (condensed, bold)

class AppTextStyles {
  AppTextStyles._();

  // ── Metrics (Oswald) ────────────────────────────────────────────────────────
  static TextStyle metric({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.oswald(fontSize: size, fontWeight: weight, color: color);

  static TextStyle metricLarge({Color color = AppColors.coral}) =>
      metric(size: 48, color: color);

  static TextStyle metricMedium({Color color = AppColors.textPrimary}) =>
      metric(size: 32, color: color);

  static TextStyle metricSmall({Color color = AppColors.textSecondary}) =>
      metric(size: 16, weight: FontWeight.w400, color: color);

  // ── UI / Body (Archivo) ──────────────────────────────────────────────────────
  static TextStyle display({Color color = AppColors.textPrimary}) =>
      GoogleFonts.archivo(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: color,
      );

  static TextStyle title({
    double size = 20,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.archivo(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle subtitle({Color color = AppColors.textSecondary}) =>
      GoogleFonts.archivo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle body({
    double size = 16,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
  }) =>
      GoogleFonts.archivo(fontSize: size, fontWeight: weight, color: color);

  static TextStyle label({Color color = AppColors.textSecondary}) =>
      GoogleFonts.archivo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle button({Color color = AppColors.textOnCoral}) =>
      GoogleFonts.archivo(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      );
}
