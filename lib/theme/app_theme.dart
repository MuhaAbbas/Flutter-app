import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceElevated = Color(0xFF252525);
  static const primary = Color(0xFF4F8EF7);
  static const secondary = Color(0xFF00C896);
  static const error = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B0);
  static const divider = Color(0xFF2C2C2C);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      background: background,
      surface: surface,
      primary: primary,
      secondary: secondary,
      error: error,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondary,
      indicatorColor: primary,
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
    ),
    dividerTheme: const DividerThemeData(color: divider, thickness: 1),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static TextStyle heading(double size) => GoogleFonts.poppins(
    color: textPrimary,
    fontSize: size,
    fontWeight: FontWeight.w600,
  );

  static TextStyle body(double size, {Color? color}) => GoogleFonts.inter(
    color: color ?? textPrimary,
    fontSize: size,
    fontWeight: FontWeight.w400,
  );

  static TextStyle label(double size, {Color? color, FontWeight? weight}) => GoogleFonts.inter(
    color: color ?? textSecondary,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w500,
  );
}
