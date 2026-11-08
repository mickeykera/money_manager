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
    DateTime? asOf,
  }) async {
    final db = await _dbHelper.database;
    final nowMs = (asOf ?? DateTime.now()).millisecondsSinceEpoch;
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

  /// Marks any still-active bundle of the same provider/category as superseded
  /// when a newer package is activated. A package whose expiry has just passed
  /// may still be stored as active, so the date is not used to exclude it.
  Future<void> expireActiveBundles({
    required String provider,
    required String category,
    String? exceptId,
  }) async {
    final db = await _dbHelper.database;
    final where = StringBuffer('provider = ? AND category = ? AND status = ?');
    final args = <Object?>[provider, category, 'active'];
    if (exceptId != null) {
      where.write(' AND id != ?');
      args.add(exceptId);
    }
    await db.update(
      'telecom_bundles',
      {'status': 'expired'},
      where: where.toString(),
      whereArgs: args,
    );
  }

  /// Marks bundles whose expiry date has passed as expired.
  Future<void> expireOutdatedBundles() async {
    final db = await _dbHelper.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'telecom_bundles',
      {'status': 'expired'},
      where: 'status = ? AND expiry_time IS NOT NULL AND expiry_time <= ?',
      whereArgs: ['active', nowMs],
    );
  }

  /// Removes every tracked bundle/observation. Used before a completed full SMS
  /// rescan so bundles are rebuilt only from messages inside the scan window.
  Future<void> clearAllBundles() async {
    final db = await _dbHelper.database;
    await db.delete('telecom_observations');
    await db.delete('telecom_bundles');
  }

  /// Refreshes "last confirmed" for a plan without recording an allowance
  /// observation. Used for unlimited packages, which have no numeric balance.
  Future<void> touchBundle(
    String bundleId, {
    DateTime? timestamp,
    String? sourceMessage,
  }) async {
    final db = await _dbHelper.database;
    final time = timestamp ?? DateTime.now();
    final values = <String, Object?>{
      'last_confirmed_time': time.millisecondsSinceEpoch,
      'status': 'active',
    };
    if (sourceMessage != null) values['source_message'] = sourceMessage;
    await db.update(
      'telecom_bundles',
      values,
      where: 'id = ?',
      whereArgs: [bundleId],
    );
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
    } else {
      // First observation: compare against parent bundle's original allowance
      final bundle = await getBundleById(bundleId);
      if (bundle != null && bundle.unit == unit) {
        if (remainingAllowance < bundle.originalAllowance) {
          estimatedUsage = double.parse((bundle.originalAllowance - remainingAllowance).toStringAsFixed(3));
        } else {
          estimatedUsage = null;
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

    // Update remaining allowance on parent bundle. Unlimited plans have no
    // numeric allowance, so a zero value must not mark them exhausted.
    final parent = await getBundleById(bundleId);
    final isUnlimited = parent?.isUnlimited ?? false;
    await db.update(
      'telecom_bundles',
      {
        'remaining_allowance': remainingAllowance,
        'last_confirmed_time': time.millisecondsSinceEpoch,
        'status': (!isUnlimited && remainingAllowance <= 0.001)
            ? 'exhausted'
            : 'active',
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

      if (isData && !b.isUnlimited) {
        double inGb = b.unit == 'MB' ? (b.remainingAllowance / 1024.0) : b.remainingAllowance;
        if (isEthio) {
          ethioDataGb += inGb;
        } else {
          safaricomDataGb += inGb;
        }
      }

      if (!b.isUnlimited &&
          (b.category == AppConstants.bundleCategoryVoice || b.unit == 'minutes')) {
        voiceMinutes += b.remainingAllowance.toInt();
      }

      if (!b.isUnlimited &&
          (b.category == AppConstants.bundleCategorySms || b.unit == 'SMS')) {
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
