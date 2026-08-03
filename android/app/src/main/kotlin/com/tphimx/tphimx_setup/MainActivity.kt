package com.tphimx.tphimx_setup

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.view.WindowManager
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.audiofx.Virtualizer
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import java.io.File
import java.io.FileWriter
import java.io.PrintWriter
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "online.dongmephim/platform"
    private var virtualizer: Virtualizer? = null
    private var equalizer: Equalizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Setup Native Crash Handler before anything else
        setupNativeCrashHandler()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
        try {
            (this as? androidx.activity.ComponentActivity)?.let {
                it.enableEdgeToEdge()
            }
        } catch (e: Throwable) {
            // Ignore if ComponentActivity is not available
        }
        super.onCreate(savedInstanceState)
    }

    private fun setupNativeCrashHandler() {
        val oldHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                val timestamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.getDefault()).format(Date())

                // Flutter's getApplicationDocumentsDirectory() typically maps to filesDir
                // We attempt to write to 'Logs' folder in internal storage
                val logDir = File(context.filesDir, "Logs")
                if (!logDir.exists()) {
                    logDir.mkdirs()
                }

                val logLine = "[$timestamp] [NATIVE CRASH] Thread: ${thread?.name}\n" +
                               "Exception: ${throwable.javaClass.name}: ${throwable.message}\n" +
                               "StackTrace:\n${Log.getStackTraceString(throwable)}\n" +
                               "--------------------------------------------------\n"

                // Write to both specific crash log and 'all' log to match TxaLogger
                val crashFile = File(logDir, "crash_$date.log")
                val allFile = File(logDir, "all_$date.log")

                FileWriter(crashFile, true).use { it.append(logLine) }
                FileWriter(allFile, true).use { it.append(logLine) }

            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to write native crash log", e)
            }

            // Pass the crash back to the original handler (so Android can still show the 'App has stopped' dialog)
            oldHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun initAudioEffects() {
        try {
            if (virtualizer == null) {
                virtualizer = Virtualizer(0, 0).apply {
                    enabled = false
                }
            }
            if (equalizer == null) {
                equalizer = Equalizer(0, 0).apply {
                    enabled = false
                }
            }
            if (loudnessEnhancer == null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    loudnessEnhancer = LoudnessEnhancer(0).apply {
                        enabled = false
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTV" -> {
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    val isTV = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                    result.success(isTV)
                }
                "getDeviceBrand" -> {
                    result.success(Build.BRAND ?: Build.MANUFACTURER ?: "")
                }
                "getBatteryInfo" -> {
                    try {
                        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            batteryManager.isCharging
                        } else {
                            false
                        }
                        val info = HashMap<String, Any>()
                        info["level"] = level
                        info["isCharging"] = isCharging
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", "Failed to get battery info: ${e.message}", null)
                    }
                }
                "enableSecureMode" -> {
                    try {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SECURE_ERROR", "Failed to enable secure mode: ${e.message}", null)
                    }
                }
                "disableSecureMode" -> {
                    try {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SECURE_ERROR", "Failed to disable secure mode: ${e.message}", null)
                    }
                }
                "canInstallUnknownApps" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "requestInstallUnknownAppsPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_PATH", "APK path is null", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file not found at path: $path", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                FileProvider.getUriForFile(context, "$packageName.fileprovider", file)
                            } else {
                                Uri.fromFile(file)
                            }
                            setDataAndType(uri, "application/vnd.android.package-archive")
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", "Failed to start installation: ${e.message}", null)
                    }
                }
                "set3DAudioEnabled" -> {
                    val enabledVal = call.argument<Boolean>("enabled") ?: false
                    try {
                        initAudioEffects()
                        virtualizer?.apply {
                            if (enabledVal) {
                                setStrength(1000.toShort())
                                enabled = true
                            } else {
                                enabled = false
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                "setAudioOptimizeEnabled" -> {
                    val enabledVal = call.argument<Boolean>("enabled") ?: false
                    try {
                        initAudioEffects()
                        equalizer?.apply {
                            if (enabledVal) {
                                if (numberOfBands > 0) {
                                    setBandLevel(0.toShort(), 500.toShort())
                                }
                                if (numberOfBands > 3) {
                                    setBandLevel(3.toShort(), 400.toShort())
                                }
                                enabled = true
                            } else {
                                enabled = false
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                "setAudioBoostLevel" -> {
                    val level = call.argument<Double>("level") ?: 1.0
                    try {
                        initAudioEffects()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                            loudnessEnhancer?.apply {
                                if (level > 1.0) {
                                    val dbBoost = (level - 1.0) * 10.0
                                    val targetGain = (dbBoost * 100).toInt()
                                    setTargetGain(targetGain)
                                    enabled = true
                                } else {
                                    enabled = false
                                }
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                "changeAppIcon" -> {
                    val iconName = call.argument<String>("iconName") ?: "default"
                    val aliasMap = mapOf(
                        "default" to "com.tphimx.tphimx_setup.MainActivityDefault",
                        "cyber" to "com.tphimx.tphimx_setup.MainActivityCyber",
                        "gold" to "com.tphimx.tphimx_setup.MainActivityGold",
                        "cyan" to "com.tphimx.tphimx_setup.MainActivityCyan",
                        "emerald" to "com.tphimx.tphimx_setup.MainActivityEmerald",
                        "ruby" to "com.tphimx.tphimx_setup.MainActivityRuby"
                    )
                    val targetAlias = aliasMap[iconName] ?: "com.tphimx.tphimx_setup.MainActivityDefault"
                    try {
                        val pm = packageManager
                        for ((_, aliasComponent) in aliasMap) {
                            val comp = android.content.ComponentName(packageName, aliasComponent)
                            val state = if (aliasComponent == targetAlias) {
                                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                            } else {
                                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                            }
                            pm.setComponentEnabledSetting(
                                comp,
                                state,
                                android.content.pm.PackageManager.DONT_KILL_APP
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ICON_ERROR", "Failed to change launcher icon: ${e.message}", null)
                    }
                }
                "enterPiP" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val aspectRatio = android.util.Rational(16, 9)
                            val params = android.app.PictureInPictureParams.Builder()
                                .setAspectRatio(aspectRatio)
                                .build()
                            val success = enterPictureInPictureMode(params)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", "Failed to enter PiP mode: ${e.message}", null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onPiPModeChanged", isInPictureInPictureMode)
        }
    }
}
