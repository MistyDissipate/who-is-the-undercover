import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _defaultName = 'UncoverAgent';

  static void debug(String message, {String name = _defaultName}) {
    if (!kReleaseMode) {
      developer.log(message, name: name, level: 500);
    }
  }

  static void info(String message, {String name = _defaultName}) {
    developer.log(message, name: name, level: 800);
  }

  static void warning(String message, {String name = _defaultName}) {
    developer.log(message, name: name, level: 900);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = _defaultName,
  }) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}