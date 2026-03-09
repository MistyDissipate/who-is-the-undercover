import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uncover_agent/screens/setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const launchChannel = MethodChannel('plugins.flutter.io/url_launcher');

  Future<void> _pumpSetupScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          releasePageUriOverride: Uri.parse('https://example.com/releases/latest'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('检查更新会直接跳转到发布页（成功）', (tester) async {
    String? launchedUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launchChannel, (call) async {
      if (call.method == 'launch' || call.method == 'launchUrl') {
        final args = call.arguments;
        if (args is String) {
          launchedUrl = args;
        } else if (args is Map) {
          launchedUrl = (args['url'] ?? args['urlString'])?.toString();
        }
        return true;
      }

      if (call.method == 'canLaunch' || call.method == 'canLaunchUrl') {
        return true;
      }

      return null;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launchChannel, null);
    });

    await _pumpSetupScreen(tester);
    await tester.tap(find.byTooltip('检查更新'));
    await tester.pumpAndSettle();

    expect(launchedUrl, 'https://example.com/releases/latest');
    expect(find.text('无法打开发布页，请稍后重试。'), findsNothing);
  });

  testWidgets('检查更新跳转失败时显示提示', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launchChannel, (call) async {
      if (call.method == 'launch' || call.method == 'launchUrl') {
        return false;
      }

      if (call.method == 'canLaunch' || call.method == 'canLaunchUrl') {
        return true;
      }

      return null;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launchChannel, null);
    });

    await _pumpSetupScreen(tester);
    await tester.tap(find.byTooltip('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('无法打开发布页，请稍后重试。'), findsOneWidget);
  });
}
