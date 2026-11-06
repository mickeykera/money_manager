package com.ledgerleaf.ledgerleaf

import android.Manifest
import android.content.pm.PackageManager
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.ledgerleaf/automation"
    private val smsPermissionRequestCode = 4211
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSmsPermission" -> result.success(hasSmsPermission())

                    "requestSmsPermission" -> requestSmsPermission(result)

                    "readSmsInbox" -> {
                        if (!hasSmsPermission()) {
                            result.error(
                                "permission_denied",
                                "READ_SMS permission has not been granted",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val since = call.argument<Number>("since")?.toLong() ?: 0L
                        val limit = call.argument<Number>("limit")?.toInt() ?: 500
                        try {
                            result.success(readSmsInbox(since, limit))
                        } catch (error: Exception) {
                            result.error("sms_read_failed", error.message, null)
                        }
                    }

                    "getIngestionQueuePath" ->
                        result.success(File(filesDir, "ingestion_events.json").absolutePath)

                    // iOS-only method; keep the channel symmetric so NativeBridge
                    // can call it defensively on any platform.
                    "getAppGroupDirectory" -> result.success(null)

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasSmsPermission(): Boolean {
        return checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_pending", "An SMS permission request is already open", null)
            return
        }

        pendingPermissionResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.READ_SMS,
                Manifest.permission.RECEIVE_SMS,
            ),
            smsPermissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsPermissionRequestCode) return

        val granted = hasSmsPermission()
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    private fun readSmsInbox(since: Long, limit: Int): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )

        val selectionParts = mutableListOf<String>()
        val selectionArgs = mutableListOf<String>()
        if (since > 0) {
            selectionParts.add("${Telephony.Sms.DATE} > ?")
            selectionArgs.add(since.toString())
        }
        selectionParts.add("${Telephony.Sms.BODY} IS NOT NULL")

        val cursor = contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selectionParts.joinToString(" AND "),
            selectionArgs.toTypedArray(),
            "${Telephony.Sms.DATE} DESC",
        )

        cursor?.use {
            val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)

            while (it.moveToNext() && messages.size < limit) {
                val body = if (bodyIndex >= 0) it.getString(bodyIndex) else null
                if (body.isNullOrBlank()) continue

                messages.add(
                    mapOf(
                        "sender" to if (addressIndex >= 0) it.getString(addressIndex) else null,
                        "body" to body,
                        "date" to if (dateIndex >= 0) it.getLong(dateIndex) else 0L,
                    ),
                )
            }
        }

        return messages
    }
}
