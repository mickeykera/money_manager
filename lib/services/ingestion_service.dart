import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../data/database/database_helper.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/bundle_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../domain/models/bundle_model.dart';
import '../domain/models/ingestion_log_model.dart';
import '../domain/models/transaction_model.dart';
import '../parser/models/parse_result.dart';
import '../parser/parser_engine.dart';
import '../parser/telecom/telecom_parse_result.dart';
import '../parser/telecom/telecom_parser_engine.dart';

class IngestionResponse {
  final bool success;
  final bool isDuplicate;
  final bool isPendingReview;
  final bool isTelecomUpdate;
  final String message;
  final TransactionModel? transaction;
  final ParseResult? parseResult;
  final TelecomParseResult? telecomResult;

  const IngestionResponse({
    required this.success,
    this.isDuplicate = false,
    this.isPendingReview = false,
    this.isTelecomUpdate = false,
    required this.message,
    this.transaction,
    this.parseResult,
    this.telecomResult,
  });
}

class IngestionService {
  final ParserEngine _parserEngine;
  final TelecomParserEngine _telecomEngine;
  final TransactionRepository _transactionRepo;
  final BundleRepository _bundleRepo;
  final AccountRepository _accountRepo;
  final SettingsRepository _settingsRepo;
  final DatabaseHelper _dbHelper;

  IngestionService({
    ParserEngine? parserEngine,
    TelecomParserEngine? telecomEngine,
    TransactionRepository? transactionRepo,
    BundleRepository? bundleRepo,
    AccountRepository? accountRepo,
    SettingsRepository? settingsRepo,
    DatabaseHelper? dbHelper,
  })  : _parserEngine = parserEngine ?? ParserEngine(),
        _telecomEngine = telecomEngine ?? TelecomParserEngine(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _bundleRepo = bundleRepo ?? BundleRepository(),
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
    final cleanMessage = rawMessage.trim();
    final sanitizedSnippet = _createSanitizedSnippet(cleanMessage);

    // 1. Telecom Bundle Branch (Ethio telecom & Safaricom Ethiopia)
    if (_telecomEngine.canParse(cleanMessage, sender)) {
      final telecomResult = _telecomEngine.parse(cleanMessage, sender);
      if (telecomResult.isRecognized) {
        return _handleTelecomMessage(
          telecomResult: telecomResult,
          rawMessage: cleanMessage,
          sender: sender,
          timestamp: timestamp,
          sanitizedSnippet: sanitizedSnippet,
        );
      }
    }

    // 2. Standard Financial Transaction Parsing
    final parseResult = _parserEngine.parse(cleanMessage, sender: sender);

    // 2a. Rejected OTP or Security Message
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

    // 2b. Failed / Declined Transaction
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

    // 2c. Unrecognized or parse error
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

    // 2d. Generate deduplication fingerprint
    final fingerprint = _generateFingerprint(
      sender: sender ?? parseResult.institution,
      amountSantims: parseResult.amountSantims,
      reference: parseResult.reference,
      timestamp: timestamp,
    );

    // 2e. Check duplicate
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

    // 2f. Resolve Account ID
    final accountId = await _resolveAccountId(sender, parseResult.institution);

    // 2g. Resolve Category ID
    final categoryId = await _resolveCategoryId(
      merchant: parseResult.merchant,
      type: parseResult.transactionType,
    );

    // 2h. Privacy setting for original message
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

    // 2i. Atomically persist transaction
    await _transactionRepo.insertTransaction(tx);

    // 2j. Audit log
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

  Future<IngestionResponse> _handleTelecomMessage({
    required TelecomParseResult telecomResult,
    required String rawMessage,
    String? sender,
    required DateTime timestamp,
    required String sanitizedSnippet,
  }) async {
    const uuid = Uuid();
    TransactionModel? tx;

    // A. If message reports a purchase with an explicit monetary price:
    if (telecomResult.isPurchase &&
        telecomResult.purchasePriceSantims != null &&
        telecomResult.purchasePriceSantims! > 0) {
      final fingerprint = _generateFingerprint(
        sender: sender ?? telecomResult.provider,
        amountSantims: telecomResult.purchasePriceSantims!,
        reference: telecomResult.bundleName,
        timestamp: timestamp,
      );

      final isDup = await _transactionRepo.isDuplicate(
        fingerprint,
        reference: telecomResult.bundleName,
        amountSantims: telecomResult.purchasePriceSantims!,
        timestamp: timestamp,
      );

      if (!isDup) {
        final accountId = await _resolveAccountId(sender, telecomResult.provider);
        final retainSmsSetting = await _settingsRepo.getSetting(AppConstants.keyRetainOriginalSms);
        final shouldRetainSms = retainSmsSetting != 'false';

        tx = TransactionModel(
          id: uuid.v4(),
          amountSantims: telecomResult.purchasePriceSantims!,
          currency: AppConstants.defaultCurrency,
          type: AppConstants.typeExpense,
          merchant: '${telecomResult.provider}: ${telecomResult.bundleName}',
          timestamp: timestamp,
          categoryId: 'cat_utilities',
          accountId: accountId,
          source: AppConstants.sourceSms,
          importStatus: AppConstants.statusPosted,
          sourceFingerprint: fingerprint,
          originalMessage: shouldRetainSms ? rawMessage : null,
          reference: null,
          isReviewed: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _transactionRepo.insertTransaction(tx);
      }
    }

    // B. Save or Update the Telecom Bundle Model
    final existingBundle = await _bundleRepo.findActiveBundle(
      provider: telecomResult.provider,
      category: telecomResult.category,
    );

    String bundleId;
    if (telecomResult.isPurchase || existingBundle == null) {
      bundleId = uuid.v4();
      final newBundle = TelecomBundleModel(
        id: bundleId,
        provider: telecomResult.provider,
        bundleName: telecomResult.bundleName,
        category: telecomResult.category,
        originalAllowance: telecomResult.originalAllowance,
        remainingAllowance: telecomResult.remainingAllowance,
        unit: telecomResult.unit,
        activationTime: telecomResult.activationTime ?? timestamp,
        expiryTime: telecomResult.expiryTime,
        purchasePriceSantims: telecomResult.purchasePriceSantims,
        sourceFingerprint: rawMessage.hashCode.toString(),
        lastConfirmedTime: timestamp,
        confidenceScore: telecomResult.confidenceScore,
        status: 'active',
      );
      await _bundleRepo.saveBundle(newBundle);
    } else {
      bundleId = existingBundle.id;
    }

    // C. Record observation and calculate usage since previous report
    await _bundleRepo.recordObservation(
      bundleId: bundleId,
      remainingAllowance: telecomResult.remainingAllowance,
      unit: telecomResult.unit,
      sourceMessage: rawMessage,
      timestamp: timestamp,
    );

    // D. Log Ingestion
    await _logIngestion(
      sender: sender,
      snippet: sanitizedSnippet,
      status: telecomResult.isPurchase ? 'telecom_purchase' : 'telecom_balance_update',
      amount: telecomResult.purchasePriceSantims,
      confidence: telecomResult.confidenceScore,
    );

    return IngestionResponse(
      success: true,
      isTelecomUpdate: true,
      message: telecomResult.isPurchase
          ? 'Recorded bundle purchase: ${telecomResult.bundleName}'
          : 'Updated remaining allowance: ${telecomResult.remainingAllowance} ${telecomResult.unit}',
      transaction: tx,
      telecomResult: telecomResult,
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
    if (s.contains('mpesa') || s.contains('safaricom') || s.contains('700') || s.contains('ሳፋሪኮም')) {
      return 'acc_mpesa';
    }
    if (s.contains('telebirr') || s.contains('ቴሌብር') || s.contains('ethio telecom') || s.contains('994') || s.contains('127')) {
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
        m.contains('internet') ||
        m.contains('bundle') ||
        m.contains('telecom') ||
        m.contains('safaricom') ||
        m.contains('ethio telecom') ||
        m.contains('ፓኬጅ')) {
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
