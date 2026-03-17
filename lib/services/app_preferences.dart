import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _languagePrefKey = 'isHindiLanguage';
  static const String _darkModePrefKey = 'isDarkMode';

  static final ValueNotifier<bool> isHindiNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_languagePrefKey)) {
      await prefs.setBool(_languagePrefKey, true);
    }
    if (!prefs.containsKey(_darkModePrefKey)) {
      await prefs.setBool(_darkModePrefKey, false);
    }
    isHindiNotifier.value = prefs.getBool(_languagePrefKey) ?? true;
    themeModeNotifier.value = (prefs.getBool(_darkModePrefKey) ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static Future<void> setHindi(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languagePrefKey, value);
    isHindiNotifier.value = value;
  }

  static Future<void> setDarkMode(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModePrefKey, value);
    themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }
}
