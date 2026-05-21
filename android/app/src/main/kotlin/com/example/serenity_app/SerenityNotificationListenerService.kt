package com.example.serenity_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class SerenityNotificationListenerService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("SerenityNotifications", "Notification listener conectado")
        clearIfNeeded()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        if (!SerenitySupervisionState.isActive(this)) return
        if (sbn == null) return
        if (sbn.packageName == packageName) return
        if (sbn.packageName == "com.android.systemui") return
        if (sbn.key.isNullOrBlank()) return

        try {
            Log.d(
                "SerenityNotifications",
                "Cancelando notificación de: ${sbn.packageName}"
            )
            cancelNotification(sbn.key)
        } catch (e: Exception) {
            Log.e(
                "SerenityNotifications",
                "No se pudo cancelar notificación: ${e.message}"
            )
        }
    }

    private fun clearIfNeeded() {
        if (!SerenitySupervisionState.isActive(this)) return

        try {
            activeNotifications?.forEach { sbn ->
                if (sbn.packageName != packageName &&
                    sbn.packageName != "com.android.systemui" &&
                    !sbn.key.isNullOrBlank()
                ) {
                    cancelNotification(sbn.key)
                }
            }
        } catch (e: Exception) {
            Log.e(
                "SerenityNotifications",
                "clearIfNeeded error: ${e.message}"
            )
        }
    }
}