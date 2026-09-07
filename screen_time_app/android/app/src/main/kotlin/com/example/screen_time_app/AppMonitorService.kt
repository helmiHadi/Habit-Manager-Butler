package com.example.screen_time_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationCompat

class AppMonitorService : Service() {

    // ─────────────────────────────────────────────────────────────────────────
    // Companion object  —  SINGLE SOURCE OF TRUTH for the blocklist.
    //
    // WHY companion?  Android can kill and restart a START_STICKY service at
    // any time (battery optimiser, memory pressure, etc.).  If the blocklist
    // is stored only on the instance, the new instance starts with an empty
    // list until the next UPDATE_BLOCKED_APPS intent arrives.  Storing it in
    // the companion makes it survive the restart because the companion's
    // memory lives with the class-loader, not the service instance.
    //
    // MainActivity / MethodChannel writes here directly so the check loop
    // always reads fresh data without waiting for an intent round-trip.
    // ─────────────────────────────────────────────────────────────────────────
    companion object {
        /** True while at least one service instance is alive. */
        @Volatile var isRunning = false

        /**
         * Authoritative list of package names that must be blocked.
         * Written by [updateBlocklist] from any thread; read by the
         * monitor loop on the main thread.
         *
         * Using @Volatile guarantees that a write on the MethodChannel
         * thread is immediately visible to the main-thread monitor loop
         * without additional synchronisation overhead.
         */
        @Volatile var blockedPackages: List<String> = emptyList()
            private set

        /** Roast messages shown on the overlay. */
        @Volatile var roastsList: List<String> = listOf("Get back to work.")
            private set

        /**
         * Called by [MainActivity] whenever Flutter sends a new blocklist.
         * Updates both companion fields atomically; the running monitor loop
         * will pick up the new list on its very next 1-second tick — no
         * restart needed.
         */
        fun updateBlocklist(packages: List<String>, roasts: List<String>? = null) {
            blockedPackages = packages
            if (!roasts.isNullOrEmpty()) roastsList = roasts
            android.util.Log.d(
                "AppMonitorService",
                "✅ Blocklist updated: ${packages.size} packages → $packages"
            )
        }
    }

    // ── Instance fields ───────────────────────────────────────────────────────
    private val CHANNEL_ID = "AppMonitorServiceChannel"
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isOverlayShowing = false

    /** The package that was in the foreground on the PREVIOUS tick.
     *  Used so we only act on a state-change, not on every tick. */
    private var lastForegroundApp = ""

    // ── Monitor loop ──────────────────────────────────────────────────────────

    private val monitorRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, 1_000) // 1-second tick
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        android.util.Log.d("AppMonitorService", "Service created. Current blocklist: ${blockedPackages.size} packages.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "UPDATE_BLOCKED_APPS" -> {
                // Hot-path: called by MainActivity.updateBlockedApps channel handler.
                val packages = intent.getStringArrayListExtra("BLOCKED_PACKAGES")
                val roasts   = intent.getStringArrayListExtra("ROASTS")
                if (packages != null) {
                    updateBlocklist(packages, roasts)
                    // Force an immediate check so blocking takes effect without
                    // waiting for the next 1-second tick.
                    checkForegroundApp()
                }
                return START_STICKY
            }

            else -> {
                // Cold-start path: service was started fresh by startService().
                val packages = intent?.getStringArrayListExtra("BLOCKED_PACKAGES")
                val roasts   = intent?.getStringArrayListExtra("ROASTS")
                // Only overwrite the companion if the intent actually carries data.
                // If Android restarts the service via START_STICKY with a null
                // intent, we want to KEEP the companion's existing list.
                if (packages != null) {
                    updateBlocklist(packages, roasts)
                }

                val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setContentTitle("Butler")
                    .setContentText("Monitoring app usage")
                    .setSmallIcon(android.R.drawable.ic_secure)
                    .build()

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        1, notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(1, notification)
                }

                // Start (or re-start) the monitor loop.
                handler.removeCallbacks(monitorRunnable)
                handler.post(monitorRunnable)

                android.util.Log.d(
                    "AppMonitorService",
                    "Service started. Blocking ${blockedPackages.size} packages: $blockedPackages"
                )
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(monitorRunnable)
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Foreground-app check ──────────────────────────────────────────────────

    /**
     * Reads the most-recently-foregrounded package from UsageEvents and
     * compares it against the companion's [blockedPackages] list.
     *
     * Key correctness property: we ALWAYS read [blockedPackages] from the
     * companion, never from a stale instance variable.  This means an
     * UPDATE_BLOCKED_APPS intent received 1 ms ago is already reflected here.
     */
    private fun checkForegroundApp() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now    = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(now - 10_000, now)
        val event  = UsageEvents.Event()
        var currentForegroundApp = ""

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                currentForegroundApp = event.packageName
            }
        }

        if (currentForegroundApp.isEmpty()) return // No foreground change detected

        // Read authoritative list from companion — always fresh, never stale.
        val currentBlocklist = blockedPackages

        if (currentBlocklist.contains(currentForegroundApp)) {
            // The app that came to the foreground is on the blocklist.
            if (!isOverlayShowing || lastForegroundApp != currentForegroundApp) {
                android.util.Log.d(
                    "AppMonitorService",
                    "🚫 Blocking $currentForegroundApp (blocklist: $currentBlocklist)"
                )
                showOverlay()
            }
        } else if (currentForegroundApp != packageName) {
            // An allowed app came to the foreground — dismiss the overlay.
            removeOverlay()
        }

        lastForegroundApp = currentForegroundApp
    }

    // ── Overlay ───────────────────────────────────────────────────────────────

    private fun showOverlay() {
        if (isOverlayShowing) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity     = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F2000000"))
        }

        val titleText = TextView(this).apply {
            text      = "Blocked by Butler"
            textSize  = 32f
            setTextColor(Color.WHITE)
            setTypeface(null, android.graphics.Typeface.BOLD)
            gravity   = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }

        val subtitleText = TextView(this).apply {
            // Always picks from the COMPANION's roastsList — so a new roast
            // list delivered via UPDATE_BLOCKED_APPS is shown immediately.
            text          = if (roastsList.isNotEmpty()) roastsList.random()
                            else "Nice try. Get back to work."
            textSize      = 18f
            setTextColor(Color.LTGRAY)
            gravity       = Gravity.CENTER
            setPadding(32, 0, 32, 64)
            textAlignment = View.TEXT_ALIGNMENT_CENTER
        }

        val buttonDrawable = android.graphics.drawable.GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadius = 50f
        }

        val homeButton = android.widget.Button(this).apply {
            text     = "Back to Work"
            textSize = 16f
            setTextColor(Color.BLACK)
            background = buttonDrawable
            setPadding(64, 32, 64, 32)
            isAllCaps = false
            setTypeface(null, android.graphics.Typeface.BOLD)
            setOnClickListener {
                removeOverlay()
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            }
        }

        layout.addView(titleText)
        layout.addView(subtitleText)
        layout.addView(homeButton)

        overlayView = layout
        windowManager?.addView(overlayView, params)
        isOverlayShowing = true
    }

    private fun removeOverlay() {
        if (!isOverlayShowing) return
        overlayView?.let { windowManager?.removeView(it) }
        overlayView      = null
        isOverlayShowing = false
    }

    // ── Notification channel ──────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "App Monitor Service Channel",
                NotificationManager.IMPORTANCE_LOW  // LOW = no sound, no heads-up
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
