package com.example.serenity_app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class SerenityAccessibilityService : AccessibilityService() {

    private val allowedPackages = setOf(
        "com.example.serenity_app",
        "com.android.systemui"
    )

    private var lastBringToFrontAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!SerenitySupervisionState.isActive(this)) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val currentPackage = event.packageName?.toString() ?: return
        if (currentPackage.isBlank()) return
        if (currentPackage in allowedPackages) return

        val now = SystemClock.elapsedRealtime()
        if (now - lastBringToFrontAt < 1200) return
        lastBringToFrontAt = now

        Log.d("SerenityAccessibility", "App detectada fuera de Serenity: $currentPackage")

        try {
            val myIntent = packageManager.getLaunchIntentForPackage(packageName)
            myIntent?.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            if (myIntent != null) {
                startActivity(myIntent)
            }
        } catch (e: Exception) {
            Log.e("SerenityAccessibility", "Error al traer Serenity al frente: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d("SerenityAccessibility", "Servicio interrumpido")
    }
}