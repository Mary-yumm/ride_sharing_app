// utils/app_colors.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color white = Color(0xFFFFFFFF); // Example light mode primary color
  static const Color primary = Color(0xFF3F3F3F);  // Example dark mode primary color
  static ValueNotifier<Color> secondary = ValueNotifier<Color>(Color(0xFF4E5D94));
  static const Color secondaryLight = Color(0xFF7280b4); // Example light mode secondary color

  static const Color primaryLight = Color(0xFF5A5A5A); // Slightly lighter than 0xFF3F3F3F
  static const Color textGrey = Colors.grey;
  static const Color lightGrey = Color(0xFFF0F0F0);

  static Future<void> loadColor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('secondaryColor');
    if (colorValue != null) {
      secondary.value = Color(colorValue);
    }
  }

  static Future<void> saveColor(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secondaryColor', color.value);
  }
}
