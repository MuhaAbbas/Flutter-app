import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_service.dart';

class AppTheme {
  // Adaptive colors — change based on dark/light mode
  static Color get background      => ThemeService.isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9);
  static Color get surface         => ThemeService.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated => ThemeService.isDark ? const Color(0xFF252525) : const Color(0xFFF0F4F8);
  static Color get textPrimary     => ThemeService.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  static Color get textSecondary   => ThemeService.isDark ? const Color(0xFFB0B0B0) : const Color(0xFF64748B);
  static Color get divider         => ThemeService.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0);

  // Brand colors — same in both modes
  static const primary   = Color(0xFF4F8EF7);
  static const secondary = Color(0xFF00C896);
  static const error     = Color(0xFFF87171);
  static const warning   = Color(0xFFFBBF24);

  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      error: error,
      surface: surface,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondary,
      indicatorColor: primary,
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
    ),
    dividerTheme: DividerThemeData(color: divider, thickness: 1),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      error: error,
      surface: surface,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondary,
      indicatorColor: primary,
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
    ),
    dividerTheme: DividerThemeData(color: divider, thickness: 1),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static TextStyle heading(double size) => GoogleFonts.poppins(
    color: textPrimary, fontSize: size, fontWeight: FontWeight.w600);

  static TextStyle body(double size, {Color? color}) => GoogleFonts.inter(
    color: color ?? textPrimary, fontSize: size, fontWeight: FontWeight.w400);

  static TextStyle label(double size, {Color? color, FontWeight? weight}) => GoogleFonts.inter(
    color: color ?? textSecondary, fontSize: size, fontWeight: weight ?? FontWeight.w500);
}
