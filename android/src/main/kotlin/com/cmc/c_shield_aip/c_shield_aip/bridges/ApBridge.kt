package com.cmc.c_shield_aip.c_shield_aip.bridges

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.cmc.c_shield_aip.c_shield_aip.CShieldErrorCode
import com.cmc.cshield_embedded.aip.api.AIPCore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ApBridge(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())

    // Only the cryptographic sign/verify are exposed to Flutter. Body
    // normalization, payload construction, hashing and the response
    // timestamp-window check are all done in Dart (APNormalizer / CShieldAP),
    // so no fabricated okhttp Request/URL is needed here.
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ap.sign"   -> handleSign(call, result)
            "ap.verify" -> handleVerify(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleSign(call: MethodCall, result: MethodChannel.Result) {
        val payload = call.argument<String>("payload")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "payload required", null)

        Thread {
            try {
                val signature = AIPCore.sign(context, payload)
                mainHandler.post { result.success(signature) }
//            } catch (e: CShieldException) {
//                mainHandler.post { result.error(CShieldErrorCode.AIP_PROXY_CA, e.message, null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error(CShieldErrorCode.AP_SIGNING_FAILED, e.message, null) }
            }
        }.start()
    }

    private fun handleVerify(call: MethodCall, result: MethodChannel.Result) {
        val payload = call.argument<String>("payload")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "payload required", null)
        val signature = call.argument<String>("signature")
            ?: return result.error(CShieldErrorCode.INVALID_ARGUMENT, "signature required", null)

        Thread {
            try {
                val valid = AIPCore.verifySign(context, payload, signature)
                mainHandler.post {
                    if (valid) result.success(null)
                    else result.error(CShieldErrorCode.AP_INVALID_SIGNATURE, "Signature verification failed", null)
                }
//            } catch (e: CShieldException) {
//                mainHandler.post { result.error(CShieldErrorCode.AIP_PROXY_CA, e.message, null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error(CShieldErrorCode.NATIVE_ERROR, e.message, null) }
            }
        }.start()
    }

}
