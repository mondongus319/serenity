package com.example.serenity_app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val KIOSK_CHANNEL = "com.example.serenity_app/kiosk"
    private val TAG = "KioskMode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KIOSK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLockTask" -> {
                        try {
                            startLockTask()
                            hideSystemUI()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("LOCK_TASK_ERROR", e.message, null)
                        }
                    }

                    "stopLockTask" -> {
                        try {
                            stopLockTask()
                            showSystemUI()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("LOCK_TASK_ERROR", e.message, null)
                        }
                    }

                    "getForegroundApp" -> {
                        try {
                            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            @Suppress("DEPRECATION")
                            val tasks = am.getRunningTasks(1)
                            val pkg = tasks.firstOrNull()?.topActivity?.packageName ?: packageName
                            result.success(pkg)
                        } catch (e: Exception) {
                            result.success(packageName)
                        }
                    }

                    "bringToFront" -> {
                        try {
                            val intent = packageManager.getLaunchIntentForPackage(packageName)
                            intent?.let {
                                it.flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(it)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("BRING_TO_FRONT_ERROR", e.message, null)
                        }
                    }

                    "isPinningEnabled" -> {
                        try {
                            val lockToAppEnabled = Settings.System.getInt(
                                contentResolver,
                                "lock_to_app_enabled",
                                0
                            )
                            result.success(lockToAppEnabled == 1)
                        } catch (e: Exception) {
                            try {
                                val lockToAppEnabled2 = Settings.Secure.getInt(
                                    contentResolver,
                                    "lock_to_app_enabled",
                                    0
                                )
                                result.success(lockToAppEnabled2 == 1)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    }

                    "openPinningSettings" -> {
                        var opened = false

                        if (!opened) {
                            try {
                                val intent = Intent("com.android.settings.SCREEN_PINNING_SETTINGS")
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                opened = true
                                result.success(null)
                            } catch (_: Exception) {
                            }
                        }

                        if (!opened) {
                            try {
                                val intent = Intent(Settings.ACTION_SECURITY_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                opened = true
                                result.success(null)
                            } catch (_: Exception) {
                            }
                        }

                        if (!opened) {
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_SETTINGS)
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("SETTINGS_ERROR", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
        }
    }

    override fun onResume() {
        super.onResume()
        hideSystemUI()
    }

    private fun hideSystemUI() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.setDecorFitsSystemWindows(false)
                window.insetsController?.let { controller ->
                    controller.hide(
                        WindowInsets.Type.statusBars() or
                            WindowInsets.Type.navigationBars() or
                            WindowInsets.Type.systemBars()
                    )
                    controller.systemBarsBehavior =
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "hideSystemUI error: ${e.message}")
        }
    }

    private fun showSystemUI() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.setDecorFitsSystemWindows(true)
                window.insetsController?.show(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
                )
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            }
        } catch (e: Exception) {
            Log.e(TAG, "showSystemUI error: ${e.message}")
        }
    }
}