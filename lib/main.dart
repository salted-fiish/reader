import 'package:flutter/material.dart';
import 'providers/theme_provider.dart';
import 'screens/bookshelf_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      isDarkMode: _isDarkMode,
      toggleTheme: _toggleTheme,
      child: MaterialApp(
        title: 'PDF Reader',
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2C2C2C),      // 主要颜色：深灰色
            secondary: Color(0xFF4A4A4A),    // 次要颜色：中灰色
            surface: Colors.white,            // 表面颜色：白色
            background: Color(0xFFF5F5F5),    // 背景色：浅灰色
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Colors.white,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1A1A1A),
            secondary: Color(0xFF2C2C2C),
            surface: Color(0xFF121212),
            background: Color(0xFF000000),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Color(0xFF121212),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        home: const BookshelfScreen(),
      ),
    );
  }
}
