package com.cmc.c_shield_aip.c_shield_aip

import android.content.Context
import com.cmc.c_shield_aip.c_shield_aip.bridges.ApBridge
import com.cmc.c_shield_aip.c_shield_aip.bridges.SslBridge
import com.cmc.cshield_embedded.CShieldSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** CShieldAipPlugin */
class CShieldAipPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    private lateinit var context: Context

    private lateinit var sslBridge: SslBridge
    private lateinit var apBridge: ApBridge

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "c_shield_aip")

        sslBridge = SslBridge()
        apBridge = ApBridge(context)

        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when {
            call.method == "sdk.initialize" -> {
                CShieldSDK.initialize(context)
                result.success(null)
            }
            call.method.startsWith("ssl.") -> sslBridge.handle(call, result)
            call.method.startsWith("ap.") -> apBridge.handle(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
