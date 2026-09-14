package com.serenityapp.parental

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

// ═══════════════════════════════════════════════════════════════════════════
// ❌ SE ELIMINÓ EL MÉTODO "getForegroundApp"
//
// Devolvía qué app estaba al frente usando ActivityManager.getRunningTasks().
// Se quitó por tres razones que se suman:
//
//   1. NUNCA se llamaba desde Dart. Era código muerto.
//
//   2. NI SIQUIERA FUNCIONABA. Desde Android 5 (2014) getRunningTasks() solo
//      devuelve las tareas de tu propia app, por motivos de privacidad. Lo
//      único que podía responder era "com.serenityapp.parental".
//
//   3. ES LA API QUE LOS ESCÁNERES ASOCIAN CON ESPIAR AL USUARIO. Play
//      Protect bloqueó la instalación de esta app por su combinación de
//      permisos; dejar dentro del APK código que consulta qué otras apps usa
//      la persona empuja en la misma dirección, y aquí no aportaba nada.
//
// Con él se fue también el import de android.app.ActivityManager y el de
// android.content.Context, que solo existían para esto.
//
// Si algún día hace falta saber qué app está al frente de verdad, la vía
// moderna es UsageStatsManager — que exige el permiso PACKAGE_USAGE_STATS,
// que el usuario debe conceder a mano en Ajustes, y que hay que justificar
// ante Google. No es un cambio de una línea: es una decisión de producto.
// ═══════════════════════════════════════════════════════════════════════════

class MainActivity : FlutterFragmentActivity() {

    private val KIOSK_CHANNEL = "com.serenityapp.parental/kiosk"
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
