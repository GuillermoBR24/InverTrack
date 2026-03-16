import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://TU_PROJECT_URL.supabase.co',
    anonKey: 'TU_ANON_KEY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi App',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkBlueTheme(),
      darkTheme: _buildDarkBlueTheme(),
      themeMode: ThemeMode.dark,
      home: const LoginScreen(),
    );
  }

  ThemeData _buildDarkBlueTheme() {
    const primaryBlue    = Color(0xFF4FC3F7); // azul claro
    const accentBlue     = Color(0xFF0288D1); // azul medio
    const backgroundDark = Color(0xFF0A0E1A); // casi negro azulado
    const surfaceDark    = Color(0xFF111827); // cards / superficies
    const surfaceCard    = Color(0xFF1E2D3D); // inputs / contenedores
    const textPrimary    = Color(0xFFE8F4FD); // blanco azulado
    const textSecondary  = Color(0xFF7BA7C2); // gris azulado

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary:          primaryBlue,
        onPrimary:        Color(0xFF003A5C),
        secondary:        accentBlue,
        onSecondary:      Colors.white,
        surface:          surfaceDark,
        onSurface:        textPrimary,
        surfaceContainer: surfaceCard,
        error:            Color(0xFFFF6B6B),
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceCard,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
        ),
      ),

      // Tipografía
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textPrimary,   fontWeight: FontWeight.bold),
        bodyLarge:      TextStyle(color: textPrimary),
        bodyMedium:     TextStyle(color: textSecondary),
        labelLarge:     TextStyle(color: textPrimary,   fontWeight: FontWeight.w600),
      ),
    );
  }
}