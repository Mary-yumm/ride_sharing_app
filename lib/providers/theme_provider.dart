import 'package:flutter/material.dart';
import '../../utils/app_colors.dart'; // Import your colors

class ThemeProvider extends ChangeNotifier {
  bool _isDarkTheme = false;

  bool get isDarkTheme => _isDarkTheme;

  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    notifyListeners();
  }

  ThemeData get themeData {
    return _isDarkTheme ? _darkTheme : _lightTheme;
  }

  ThemeData get _lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.white,
      hintColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.white,
      );
  }

  ThemeData get _darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      hintColor: AppColors.white,
      scaffoldBackgroundColor: AppColors.primary,

      );
  }
}
//Theme.of(context).hintColor
