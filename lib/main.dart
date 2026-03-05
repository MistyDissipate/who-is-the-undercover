import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uncover_agent/utils/app_logger.dart';
import 'screens/setup_screen.dart' as setup;

void main() {
  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter framework error',
      name: 'Main',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  AppLogger.info('Application starting', name: 'Main');
  runApp(const MyApp());
}

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
        '/': (context) => const setup.SetupScreen(),
        
        // 后续可以添加 '/vote' 等
      },
    );
  }
}