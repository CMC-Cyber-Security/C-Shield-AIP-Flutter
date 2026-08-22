import Flutter
import UIKit
import CShieldEmbedded

/// Mirrors CShieldEmbeddedPlugin.kt (android) — keep both in sync.
public class CShieldEmbeddedPlugin: NSObject, FlutterPlugin {

    private let sslBridge = SslBridge()
    private let aipBridge = AipBridge()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "c_shield_embedded", binaryMessenger: registrar.messenger())
        let instance = CShieldEmbeddedPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "sdk.initialize":
            // TODO: confirm the exact init signature once the CShieldEmbedded.xcframework
            // header is available — mirrors CShieldSDK.initialize(context) on android, which
            // takes no RASP reaction/listener params since this build has no RASP.
            CShield.initialize()
            result(nil)
        case let m where m.hasPrefix("ssl."):
            sslBridge.handle(call: call, result: result)
        case let m where m.hasPrefix("aip."):
            aipBridge.handle(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
