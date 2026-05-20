import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Цвета бренда
  static const Color primaryOrange = Color(0xFFFF8A5B);
  static const Color primaryPink = Color(0xFFFF5A82);
  static const Color accentRed = Color(0xFFFF706E);
  
  // Дополнительные цвета для UI
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  
  // Светлая тема
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryOrange,
    scaffoldBackgroundColor: surfaceLight,
    
    colorScheme: const ColorScheme.light(
      primary: primaryOrange,
      secondary: primaryPink,
      surface: Colors.white,
      background: surfaceLight,
      error: Color(0xFFEF4444),
      onSurface: textPrimary,
      outline: borderLight,
    ),
    
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF374151), height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderLight, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderLight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
    ),
    
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderLight, width: 1),
      ),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primaryOrange.withOpacity(0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryOrange);
        }
        return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryOrange, size: 24);
        }
        return const IconThemeData(color: textSecondary, size: 24);
      }),
    ),
    
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    
    dividerTheme: const DividerThemeData(
      color: borderLight,
      thickness: 1,
    ),
    
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    dialogTheme: DialogThemeData(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
  
  // Темная тема
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryOrange,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    
    colorScheme: const ColorScheme.dark(
      primary: primaryOrange,
      secondary: primaryPink,
      surface: Color(0xFF1E293B),
      background: Color(0xFF0F172A),
      error: Color(0xFFF87171),
      onSurface: Colors.white,
      outline: Color(0xFF334155),
    ),
    
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFCBD5E1), height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
    ),
    
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      color: const Color(0xFF1E293B),
      surfaceTintColor: Colors.transparent,
    ),
    
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: const Color(0xFF1E293B),
      surfaceTintColor: Colors.transparent,
      indicatorColor: primaryOrange.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryOrange);
        }
        return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryOrange, size: 24);
        }
        return const IconThemeData(color: Color(0xFF94A3B8), size: 24);
      }),
    ),
    
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    
    dividerTheme: const DividerThemeData(
      color: Color(0xFF334155),
      thickness: 1,
    ),
    
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1E293B),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    dialogTheme: DialogThemeData(
      surfaceTintColor: Colors.transparent,
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
  
  // Градиент
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryOrange, primaryPink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  // Мягкий градиент для фонов
  static const LinearGradient softGradient = LinearGradient(
    colors: [Color(0x14FF8A5B), Color(0x14FF5A82)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
