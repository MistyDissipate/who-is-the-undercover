import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uncover_agent/utils/app_logger.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String releasePageUrl;
  final String? downloadUrl;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.releasePageUrl,
    required this.downloadUrl,
  });
}

class UpdateCheckException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRateLimited;
  final String? releasePageUrl;

  const UpdateCheckException(
    this.message, {
    this.statusCode,
    this.isRateLimited = false,
    this.releasePageUrl,
  });

  @override
  String toString() => message;
}

class UpdateService {
  static const String _githubRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: '',
  );

  static bool get isConfigured => _githubRepo.trim().isNotEmpty;

  static String get releaseLatestPageUrl =>
      'https://github.com/$_githubRepo/releases/latest';

  static Future<UpdateInfo> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (_githubRepo.trim().isEmpty) {
      throw const UpdateCheckException(
        '未配置 GITHUB_REPO。请在构建时通过 --dart-define=GITHUB_REPO=owner/repo 传入仓库名。',
      );
    }

    final apiUrl = Uri.parse('https://api.github.com/repos/$_githubRepo/releases/latest');
    final response = await http.get(
      apiUrl,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'uncover-agent-app',
      },
    );

    if (response.statusCode != 200) {
      final body = response.body;
      final looksLikeRateLimit = response.statusCode == 403 &&
          (body.contains('API rate limit exceeded') ||
              body.contains('rate limit') ||
              response.headers['x-ratelimit-remaining'] == '0');

      if (looksLikeRateLimit) {
        throw UpdateCheckException(
          'GitHub API 触发限流，请稍后再试。',
          statusCode: response.statusCode,
          isRateLimited: true,
          releasePageUrl: releaseLatestPageUrl,
        );
      }

      throw UpdateCheckException(
        'GitHub API 请求失败（${response.statusCode}）',
        statusCode: response.statusCode,
        releasePageUrl: releaseLatestPageUrl,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersionRaw = (json['tag_name'] as String? ?? '').trim();
    final latestVersion = _normalizeVersion(latestVersionRaw);
    final releasePageUrl = (json['html_url'] as String? ?? '').trim();
    final releaseNotes = (json['body'] as String? ?? '').trim();

    if (latestVersion.isEmpty || releasePageUrl.isEmpty) {
      throw const UpdateCheckException('GitHub Release 数据不完整，请检查 tag 与发布页链接。');
    }

    final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;
    final downloadUrl = _resolveDownloadUrl(json, releasePageUrl);

    AppLogger.info(
      'Update check completed (current=$currentVersion, latest=$latestVersion, hasUpdate=$hasUpdate)',
      name: 'UpdateService',
    );

    return UpdateInfo(
      hasUpdate: hasUpdate,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseNotes: releaseNotes,
      releasePageUrl: releasePageUrl,
      downloadUrl: downloadUrl,
    );
  }

  static String _resolveDownloadUrl(
    Map<String, dynamic> releaseJson,
    String fallbackUrl,
  ) {
    final assets = releaseJson['assets'];
    if (assets is! List) {
      return fallbackUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = (asset['browser_download_url'] as String? ?? '').trim();
        if (name.endsWith('.apk') && url.isNotEmpty) {
          return url;
        }
      }
    }

    return fallbackUrl;
  }

  static String _normalizeVersion(String version) {
    var normalized = version.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  static int _compareVersions(String a, String b) {
    final aParts = _parseVersionParts(a);
    final bParts = _parseVersionParts(b);
    final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;

    for (var i = 0; i < maxLen; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) {
        return av > bv ? 1 : -1;
      }
    }
    return 0;
  }

  static List<int> _parseVersionParts(String version) {
    final withoutBuild = version.split('+').first;
    final withoutPreRelease = withoutBuild.split('-').first;
    return withoutPreRelease
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }
}
