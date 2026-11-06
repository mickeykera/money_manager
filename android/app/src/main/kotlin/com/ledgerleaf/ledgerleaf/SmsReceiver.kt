package com.ledgerleaf.ledgerleaf

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Captures incoming SMS while the app is in the background and appends it to the
 * same ingestion queue that NativeBridge drains when LedgerLeaf opens. The
 * queue lives in the app's private files directory.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val sender = messages.first().originatingAddress
        val timestamp = messages.first().timestampMillis
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }.trim()
        if (body.isEmpty()) return

        val queueFile = File(context.filesDir, "ingestion_events.json")

        synchronized(SmsReceiver::class.java) {
            val queue = readQueue(queueFile)

            val event = JSONObject()
                .put("rawText", body)
                .put("sender", sender ?: "")
                .put("timestamp", isoTimestamp(timestamp))
            queue.put(event)

            // Keep the queue bounded in case the app is not opened for a long time.
            val trimmed = JSONArray()
            val start = if (queue.length() > MAX_QUEUE_SIZE) queue.length() - MAX_QUEUE_SIZE else 0
            for (index in start until queue.length()) {
                trimmed.put(queue.get(index))
            }

            queueFile.writeText(trimmed.toString())
        }
    }

    private fun readQueue(file: File): JSONArray {
        if (!file.exists()) return JSONArray()
        return try {
            JSONArray(file.readText())
        } catch (_: Exception) {
            // A corrupt queue must never block new messages.
            JSONArray()
        }
    }

    private fun isoTimestamp(epochMillis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date(epochMillis))
    }

    companion object {
        private const val MAX_QUEUE_SIZE = 500
    }
}
