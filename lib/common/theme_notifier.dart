import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

const _storage = FlutterSecureStorage();

Future<void> loadThemePreference() async {
  final saved = await _storage.read(key: 'themeMode');
  themeNotifier.value = _fromString(saved);
}

Future<void> saveThemePreference(ThemeMode mode) async {
  await _storage.write(key: 'themeMode', value: mode.name);
  themeNotifier.value = mode;
}

ThemeMode _fromString(String? value) {
  if (value == 'dark') return ThemeMode.dark;
  return ThemeMode.light;
}
