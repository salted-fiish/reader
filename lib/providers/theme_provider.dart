import 'package:flutter/material.dart';

class ThemeProvider extends InheritedWidget {
  final bool isDarkMode;
  final Function(bool) toggleTheme;

  const ThemeProvider({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
    required super.child,
  });

  static ThemeProvider of(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<ThemeProvider>()!;
    return element.widget as ThemeProvider;
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return isDarkMode != oldWidget.isDarkMode;
  }
} 