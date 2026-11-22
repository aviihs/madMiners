package com.madminers.game

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Android drops Wi-Fi broadcast packets unless an app holds this lock.
    // Held only while the app is looking for a server on the local network.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mad_miners/lan").setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        val lock = multicastLock ?: (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                            .createMulticastLock("mad-miners-discovery")
                            .also { it.setReferenceCounted(false); multicastLock = it }
                        lock.acquire()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "release" -> {
                    multicastLock?.takeIf { it.isHeld }?.release()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        multicastLock?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }
}
