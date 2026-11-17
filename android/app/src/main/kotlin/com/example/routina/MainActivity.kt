package com.example.routina

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val backupImport = BackupImport(this)
    private var firstReminderSync = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "routina/device_clock")
            .setMethodCallHandler { call, result ->
                if (call.method == "timerSample") {
                    val bootCount = Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1)
                    result.success(if (bootCount < 0) null else mapOf(
                        "bootCount" to bootCount,
                        "uptimeUs" to SystemClock.elapsedRealtimeNanos() / 1000L,
                    ))
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "routina/backup_storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") backupImport.pick(result) else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "routina/device_time_zone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "identifier" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "routina/notifications")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "permission" -> result.success(LocalReminders.permission(this))
                        "request" -> {
                            if (Build.VERSION.SDK_INT >= 33 &&
                                LocalReminders.permission(this) == "notDetermined" && permissionResult == null
                            ) {
                                permissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 710)
                            } else {
                                result.success(null)
                            }
                        }
                        "settings" -> {
                            val intent = if (Build.VERSION.SDK_INT >= 26) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                        "sync" -> {
                            LocalReminders.synchronize(this, call.arguments as Map<*, *>, firstReminderSync)
                            firstReminderSync = false
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    if (permissionResult === result) permissionResult = null
                    result.error("notifications", error.message, null)
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 710) {
            if (grantResults.isNotEmpty()) LocalReminders.recordPermissionRequest(this)
            permissionResult?.success(null)
            permissionResult = null
        }
    }

    @Deprecated("Used to receive Storage Access Framework results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        backupImport.onResult(requestCode, resultCode, data)
    }
}
