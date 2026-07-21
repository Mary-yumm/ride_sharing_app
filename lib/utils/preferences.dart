// services/preferences.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class Preferences {
  static Future<void> saveSecondaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('secondaryColor', color.value);
    AppColors.secondary.value = color; // Update the ValueNotifier directly
  }

  static Future<void> loadSecondaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('secondaryColor');
    if (colorValue != null) {
      AppColors.secondary.value = Color(colorValue); // Update the ValueNotifier directly
    }
  }
}
