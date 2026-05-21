package com.example.serenity_app

import android.content.ComponentName
import android.content.Context
import android.provider.Settings

object SerenitySupervisionState {
    private const val PREFS = "serenity_supervision"
    private const val KEY_ACTIVE = "active"

    fun setActive(context: Context, active: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ACTIVE, active)
            .apply()
    }

    fun isActive(context: Context): Boolean {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ACTIVE, false)
    }

    fun isAccessibilityEnabled(context: Context): Boolean {
        val expected = ComponentName(context, SerenityAccessibilityService::class.java)
            .flattenToString()
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    fun isNotificationListenerEnabled(context: Context): Boolean {
        val expected = ComponentName(context, SerenityNotificationListenerService::class.java)
            .flattenToString()
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }
}