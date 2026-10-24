import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../data/database/database_helper.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../domain/models/ingestion_log_model.dart';
import '../domain/models/transaction_model.dart';
import '../parser/models/parse_result.dart';
import '../parser/parser_engine.dart';

class IngestionResponse {
  final bool success;
  final bool isDuplicate;
  final bool isPendingReview;
  final String message;
  final TransactionModel? transaction;
  final ParseResult? parseResult;

  const IngestionResponse({
    required this.success,
    this.isDuplicate = false,
    this.isPendingReview = false,
    required this.message,
    this.transaction,
    this.parseResult,
  });
}

class IngestionService {
  final ParserEngine _parserEngine;
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;
  final SettingsRepository _settingsRepo;
  final DatabaseHelper _dbHelper;

  IngestionService({
    ParserEngine? parserEngine,
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
    SettingsRepository? settingsRepo,
    DatabaseHelper? dbHelper,
  })  : _parserEngine = parserEngine ?? ParserEngine(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository(),
        _dbHelper = dbHelper ?? DatabaseHelper();

  /// Primary pipeline for processing incoming SMS messages
  Future<IngestionResponse> processIncomingSms({
    required String rawMessage,
    String? sender,
    DateTime? messageTime,
  }) async {
    final timestamp = messageTime ?? DateTime.now();
    final parseResult = _parserEngine.parse(rawMessage, sender: sender);

    // Sanitize snippet for audit log (truncate and avoid sensitive strings)
    final sanitizedSnippet = _createSanitizedSnippet(rawMessage);

    // 1. Rejected OTP or Security Message
    if (parseResult.status == ParseStatus.rejectedOtp) {
      await _logIngestion(
        sender: sender,
        snippet: '[SECURITY PASSPHRASE / OTP DETECTED AND DROPPED]',
        status: 'rejected_otp',
        confidence: 0.0,
        error: parseResult.failureReason,
      );
      return IngestionResponse(
        success: false,
        message: 'Security passcode rejected and dropped.',
        parseResult: parseResult,
      );
    }

    // 2. Failed / Declined Transaction
    if (parseResult.status == ParseStatus.rejectedFailedTxn) {
      await _logIngestion(
        sender: sender,
        snippet: sanitizedSnippet,
        status: 'rejected_failed_txn',
        confidence: 0.0,
        error: parseResult.failureReason,
      );
      return IngestionResponse(
        success: false,
        message: 'Failed/declined transaction alert ignored.',
        parseResult: parseResult,
      );
    }

    // 3. Unrecognized or parse error
    if (parseResult.status == ParseStatus.rejectedNonFinancial ||
        parseResult.status == ParseStatus.error) {
      await _logIngestion(
        sender: sender,
        snippet: sanitizedSnippet,
        status: 'parse_error',
        confidence: 0.0,
        error: parseResult.failureReason ?? 'Unrecognized format',
      );
      return IngestionResponse(
        success: false,
        message: parseResult.failureReason ?? 'Unrecognized message format',
        parseResult: parseResult,
      );
    }

    // 4. Generate deduplication fingerprint
    final fingerprint = _generateFingerprint(
      sender: sender ?? parseResult.institution,
      amountSantims: parseResult.amountSantims,
      reference: parseResult.reference,
      timestamp: timestamp,
    );

    // 5. Check duplicate
    final isDup = await _transactionRepo.isDuplicate(
      fingerprint,
      reference: parseResult.reference,
      amountSantims: parseResult.amountSantims,
      timestamp: timestamp,
    );

    if (isDup) {
      await _logIngestion(
        sender: sender,
        snippet: sanitizedSnippet,
        status: 'duplicate',
        amount: parseResult.amountSantims,
        confidence: parseResult.confidenceScore,
        error: 'Duplicate message delivery detected',
      );
      return IngestionResponse(
        success: true,
        isDuplicate: true,
        message: 'Transaction already recorded (duplicate delivery)',
        parseResult: parseResult,
      );
    }

    // 6. Resolve Account ID
    final accountId = await _resolveAccountId(sender, parseResult.institution);

    // 7. Resolve Category ID
    final categoryId = await _resolveCategoryId(
      merchant: parseResult.merchant,
      type: parseResult.transactionType,
    );

    // 8. Privacy setting for original message
    final retainSmsSetting = await _settingsRepo.getSetting(AppConstants.keyRetainOriginalSms);
    final shouldRetainSms = retainSmsSetting != 'false';

    final isHighConfidence = parseResult.confidenceScore >= 0.85;
    const uuid = Uuid();

    final tx = TransactionModel(
      id: uuid.v4(),
      amountSantims: parseResult.amountSantims,
      currency: parseResult.currency,
      type: parseResult.transactionType,
      merchant: parseResult.merchant,
      timestamp: timestamp,
      categoryId: categoryId,
      accountId: accountId,
      source: AppConstants.sourceSms,
      importStatus: isHighConfidence
          ? AppConstants.statusPosted
          : AppConstants.statusPendingReview,
      sourceFingerprint: fingerprint,
      originalMessage: shouldRetainSms ? rawMessage : null,
      reference: parseResult.reference,
      isReviewed: isHighConfidence,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 9. Atomically persist transaction
    await _transactionRepo.insertTransaction(tx);

    // 10. Audit log
    await _logIngestion(
      sender: sender,
      snippet: sanitizedSnippet,
      status: isHighConfidence ? 'success' : 'pending_review',
      amount: parseResult.amountSantims,
      confidence: parseResult.confidenceScore,
    );

    return IngestionResponse(
      success: true,
      isPendingReview: !isHighConfidence,
      message: isHighConfidence
          ? 'Transaction recorded successfully: ${tx.money.format()}'
          : 'Transaction flagged for review due to low parser confidence',
      transaction: tx,
      parseResult: parseResult,
    );
  }

  String _generateFingerprint({
    required String sender,
    required int amountSantims,
    String? reference,
    required DateTime timestamp,
  }) {
    // Round timestamp to minute to absorb minor network transport delays
    final roundedMinute = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      timestamp.hour,
      timestamp.minute,
    ).millisecondsSinceEpoch;

    final raw = '$sender|$amountSantims|${reference ?? ""}|$roundedMinute';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  String _createSanitizedSnippet(String raw) {
    var snippet = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (snippet.length > 80) {
      snippet = '${snippet.substring(0, 80)}...';
    }
    return snippet;
  }

  Future<void> _logIngestion({
    String? sender,
    required String snippet,
    required String status,
    int? amount,
    double? confidence,
    String? error,
  }) async {
    try {
      final db = await _dbHelper.database;
      const uuid = Uuid();
      final log = IngestionLogModel(
        id: uuid.v4(),
        timestamp: DateTime.now(),
        sender: sender,
        rawMessageSnippet: snippet,
        status: status,
        parsedAmountSantims: amount,
        confidenceScore: confidence,
        errorMessage: error,
      );
      await db.insert('ingestion_logs', log.toMap());
    } catch (_) {
      // Non-fatal logging failure
    }
  }

  Future<String> _resolveAccountId(String? sender, String institution) async {
    final s = (sender ?? institution).toLowerCase();
    if (s.contains('telebirr') || s.contains('ቴሌብር')) {
      return 'acc_telebirr';
    }
    if (s.contains('abyssinia') || s.contains('boa') || s.contains('አቢሲኒያ')) {
      return 'acc_boa';
    }
    if (s.contains('cbe') || s.contains('ንግድ ባንክ')) {
      return 'acc_cbe';
    }
    // Default account
    final accounts = await _accountRepo.getAllAccounts();
    return accounts.isNotEmpty ? accounts.first.id : 'acc_cbe';
  }

  Future<String> _resolveCategoryId({required String merchant, required String type}) async {
    if (type == AppConstants.typeIncome) {
      return 'cat_income';
    }
    if (type == AppConstants.typeTransfer) {
      return 'cat_transfer';
    }

    final m = merchant.toLowerCase();
    if (m.contains('kaldi') ||
        m.contains('coffee') ||
        m.contains('restaurant') ||
        m.contains('burger') ||
        m.contains('cafe') ||
        m.contains('supermarket') ||
        m.contains('grocery') ||
        m.contains('fresh corner') ||
        m.contains('food') ||
        m.contains('meat') ||
        m.contains('bakery')) {
      return 'cat_food';
    }
    if (m.contains('ride') ||
        m.contains('ferej') ||
        m.contains('taxi') ||
        m.contains('fuel') ||
        m.contains('total') ||
        m.contains('oil') ||
        m.contains('transport')) {
      return 'cat_transport';
    }
    if (m.contains('electric') ||
        m.contains('water') ||
        m.contains('utility') ||
        m.contains('dstv') ||
        m.contains('internet')) {
      return 'cat_utilities';
    }
    if (m.contains('airtime') || m.contains('fee') || m.contains('service charge')) {
      return 'cat_fees';
    }
    if (m.contains('pharmacy') ||
        m.contains('hospital') ||
        m.contains('clinic') ||
        m.contains('dr.') ||
        m.contains('medical')) {
      return 'cat_health';
    }
    if (m.contains('school') || m.contains('university') || m.contains('college') || m.contains('tuition')) {
      return 'cat_education';
    }
    if (m.contains('cinema') || m.contains('movie') || m.contains('theatre') || m.contains('concert')) {
      return 'cat_entertainment';
    }
    if (m.contains('cash withdrawal') || m.contains('atm') || m.contains('withdrawn')) {
      return 'cat_transfer';
    }

    return 'cat_other';
  }
}
