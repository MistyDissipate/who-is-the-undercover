import 'package:flutter/material.dart';
import 'screens/setup_screen.dart' as setup;
import 'screens/host_screen.dart' as host;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '谁是卧底助手',
      initialRoute: '/',
      routes: {
        '/': (context) => setup.SetupScreen(),
        
        // 后续可以添加 '/vote' 等
      },
    );
  }
}