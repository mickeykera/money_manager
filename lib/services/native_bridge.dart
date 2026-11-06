import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'android_sms_service.dart';
import 'app_state.dart';

class NativeBridge with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel(
    'com.ledgerleaf/automation',
  );
  final AppState _appState;
  bool _isDraining = false;

  NativeBridge(this._appState) {
    WidgetsBinding.instance.addObserver(this);
    // Listen for direct method calls from iOS if app is open
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  Future<void> _handleResume() async {
    // App became active: drain background events first, then pull any SMS that
    // arrived while the app was closed on Android.
    await drainNativeQueue();
    if (AndroidSmsService.isSupported) {
      await AndroidSmsService.instance.importRecentMessages(_appState);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onSmsIngested') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null) {
        final text = args['text'] as String?;
        final sender = args['sender'] as String?;
        if (text != null && text.isNotEmpty) {
          await _appState.ingestSms(text, sender: sender);
        }
      }
    }
  }

  /// Drains background events stored in the shared App Group queue file
  Future<int> drainNativeQueue() async {
    if (_isDraining) return 0;
    _isDraining = true;

    try {
      final queueFile = await _getQueueFile();
      if (queueFile == null || !await queueFile.exists()) {
        _isDraining = false;
        return 0;
      }

      final content = await queueFile.readAsString();
      if (content.trim().isEmpty) {
        _isDraining = false;
        return 0;
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is! List || decoded.isEmpty) {
        _isDraining = false;
        return 0;
      }

      int processedCount = 0;
      for (final item in decoded) {
        if (item is Map) {
          final text = item['rawText'] as String?;
          final sender = item['sender'] as String?;
          final timestampStr = item['timestamp'] as String?;

          DateTime? time;
          if (timestampStr != null) {
            time = DateTime.tryParse(timestampStr);
          }

          if (text != null && text.isNotEmpty) {
            await _appState.ingestSms(
              text,
              sender: sender,
              messageTime: time,
              reload: false,
            );
            processedCount++;
          }
        }
      }

      if (processedCount > 0) {
        await _appState.reloadAll();
      }

      // Truncate or remove drained file atomically
      await queueFile.delete();
      _isDraining = false;
      return processedCount;
    } catch (_) {
      _isDraining = false;
      return 0;
    }
  }

  Future<File?> _getQueueFile() async {
    try {
      // Android's manifest SMS receiver writes to the app's private files
      // directory; ask the native side for the exact path so both sides agree.
      if (Platform.isAndroid) {
        try {
          final androidPath = await _channel.invokeMethod<String>(
            'getIngestionQueuePath',
          );
          if (androidPath != null && androidPath.isNotEmpty) {
            return File(androidPath);
          }
        } catch (_) {}
      }

      // First attempt to get App Group container path via MethodChannel if running on iOS
      String? groupPath;
      if (Platform.isIOS) {
        try {
          groupPath = await _channel.invokeMethod<String>(
            'getAppGroupDirectory',
          );
        } catch (_) {}
      }

      if (groupPath != null && groupPath.isNotEmpty) {
        return File(p.join(groupPath, 'ingestion_events.json'));
      }

      // Fallback to Application Documents directory
      final docs = await getApplicationDocumentsDirectory();
      return File(p.join(docs.path, 'ingestion_events.json'));
    } catch (_) {
      return null;
    }
  }
}
