package com.cmc.c_shield_embedded.c_shield_embedded

import android.content.Context
import com.cmc.c_shield_embedded.c_shield_embedded.bridges.AipBridge
import com.cmc.c_shield_embedded.c_shield_embedded.bridges.SslBridge
import com.cmc.cshield_embedded.CShieldSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** CShieldEmbeddedPlugin */
class CShieldEmbeddedPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    private lateinit var context: Context

    private lateinit var sslBridge: SslBridge
    private lateinit var aipBridge: AipBridge

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "c_shield_embedded")

        sslBridge = SslBridge()
        aipBridge = AipBridge(context)

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
            call.method.startsWith("aip.") -> aipBridge.handle(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
