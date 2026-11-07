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
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel
        instance = this

        channel
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
                        val before = call.argument<Number>("before")?.toLong() ?: 0L
                        val beforeId = call.argument<Number>("beforeId")?.toLong() ?: 0L
                        val limit = call.argument<Number>("limit")?.toInt() ?: 500
                        try {
                            result.success(readSmsInbox(since, before, beforeId, limit))
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

    override fun onDestroy() {
        if (instance === this) instance = null
        methodChannel = null
        super.onDestroy()
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

    private fun readSmsInbox(
        since: Long,
        before: Long,
        beforeId: Long,
        limit: Int,
    ): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms._ID,
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
        // Upper bound used to page backwards through the inbox without skipping
        // older messages when a scan returns more than one page. The row id is
        // the tiebreaker so messages sharing a timestamp are never dropped.
        if (before > 0) {
            if (beforeId > 0) {
                selectionParts.add(
                    "(${Telephony.Sms.DATE} < ? OR " +
                        "(${Telephony.Sms.DATE} = ? AND ${Telephony.Sms._ID} < ?))",
                )
                selectionArgs.add(before.toString())
                selectionArgs.add(before.toString())
                selectionArgs.add(beforeId.toString())
            } else {
                selectionParts.add("${Telephony.Sms.DATE} < ?")
                selectionArgs.add(before.toString())
            }
        }
        selectionParts.add("${Telephony.Sms.BODY} IS NOT NULL")

        val cursor = contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selectionParts.joinToString(" AND "),
            selectionArgs.toTypedArray(),
            "${Telephony.Sms.DATE} DESC, ${Telephony.Sms._ID} DESC",
        )

        cursor?.use {
            val idIndex = it.getColumnIndex(Telephony.Sms._ID)
            val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)

            while (it.moveToNext() && messages.size < limit) {
                val body = if (bodyIndex >= 0) it.getString(bodyIndex) else null
                if (body.isNullOrBlank()) continue

                messages.add(
                    mapOf(
                        "id" to if (idIndex >= 0) it.getLong(idIndex) else 0L,
                        "sender" to if (addressIndex >= 0) it.getString(addressIndex) else null,
                        "body" to body,
                        "date" to if (dateIndex >= 0) it.getLong(dateIndex) else 0L,
                    ),
                )
            }
        }

        return messages
    }

    companion object {
        @Volatile
        private var instance: MainActivity? = null

        /**
         * Delivers an incoming SMS to the running Flutter engine so an open app
         * updates immediately. Returns true when the message was handed to a
         * live engine; the receiver still persists it to the queue as a fallback.
         */
        fun notifySmsIngested(sender: String?, body: String, timestampMillis: Long): Boolean {
            val activity = instance ?: return false
            val channel = activity.methodChannel ?: return false

            activity.runOnUiThread {
                channel.invokeMethod(
                    "onSmsIngested",
                    mapOf(
                        "text" to body,
                        "sender" to sender,
                        "timestamp" to timestampMillis,
                    ),
                )
            }
            return true
        }
    }
}
