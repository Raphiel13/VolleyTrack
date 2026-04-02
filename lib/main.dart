import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:volleytrack/models/models.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const VolleyManagerApp());
}

class VolleyManagerApp extends StatefulWidget {
  const VolleyManagerApp({super.key});

  @override
  State<VolleyManagerApp> createState() => _VolleyManagerAppState();
}

class _VolleyManagerAppState extends State<VolleyManagerApp> {
  // Default: follow system preference
  final AppThemeMode _themeMode = AppThemeMode.system;

  ThemeMode get _materialThemeMode => switch (_themeMode) {
    AppThemeMode.light  => ThemeMode.light,
    AppThemeMode.dark   => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VolleyManager',
      debugShowCheckedModeBanner: false,
      themeMode: _materialThemeMode,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: const Scaffold(
        body: Center(
          child: Text('VolleyManager'),
        ),
      ),
    );
  }
}