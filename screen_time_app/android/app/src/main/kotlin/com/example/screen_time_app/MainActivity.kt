package com.example.screen_time_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.butler.app/blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(null)
                }
                "checkOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "startService" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    val roasts = call.argument<List<String>>("roasts") ?: emptyList()
                    startAppMonitorService(blockedApps, roasts)
                    result.success(null)
                }
                "stopService" -> {
                    stopAppMonitorService()
                    result.success(null)
                }
                "updateBlockedApps" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    val roasts      = call.argument<List<String>>("roasts")      // may be null

                    // ── FAST PATH: write directly into companion memory ───────
                    // No Intent, no binder IPC, no onStartCommand queue delay.
                    // The monitor loop reads blockedPackages from the companion
                    // on every 1-second tick, so enforcement is instant.
                    AppMonitorService.updateBlocklist(blockedApps, roasts)

                    if (!AppMonitorService.isRunning) {
                        // Service is dead — bring it up.  onStartCommand will
                        // see the companion already populated and skip overwriting.
                        startAppMonitorService(blockedApps, roasts ?: emptyList())
                    }
                    result.success(null)
                }
                "getDailyUsageStats" -> {
                    result.success(getDailyUsageStats())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getDailyUsageStats(): Map<String, Int> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
        val calendar = java.util.Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis

        val usageStatsList = usageStatsManager.queryUsageStats(android.app.usage.UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        val usageMap = mutableMapOf<String, Int>()

        if (usageStatsList != null) {
            for (usageStats in usageStatsList) {
                val timeInForeground = usageStats.totalTimeInForeground
                if (timeInForeground > 0) {
                    usageMap[usageStats.packageName] = (timeInForeground / 1000 / 60).toInt()
                }
            }
        }
        return usageMap
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatsPermission() {
        if (!hasUsageStatsPermission()) {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (!hasOverlayPermission()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        }
    }

    private fun startAppMonitorService(blockedApps: List<String>, roasts: List<String>) {
        // Pre-seed the companion so the list is available even if the OS
        // delays Intent delivery (e.g. during a START_STICKY restart).
        AppMonitorService.updateBlocklist(blockedApps, roasts)

        val intent = Intent(this, AppMonitorService::class.java)
        intent.putStringArrayListExtra("BLOCKED_PACKAGES", ArrayList(blockedApps))
        intent.putStringArrayListExtra("ROASTS", ArrayList(roasts))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAppMonitorService() {
        val intent = Intent(this, AppMonitorService::class.java)
        stopService(intent)
    }
}
