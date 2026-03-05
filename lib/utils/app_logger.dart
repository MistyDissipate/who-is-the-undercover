import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _defaultName = 'UncoverAgent';
  static const int _maxBufferedLogs = 400;
  static final List<String> _bufferedLogs = <String>[];

  static void _appendBufferedLog({
    required String level,
    required String name,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final parts = <String>['[$timestamp][$level][$name] $message'];

    if (error != null) {
      parts.add('error: $error');
    }

    if (stackTrace != null) {
      parts.add('stack: $stackTrace');
    }

    _bufferedLogs.add(parts.join('\n'));
    if (_bufferedLogs.length > _maxBufferedLogs) {
      _bufferedLogs.removeRange(0, _bufferedLogs.length - _maxBufferedLogs);
    }
  }

  static String exportBufferedLogs({int maxLines = 120}) {
    if (_bufferedLogs.isEmpty) {
      return '暂无日志记录';
    }

    final start = _bufferedLogs.length > maxLines ? _bufferedLogs.length - maxLines : 0;
    return _bufferedLogs.sublist(start).join('\n\n');
  }

  static String buildIssueReport({
    String? userDescription,
    String? issueType,
  }) {
    final platformName = defaultTargetPlatform.name;
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
            ? 'profile'
            : 'debug';

    final description = (userDescription ?? '').trim();
    final normalizedDescription = description.isEmpty ? '未填写复现步骤' : description;
    final normalizedIssueType = (issueType ?? '').trim().isEmpty ? '其他' : issueType!.trim();
    final sections = <String>[
      '问题反馈时间: ${DateTime.now().toIso8601String()}',
      '运行平台: ${kIsWeb ? 'web' : platformName}',
      '构建模式: $mode',
      '问题类型: $normalizedIssueType',
      '用户描述:\n$normalizedDescription',
      '最近日志:\n${exportBufferedLogs()}',
    ];

    return sections.join('\n\n');
  }

  static void debug(String message, {String name = _defaultName}) {
    _appendBufferedLog(level: 'DEBUG', name: name, message: message);
    if (!kReleaseMode) {
      developer.log(message, name: name, level: 500);
    }
  }

  static void info(String message, {String name = _defaultName}) {
    _appendBufferedLog(level: 'INFO', name: name, message: message);
    developer.log(message, name: name, level: 800);
  }

  static void warning(String message, {String name = _defaultName}) {
    _appendBufferedLog(level: 'WARN', name: name, message: message);
    developer.log(message, name: name, level: 900);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = _defaultName,
  }) {
    _appendBufferedLog(
      level: 'ERROR',
      name: name,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}