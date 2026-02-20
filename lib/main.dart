import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/setup_screen.dart' as setup;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '谁是卧底助手',
      theme: ThemeData(
        textTheme: GoogleFonts.notoSansScTextTheme(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => setup.SetupScreen(),
        
        // 后续可以添加 '/vote' 等
      },
    );
  }
}