import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary:          AppColors.coral,
        secondary:        AppColors.amber,
        surface:          AppColors.bgLight,
        onPrimary:        Colors.white,
        onSecondary:      Colors.white,
        onSurface:        AppColors.tinta,
        error:            AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: GoogleFonts.archivoTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor:  AppColors.bgLight,
        foregroundColor:  AppColors.tinta,
        elevation:        0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.tinta,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  AppColors.coral,
          foregroundColor:  Colors.white,
          minimumSize:      const Size.fromHeight(52),
          shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:        GoogleFonts.archivo(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:  AppColors.tinta,
          side:             const BorderSide(color: AppColors.tinta, width: 1.5),
          minimumSize:      const Size.fromHeight(52),
          shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:        GoogleFonts.archivo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:           true,
        fillColor:        Colors.white,
        contentPadding:   const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Color(0xFFD0C8BF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Color(0xFFD0C8BF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.coral, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.archivo(color: const Color(0xFFAA9F96), fontSize: 15),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary:   AppColors.coral,
        secondary: AppColors.amber,
        surface:   AppColors.bgDark,
        onPrimary: Colors.white,
        onSurface: AppColors.textOnDark,
        error:     AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: GoogleFonts.archivoTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor:  AppColors.bgDark,
        foregroundColor:  AppColors.textOnDark,
        elevation:        0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: Colors.white,
          minimumSize:     const Size.fromHeight(52),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:       GoogleFonts.archivo(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
