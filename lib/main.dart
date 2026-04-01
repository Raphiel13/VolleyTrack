import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const VolleyManagerApp());
}

class VolleyManagerApp extends StatelessWidget {
  const VolleyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'VolleyManager',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text('VolleyManager'),
        ),
      ),
    );
  }
}