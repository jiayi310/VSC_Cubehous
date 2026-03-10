import 'package:flutter/material.dart';
import 'common/theme_notifier.dart';
import 'splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadThemePreference();
  runApp(const MyApp());
}
