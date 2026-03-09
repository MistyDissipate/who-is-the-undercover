import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uncover_agent/utils/app_logger.dart';
import 'screens/setup_screen.dart' as setup;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureOrientationPolicy();

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

// 判断设备类型并设置屏幕方向，平板允许所有方向，手机仅允许竖屏
Future<void> _configureOrientationPolicy() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  final isTablet = logicalSize.shortestSide >= 600; // 认为超过600就是pad端

  if (isTablet) {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    return;
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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