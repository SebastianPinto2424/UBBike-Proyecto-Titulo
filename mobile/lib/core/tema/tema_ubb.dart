import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

ThemeData crearTemaUbb() {
  const esquema = ColorScheme.light(
    primary: ColoresUbb.azulApp,
    onPrimary: Colors.white,
    secondary: ColoresUbb.turquesa,
    onSecondary: ColoresUbb.azulNoche,
    tertiary: ColoresUbb.azulApp,
    onTertiary: Colors.white,
    error: ColoresUbb.rojoInstitucional,
    onError: Colors.white,
    surface: ColoresUbb.superficie,
    onSurface: ColoresUbb.textoPrincipal,
    outline: ColoresUbb.bordeFuerte,
    outlineVariant: ColoresUbb.borde,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresUbb.fondo,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: ColoresUbb.textoPrincipal,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: ColoresUbb.textoPrincipal,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: ColoresUbb.textoPrincipal,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: ColoresUbb.textoPrincipal,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(color: ColoresUbb.textoPrincipal, letterSpacing: 0),
      bodyMedium: TextStyle(color: ColoresUbb.textoPrincipal, letterSpacing: 0),
      bodySmall: TextStyle(color: ColoresUbb.textoSecundario, letterSpacing: 0),
      labelLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
      labelMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresUbb.azulNoche,
      foregroundColor: Colors.white,
      surfaceTintColor: ColoresUbb.azulNoche,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: ColoresUbb.superficie,
      elevation: 0.5,
      shadowColor: ColoresUbb.textoPrincipal.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ColoresUbb.borde),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresUbb.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColoresUbb.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: ColoresUbb.azulApp,
          width: 1.6,
        ),
      ),
      prefixIconColor: ColoresUbb.azulApp,
      labelStyle: const TextStyle(color: ColoresUbb.textoSecundario),
      floatingLabelStyle: const TextStyle(
        color: ColoresUbb.azulApp,
        fontWeight: FontWeight.w800,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ColoresUbb.azulApp,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ColoresUbb.grisInstitucional,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
      height: 66,
      indicatorColor: ColoresUbb.superficieAzulSuave,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? ColoresUbb.azulApp
              : ColoresUbb.textoSecundario,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          fontSize: 11,
          letterSpacing: -0.2,
          height: 1.1,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? ColoresUbb.azulApp
              : ColoresUbb.textoSecundario,
        );
      }),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresUbb.azulApp,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        side: const BorderSide(color: ColoresUbb.bordeFuerte),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoresUbb.azulApp,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ColoresUbb.azulApp;
          }
          return Colors.white;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return ColoresUbb.azulApp;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(
            color: states.contains(WidgetState.selected)
                ? ColoresUbb.azulApp
                : ColoresUbb.bordeFuerte,
          );
        }),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColoresUbb.azulNoche,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: ColoresUbb.borde,
      thickness: 1,
      space: 1,
    ),
  );
}
