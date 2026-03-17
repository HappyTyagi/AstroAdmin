import 'package:flutter/material.dart';

class AdminAppTheme {
  static const String fontFamily = 'Calibri';
  static const Color primaryIndigo = Color(0xFF2B1B4B);
  static const Color deepBlue = Color(0xFF1E2150);
  static const Color gold = Color(0xFFEAB75B);
  static const Color cream = Color(0xFFF7F4EA);
  static const Color ink = Color(0xFF1D243D);
  static const Color muted = Color(0xFF6F7693);
  static const Color success = Color(0xFF198754);
  static const Color danger = Color(0xFFC94C4C);
  static const Color midnight = primaryIndigo;
  static const Color royal = deepBlue;
  static const Color blush = cream;

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = base.colorScheme.copyWith(
      primary: primaryIndigo,
      secondary: gold,
      tertiary: gold,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
    );

    return base.copyWith(
      scaffoldBackgroundColor: cream,
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryIndigo),
        actionsIconTheme: IconThemeData(color: primaryIndigo),
      ),
      iconTheme: const IconThemeData(color: primaryIndigo),
      primaryIconTheme: const IconThemeData(color: primaryIndigo),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: gold.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryIndigo : muted.withValues(alpha: 0.9),
          );
        }),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dividerTheme: DividerThemeData(
        color: primaryIndigo.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryIndigo.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryIndigo.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: primaryIndigo,
          side: BorderSide(
            color: primaryIndigo.withValues(alpha: 0.22),
            width: 1.2,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = base.colorScheme.copyWith(
      primary: gold,
      secondary: gold,
      tertiary: gold,
      surface: const Color(0xFF171A24),
      surfaceTint: Colors.transparent,
      onSurface: Colors.white,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F1219),
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: gold),
        actionsIconTheme: IconThemeData(color: gold),
      ),
      iconTheme: const IconThemeData(color: gold),
      primaryIconTheme: const IconThemeData(color: gold),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF171A24),
        indicatorColor: gold.withValues(alpha: 0.24),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? gold : gold.withValues(alpha: 0.78),
          );
        }),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF171A24),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF232A3A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B1F2B),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: gold,
          foregroundColor: ink,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: gold,
          foregroundColor: ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1.2,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF171A24),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF171A24),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static BoxDecoration glassCard({
    List<Color>? colors,
    Border? border,
    double radius = 24,
    bool isDark = false,
  }) {
    final resolvedColors =
        colors ??
        (isDark
            ? <Color>[const Color(0xFF1A1F2C), const Color(0xFF141925)]
            : <Color>[Colors.white, Colors.white.withValues(alpha: 0.92)]);
    final resolvedBorder =
        border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : royal.withValues(alpha: 0.08),
          width: 1,
        );
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.26)
        : royal.withValues(alpha: 0.08);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: resolvedColors,
      ),
      border: resolvedBorder,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: shadowColor,
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
      ],
    );
  }

  static BoxDecoration pageBackdrop({bool isDark = false}) {
    if (isDark) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0F1219),
            Color(0xFF161A26),
            Color(0xFF10131C),
          ],
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFFFFBF3), Color(0xFFF7F1FF), cream],
      ),
    );
  }
}
