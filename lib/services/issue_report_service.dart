import 'package:uncover_agent/utils/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class IssueReportService {
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'sitegoose@gmail.com',
  );

  static Future<bool> sendLogsByEmail({
    String? userDescription,
    String? issueType,
  }) async {
    final normalizedIssueType = (issueType ?? '').trim().isEmpty ? '其他' : issueType!.trim();
    final body = AppLogger.buildIssueReport(
      userDescription: userDescription,
      issueType: normalizedIssueType,
    );
    final subject =
        'UncoverAgent 问题反馈[$normalizedIssueType] ${DateTime.now().toIso8601String()}';

    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      AppLogger.warning('No email client available for issue report', name: 'IssueReportService');
      return false;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      AppLogger.info('Issue report email client launched', name: 'IssueReportService');
    } else {
      AppLogger.warning('Failed to launch email client for issue report', name: 'IssueReportService');
    }

    return launched;
  }
}