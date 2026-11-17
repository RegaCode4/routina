package com.example.routina

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

internal class BackupImport(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null

    @Suppress("DEPRECATION")
    fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("unavailable", null, null)
            return
        }
        pending = result
        try {
            activity.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                },
                requestCode,
            )
        } catch (_: Exception) {
            pending = null
            result.error("unavailable", null, null)
        }
    }

    fun onResult(code: Int, resultCode: Int, intent: Intent?) {
        if (code != requestCode) return
        val result = pending ?: return
        val uri = intent?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            result.success(null)
            return
        }
        // A provider can omit or misreport its size. Bound the stream as well.
        Thread {
            try {
                val resolver = activity.contentResolver
                var name = "backup.routina"
                resolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameColumn >= 0 && !cursor.isNull(nameColumn)) name = cursor.getString(nameColumn)
                        val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeColumn >= 0 && !cursor.isNull(sizeColumn) &&
                            cursor.getLong(sizeColumn) > maxBytes
                        ) throw Oversized()
                    }
                }
                val bytes = resolver.openInputStream(uri)?.use { source ->
                    val buffer = ByteArray(64 * 1024)
                    val output = ByteArrayOutputStream()
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        if (count > maxBytes - output.size()) throw Oversized()
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                } ?: error("Unable to open backup")
                complete { result.success(mapOf("name" to name, "bytes" to bytes)) }
            } catch (_: Oversized) {
                complete { result.error("tooLarge", null, null) }
            } catch (_: Exception) {
                complete { result.error("unavailable", null, null) }
            }
        }.start()
    }

    private fun complete(deliver: () -> Unit) = activity.runOnUiThread {
        pending = null
        deliver()
    }

    private class Oversized : Exception()

    private companion object {
        const val requestCode = 711
        const val maxBytes = 32 * 1024 * 1024
    }
}
