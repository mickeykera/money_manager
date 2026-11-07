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
  final int balanceUpdates;
  final int ignored;
  final String message;
  final DateTime? newestMessageAt;

  const SmsImportSummary({
    required this.status,
    this.scanned = 0,
    this.imported = 0,
    this.duplicates = 0,
    this.balanceUpdates = 0,
    this.ignored = 0,
    required this.message,
    this.newestMessageAt,
  });

  bool get isSuccess => status == SmsImportStatus.success;
}

class _InboxMessage {
  final int id;
  final String? sender;
  final String body;
  final int dateMillis;

  const _InboxMessage({
    this.id = 0,
    required this.sender,
    required this.body,
    required this.dateMillis,
  });
}

class _InboxScanResult {
  final List<_InboxMessage> messages;
  final bool completed;
  final int? oldestMillis;
  final int? oldestId;

  const _InboxScanResult({
    required this.messages,
    required this.completed,
    this.oldestMillis,
    this.oldestId,
  });
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

  /// Sender IDs that are known to send bank, wallet or telecom alerts.
  ///
  /// Checking the sender first means a genuine alert is never dropped just
  /// because it is written in Amharic or uses a keyword we did not anticipate.
  static bool isKnownFinancialSender(String? sender) {
    if (sender == null) return false;
    final normalized = sender.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (normalized.isEmpty) return false;

    if (_knownFinancialSenderIds.contains(normalized)) return true;

    return normalized.contains('bank') ||
        normalized.contains('telecom') ||
        normalized.contains('telebirr') ||
        normalized.contains('mpesa') ||
        normalized.contains('safaricom') ||
        normalized.contains('abyssinia') ||
        normalized.contains('dashen') ||
        normalized.contains('amole') ||
        normalized.contains('awash') ||
        normalized.contains('cbe');
  }

  static const Set<String> _knownFinancialSenderIds = {
    // Ethio telecom package alerts. 251994 is the international form.
    '994',
    '0994',
    '251994',
    '00251994',
    // CBE / Telebirr short code.
    '127',
    'cbe',
    'cbebirr',
    'telebirr',
    // Safaricom M-PESA and Safaricom Ethiopia.
    '700',
    '0700',
    '251700',
    '704',
    '0704',
    '251704',
    '777',
    '0777',
    '251777',
    'mpesa',
    'safaricom',
    'safaricomet',
    // Other Ethiopian banks.
    'boa',
    'abyssinia',
    'bankofabyssinia',
    'dashen',
    'amole',
    'awash',
    'united',
    'nib',
    'wegagen',
    'berhan',
    'zemen',
    'coop',
    'oromia',
    'bunna',
    'hibret',
    'enat',
    'ethiotelecom',
    'ethiotel',
  };

  /// Broad financial-keyword/sender check so personal SMS never reach the
  /// parser or its audit log. The actual parsers still decide what is a
  /// transaction or a balance update.
  static bool looksLikeFinancialSms(String body, {String? sender}) {
    if (isKnownFinancialSender(sender)) return true;
    return _financialPattern.hasMatch(body.toLowerCase());
  }

  static final RegExp _financialPattern = RegExp(
    r'(\betb\b|\bbirr\b|ብር|\bdebited\b|\bcredited\b|\bdebit\b|\bcredit\b|'
    r'\bpaid\b|\bpayment\b|\btransferred\b|\btransfer\b|\bwithdrawn\b|'
    r'\bwithdrawal\b|\bdeposit(?:ed)?\b|\bpurchas(?:e|ed|ing)\b|\bbought\b|'
    r'\brecharg(?:e|ed|ing)\b|\bsubscrib(?:e|ed|ing|ption)\b|'
    r'\brenew(?:ed|al|ing)?\b|\bactivat(?:e|ed|ion|ing)\b|\btop ?up\b|'
    r'\bbalance\b|\bavailable\b|\bremaining\b|\busage\b|\bused\b|'
    r'\btransaction\b|\baccount\b|\bacct\b|\btelebirr\b|\bm-?pesa\b|'
    r'\bsafaricom\b|\bethio ?telecom\b|\bcbe\b|\babyssinia\b|\bboa\b|'
    r'\bdashen\b|\bamole\b|\bawash\b|\bbank\b|\bbundle\b|\bpackage\b|'
    r'\bairtime\b|\binternet\b|\bdata\b|\bgb\b|\bmb\b|\bminutes\b|'
    r'\bmins\b|\bsms\b|\bvoice\b|\bvalid (?:until|till|up to)\b|'
    r'\bexpir(?:e|es|ed|ing)\b|\bref\b|\btxn\b|'
    r'ተቀንሷል|ተጨምሯል|ተከፍሏል|ቀሪ|ወጪ|ገቢ|ተሞልቷል|ገዝተዋል|አስገብተዋል|'
    r'ተመዝግቧል|ሂሳብ|ባንክ|ፓኬጅ|ጥቅም)',
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

  /// Imports bank/telecom SMS from the inbox.
  ///
  /// The first run scans [initialLookbackDays] of history. Later runs only scan
  /// since the last successful sync. Both modes page backwards through the
  /// inbox, so a busy inbox is never truncated at the first page.
  Future<SmsImportSummary> importRecentMessages(
    AppState appState, {
    int pageSize = defaultPageSize,
    int maxPages = defaultMaxPages,
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

      final since = includeAlreadySynced
          ? _lookbackStartMillis()
          : await _syncStartMillis();

      final scan = await _readMessages(
        since: since,
        pageSize: pageSize,
        maxPages: maxPages,
      );

      // Process oldest-first so balance alerts end on the most recent value.
      scan.messages.sort((a, b) => a.dateMillis.compareTo(b.dateMillis));

      var imported = 0;
      var duplicates = 0;
      var balanceUpdates = 0;
      var ignored = 0;
      var scanned = 0;
      int? newestMillis;

      for (final message in scan.messages) {
        final dateMillis = message.dateMillis;
        final messageTime = dateMillis <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(dateMillis);

        scanned++;

        if (!looksLikeFinancialSms(message.body, sender: message.sender)) {
          ignored++;
          continue;
        }

        final response = await appState.ingestSms(
          message.body,
          sender: message.sender,
          messageTime: messageTime,
          reload: false,
        );

        if (response.isDuplicate) {
          duplicates++;
        } else if (response.isBalanceUpdate) {
          balanceUpdates++;
        } else if (response.success) {
          imported++;
        } else {
          ignored++;
        }

        if (dateMillis > 0 &&
            (newestMillis == null || dateMillis > newestMillis)) {
          newestMillis = dateMillis;
        }
      }

      if (scanned > 0) {
        await appState.reloadAll();

        // When every page was read, the newest message is a safe cursor. If a
        // very large inbox hit the page cap, resume from the oldest message on
        // the next run instead of skipping the remainder.
        final cursor = scan.completed
            ? (newestMillis ?? DateTime.now().millisecondsSinceEpoch)
            : (scan.oldestMillis != null
                  ? scan.oldestMillis! - 1
                  : DateTime.now().millisecondsSinceEpoch);
        await _settingsRepo.setSetting(
          AppConstants.keyLastSmsSyncAt,
          cursor.toString(),
        );
      }

      return SmsImportSummary(
        status: SmsImportStatus.success,
        scanned: scanned,
        imported: imported,
        duplicates: duplicates,
        balanceUpdates: balanceUpdates,
        ignored: ignored,
        newestMessageAt: newestMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(newestMillis),
        message: _summaryMessage(
          scanned: scanned,
          imported: imported,
          duplicates: duplicates,
          balanceUpdates: balanceUpdates,
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

  /// Pages backwards through the inbox until the lookback window is exhausted
  /// or [maxPages] is reached.
  Future<_InboxScanResult> _readMessages({
    required int since,
    required int pageSize,
    required int maxPages,
  }) async {
    final messages = <_InboxMessage>[];
    final seen = <String>{};
    var before = 0;
    var beforeId = 0;
    var completed = true;
    int? oldestMillis;
    int? oldestId;

    for (var page = 0; page < maxPages; page++) {
      final rawMessages =
          await _channel.invokeListMethod<dynamic>('readSmsInbox', {
            'since': since,
            'before': before,
            'beforeId': beforeId,
            'limit': pageSize,
          }) ??
          const [];

      var oldestOnPage = 0;
      var oldestOnPageId = 0;
      for (final rawMessage in rawMessages) {
        if (rawMessage is! Map) continue;
        final body = (rawMessage['body'] as String?)?.trim();
        if (body == null || body.isEmpty) continue;

        final id = (rawMessage['id'] as num?)?.toInt() ?? 0;
        final sender = rawMessage['sender'] as String?;
        final dateMillis = (rawMessage['date'] as num?)?.toInt() ?? 0;
        final key = id > 0 ? 'id:$id' : '$sender|$dateMillis|${body.hashCode}';
        if (!seen.add(key)) continue;

        messages.add(
          _InboxMessage(
            id: id,
            sender: sender,
            body: body,
            dateMillis: dateMillis,
          ),
        );

        final isOlderOnPage =
            dateMillis > 0 &&
            (oldestOnPage == 0 ||
                dateMillis < oldestOnPage ||
                (dateMillis == oldestOnPage &&
                    id > 0 &&
                    (oldestOnPageId == 0 || id < oldestOnPageId)));
        if (isOlderOnPage) {
          oldestOnPage = dateMillis;
          oldestOnPageId = id;
        }

        final isOlderOverall =
            dateMillis > 0 &&
            (oldestMillis == null ||
                dateMillis < oldestMillis ||
                (dateMillis == oldestMillis &&
                    id > 0 &&
                    (oldestId == null || id < oldestId)));
        if (isOlderOverall) {
          oldestMillis = dateMillis;
          oldestId = id;
        }
      }

      if (rawMessages.length < pageSize) {
        completed = true;
        break;
      }

      if (oldestOnPage == 0) {
        // The page was full of unusable rows; stop rather than loop forever.
        completed = false;
        break;
      }

      // No cursor progress means the remaining rows cannot be reached.
      if (oldestOnPage == before && oldestOnPageId == beforeId) {
        completed = false;
        break;
      }

      before = oldestOnPage;
      beforeId = oldestOnPageId;
      if (since > 0 && before <= since) {
        completed = true;
        break;
      }

      if (page == maxPages - 1) {
        completed = false;
      }
    }

    return _InboxScanResult(
      messages: messages,
      completed: completed,
      oldestMillis: oldestMillis,
      oldestId: oldestId,
    );
  }

  int _lookbackStartMillis() {
    return DateTime.now()
        .subtract(const Duration(days: initialLookbackDays))
        .millisecondsSinceEpoch;
  }

  Future<int> _syncStartMillis() async {
    final stored = await _settingsRepo.getSetting(
      AppConstants.keyLastSmsSyncAt,
    );
    final lastSync = int.tryParse(stored ?? '');
    if (lastSync == null || lastSync <= 0) {
      return _lookbackStartMillis();
    }

    // Re-scan one day of overlap so messages delivered slightly out of order
    // are not missed. The ingestion fingerprint still rejects duplicates.
    final overlap = lastSync - const Duration(days: 1).inMilliseconds;
    final lookback = _lookbackStartMillis();
    return overlap < lookback ? lookback : overlap;
  }

  String _summaryMessage({
    required int scanned,
    required int imported,
    required int duplicates,
    required int balanceUpdates,
    required int ignored,
  }) {
    if (scanned == 0) {
      return 'No new SMS messages found.';
    }
    final parts = <String>[
      '$imported new transaction${imported == 1 ? '' : 's'} imported',
    ];
    if (balanceUpdates > 0) {
      parts.add(
        '$balanceUpdates balance update${balanceUpdates == 1 ? '' : 's'}',
      );
    }
    if (duplicates > 0) parts.add('$duplicates duplicate');
    if (ignored > 0) parts.add('$ignored non-financial ignored');
    return 'Scanned $scanned SMS: ${parts.join(', ')}.';
  }

  /// How far back the first scan (and "Import SMS now") looks.
  static const int initialLookbackDays = 365;

  /// Inbox rows fetched per native query.
  static const int defaultPageSize = 500;

  /// Safety cap: 40 pages × 500 messages = 20,000 messages per run.
  static const int defaultMaxPages = 40;
}
