import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/bundle_model.dart';
import '../database/database_helper.dart';

class BundleRepository {
  final DatabaseHelper _dbHelper;

  BundleRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<TelecomBundleModel>> getAllBundles() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'telecom_bundles',
      orderBy: 'last_confirmed_time DESC',
    );
    return rows.map((e) => TelecomBundleModel.fromMap(e)).toList();
  }

  Future<List<TelecomBundleModel>> getActiveBundles() async {
    final db = await _dbHelper.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'telecom_bundles',
      where: 'status = ? AND (expiry_time IS NULL OR expiry_time > ?)',
      whereArgs: ['active', nowMs],
      orderBy: 'last_confirmed_time DESC',
    );
    return rows.map((e) => TelecomBundleModel.fromMap(e)).toList();
  }

  Future<TelecomBundleModel?> getBundleById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('telecom_bundles', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TelecomBundleModel.fromMap(rows.first);
  }

  Future<TelecomBundleModel?> findActiveBundle({
    required String provider,
    required String category,
  }) async {
    final db = await _dbHelper.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'telecom_bundles',
      where: 'provider = ? AND category = ? AND status = ? AND (expiry_time IS NULL OR expiry_time > ?)',
      whereArgs: [provider, category, 'active', nowMs],
      orderBy: 'last_confirmed_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TelecomBundleModel.fromMap(rows.first);
  }

  Future<void> saveBundle(TelecomBundleModel bundle) async {
    final db = await _dbHelper.database;
    await db.insert(
      'telecom_bundles',
      bundle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Records an observation for a bundle and calculates estimated consumption
  Future<BundleObservationModel> recordObservation({
    required String bundleId,
    required double remainingAllowance,
    required String unit,
    required String sourceMessage,
    DateTime? timestamp,
  }) async {
    final db = await _dbHelper.database;
    final time = timestamp ?? DateTime.now();

    // Fetch previous latest observation for this bundle
    final prevRows = await db.query(
      'telecom_observations',
      where: 'bundle_id = ?',
      whereArgs: [bundleId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    double? estimatedUsage;
    if (prevRows.isNotEmpty) {
      final prevObs = BundleObservationModel.fromMap(prevRows.first);
      if (prevObs.unit == unit) {
        if (remainingAllowance < prevObs.remainingAllowance) {
          // Normal consumption between reports
          estimatedUsage = double.parse((prevObs.remainingAllowance - remainingAllowance).toStringAsFixed(3));
        } else if (remainingAllowance > prevObs.remainingAllowance) {
          // Package renewed or received bonus: do not record negative usage
          estimatedUsage = 0.0;
        }
      }
    }

    const uuid = Uuid();
    final obs = BundleObservationModel(
      id: uuid.v4(),
      bundleId: bundleId,
      timestamp: time,
      remainingAllowance: remainingAllowance,
      unit: unit,
      estimatedUsageSincePrevious: estimatedUsage,
      sourceMessage: sourceMessage,
    );

    await db.insert('telecom_observations', obs.toMap());

    // Update remaining allowance on parent bundle
    await db.update(
      'telecom_bundles',
      {
        'remaining_allowance': remainingAllowance,
        'last_confirmed_time': time.millisecondsSinceEpoch,
        'status': remainingAllowance <= 0.001 ? 'exhausted' : 'active',
      },
      where: 'id = ?',
      whereArgs: [bundleId],
    );

    return obs;
  }

  Future<List<BundleObservationModel>> getObservationsForBundle(String bundleId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'telecom_observations',
      where: 'bundle_id = ?',
      whereArgs: [bundleId],
      orderBy: 'timestamp DESC',
    );
    return rows.map((e) => BundleObservationModel.fromMap(e)).toList();
  }

  /// Computes summary of active bundles for Home and Bundles screens
  Future<TelecomSummary> getTelecomSummary() async {
    final active = await getActiveBundles();
    if (active.isEmpty) return TelecomSummary.empty;

    double ethioDataGb = 0.0;
    double safaricomDataGb = 0.0;
    int voiceMinutes = 0;
    int smsTotal = 0;
    DateTime? earliestExpiry;

    for (final b in active) {
      if (b.expiryTime != null) {
        if (earliestExpiry == null || b.expiryTime!.isBefore(earliestExpiry)) {
          earliestExpiry = b.expiryTime;
        }
      }

      final isSafaricom = b.provider.toLowerCase().contains('safaricom');
      final isEthio = !isSafaricom && (b.provider.toLowerCase().contains('ethio') || b.provider.contains('ኢትዮ'));
      final isData = b.category == AppConstants.bundleCategoryData ||
          b.category == AppConstants.bundleCategoryCombo ||
          b.category == AppConstants.bundleCategoryNightData ||
          b.category == AppConstants.bundleCategorySocial;

      if (isData) {
        double inGb = b.unit == 'MB' ? (b.remainingAllowance / 1024.0) : b.remainingAllowance;
        if (isEthio) {
          ethioDataGb += inGb;
        } else {
          safaricomDataGb += inGb;
        }
      }

      if (b.category == AppConstants.bundleCategoryVoice || b.unit == 'minutes') {
        voiceMinutes += b.remainingAllowance.toInt();
      }

      if (b.category == AppConstants.bundleCategorySms || b.unit == 'SMS') {
        smsTotal += b.remainingAllowance.toInt();
      }
    }

    return TelecomSummary(
      ethioDataRemainingGb: double.parse(ethioDataGb.toStringAsFixed(2)),
      safaricomDataRemainingGb: double.parse(safaricomDataGb.toStringAsFixed(2)),
      totalVoiceMinutesRemaining: voiceMinutes,
      totalSmsRemaining: smsTotal,
      nextKnownExpiry: earliestExpiry,
      activeBundles: active,
    );
  }
}
