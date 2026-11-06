import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../data/repositories/settings_repository.dart';
import 'app_state.dart';

enum SmsImportStatus { success, unsupported, permissionDenied, busy, failed }

class SmsImportSummary {
  final SmsImportStatus status;
  final int scanned;
  final int imported;
  final int duplicates;
  final int ignored;
  final String message;
  final DateTime? newestMessageAt;

  const SmsImportSummary({
    required this.status,
    this.scanned = 0,
    this.imported = 0,
    this.duplicates = 0,
    this.ignored = 0,
    required this.message,
    this.newestMessageAt,
  });

  bool get isSuccess => status == SmsImportStatus.success;
}

/// Reads the Android SMS inbox and feeds bank/telecom alerts through the same
/// on-device parser used by manual SMS ingestion. Messages are never uploaded.
class AndroidSmsService {
  static const MethodChannel _channel = MethodChannel(
    'com.ledgerleaf/automation',
  );
  static final AndroidSmsService instance = AndroidSmsService();

  final SettingsRepository _settingsRepo;
  bool _isImporting = false;

  AndroidSmsService({SettingsRepository? settingsRepo})
    : _settingsRepo = settingsRepo ?? SettingsRepository();

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Broad financial-keyword/sender check so personal SMS never reach the
  /// parser or its audit log. The actual parsers still decide what is a
  /// transaction.
  static bool looksLikeFinancialSms(String body, {String? sender}) {
    final haystack = '${sender ?? ''}\n$body'.toLowerCase();
    return _financialPattern.hasMatch(haystack);
  }

  static final RegExp _financialPattern = RegExp(
    r'(\betb\b|\bbirr\b|ብር|\bdebited\b|\bcredited\b|\bpaid\b|\btransferred\b|'
    r'\bwithdrawn\b|\bdeposit\b|\bpurchase\b|\bpurchased\b|\bbalance\b|'
    r'\btransaction\b|\baccount\b|\btelebirr\b|\bm-?pesa\b|\bsafaricom\b|'
    r'\bcbe\b|\babyssinia\b|\bboa\b|\bdashen\b|\bamole\b|\bbank\b|\bbundle\b|'
    r'\bairtime\b|\btop ?up\b|\bgb\b|\bmb\b|\bminutes\b|\bactivated\b|'
    r'\bpayment\b|\bcharged\b|\bdeducted\b|\bsms\b|\bref\b|\btxn\b|'
    r'ተቀንሷል|ተጨምሯል|ተከፍሏል|ቀሪ|ወጪ|ገቢ)',
    caseSensitive: false,
  );

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    if (await hasPermission()) return true;

    try {
      final granted = await _channel
          .invokeMethod<bool>('requestSmsPermission')
          .timeout(const Duration(minutes: 2));
      return granted ?? false;
    } on PlatformException {
      return hasPermission();
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Imports SMS newer than the last successful sync. The first run looks back
  /// [initialLookbackDays] so existing bank alerts are captured immediately.
  Future<SmsImportSummary> importRecentMessages(
    AppState appState, {
    int limit = 500,
    bool includeAlreadySynced = false,
  }) async {
    if (!isSupported) {
      return const SmsImportSummary(
        status: SmsImportStatus.unsupported,
        message: 'Automatic SMS import is only available on Android.',
      );
    }
    if (_isImporting) {
      return const SmsImportSummary(
        status: SmsImportStatus.busy,
        message: 'An SMS import is already running.',
      );
    }

    _isImporting = true;
    try {
      if (!await hasPermission()) {
        return const SmsImportSummary(
          status: SmsImportStatus.permissionDenied,
          message:
              'SMS permission is required. Allow it for LedgerLeaf in '
              'Settings > Apps > LedgerLeaf > Permissions.',
        );
      }

      final since = includeAlreadySynced ? 0 : await _syncStartMillis();

      final rawMessages =
          await _channel.invokeListMethod<dynamic>('readSmsInbox', {
            'since': since,
            'limit': limit,
          }) ??
          const [];

      var imported = 0;
      var duplicates = 0;
      var ignored = 0;
      var scanned = 0;
      int? newestMillis;

      for (final rawMessage in rawMessages) {
        if (rawMessage is! Map) continue;
        final body = (rawMessage['body'] as String?)?.trim();
        if (body == null || body.isEmpty) continue;

        final sender = rawMessage['sender'] as String?;
        final dateMillis = (rawMessage['date'] as num?)?.toInt();
        final messageTime = dateMillis == null || dateMillis <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(dateMillis);

        scanned++;

        if (!looksLikeFinancialSms(body, sender: sender)) {
          ignored++;
          continue;
        }

        final response = await appState.ingestSms(
          body,
          sender: sender,
          messageTime: messageTime,
          reload: false,
        );

        if (response.isDuplicate) {
          duplicates++;
        } else if (response.success) {
          imported++;
        } else {
          ignored++;
        }

        if (dateMillis != null &&
            dateMillis > 0 &&
            (newestMillis == null || dateMillis > newestMillis)) {
          newestMillis = dateMillis;
        }
      }

      if (scanned > 0) {
        await appState.reloadAll();
        await _settingsRepo.setSetting(
          AppConstants.keyLastSmsSyncAt,
          (newestMillis ?? DateTime.now().millisecondsSinceEpoch).toString(),
        );
      }

      return SmsImportSummary(
        status: SmsImportStatus.success,
        scanned: scanned,
        imported: imported,
        duplicates: duplicates,
        ignored: ignored,
        newestMessageAt: newestMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(newestMillis),
        message: _summaryMessage(
          scanned: scanned,
          imported: imported,
          duplicates: duplicates,
          ignored: ignored,
        ),
      );
    } on PlatformException catch (error) {
      return SmsImportSummary(
        status: SmsImportStatus.failed,
        message: 'SMS import failed: ${error.message ?? error.code}',
      );
    } on MissingPluginException {
      return const SmsImportSummary(
        status: SmsImportStatus.failed,
        message: 'SMS import is unavailable in this build.',
      );
    } catch (error) {
      return SmsImportSummary(
        status: SmsImportStatus.failed,
        message: 'SMS import failed: $error',
      );
    } finally {
      _isImporting = false;
    }
  }

  Future<int> _syncStartMillis() async {
    final stored = await _settingsRepo.getSetting(
      AppConstants.keyLastSmsSyncAt,
    );
    final lastSync = int.tryParse(stored ?? '');
    if (lastSync == null || lastSync <= 0) {
      return DateTime.now()
          .subtract(const Duration(days: initialLookbackDays))
          .millisecondsSinceEpoch;
    }

    // Re-scan one day of overlap so messages delivered slightly out of order
    // are not missed. The ingestion fingerprint still rejects duplicates.
    return lastSync - const Duration(days: 1).inMilliseconds;
  }

  String _summaryMessage({
    required int scanned,
    required int imported,
    required int duplicates,
    required int ignored,
  }) {
    if (scanned == 0) {
      return 'No new SMS messages found.';
    }
    final parts = <String>[
      '$imported new transaction${imported == 1 ? '' : 's'} imported',
    ];
    if (duplicates > 0) parts.add('$duplicates duplicate');
    if (ignored > 0) parts.add('$ignored non-financial ignored');
    return 'Scanned $scanned SMS: ${parts.join(', ')}.';
  }

  static const int initialLookbackDays = 90;
}
