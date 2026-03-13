package com.mobde3.player

import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.etqan.player/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // منع أخذ لقطات شاشة أو تسجيل الشاشة
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeveloperModeEnabled" -> {
                    val devMode = Settings.Global.getInt(
                        contentResolver,
                        Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0
                    ) != 0
                    result.success(devMode)
                }
                "isDebuggerAttached" -> {
                    val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
                    val isDebuggerConnected = android.os.Debug.isDebuggerConnected()
                    result.success(isDebuggable || isDebuggerConnected)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

