import Flutter
import CShieldEmbedded

/// Mirrors ApBridge.kt (android) — keep both in sync.
final class ApBridge {

    // Only the cryptographic sign/verify are exposed to Flutter. Body
    // normalization, payload construction, hashing and the response
    // timestamp-window check are all done in Dart (APNormalizer / CShieldAP),
    // so no fabricated URLRequest/URL is needed here.
    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "ap.sign":   sign(args: args, result: result)
        case "ap.verify": verify(args: args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Sign / verify

    private func sign(args: [String: Any], result: @escaping FlutterResult) {
        guard let payload = args["payload"] as? String else { result(invalidArg()); return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let signature = try CShieldAIP.sign(payload)
                DispatchQueue.main.async { result(signature) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: CShieldErrorCode.apSigningFailed,
                                         message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func verify(args: [String: Any], result: @escaping FlutterResult) {
        guard let payload   = args["payload"] as? String,
              let signature = args["signature"] as? String else { result(invalidArg()); return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let valid = try CShieldAIP.verifySign(payload, signature: signature)
                DispatchQueue.main.async {
                    if valid {
                        result(nil)
                    } else {
                        result(FlutterError(code: CShieldErrorCode.apInvalidSignature,
                                             message: "Signature verification failed", details: nil))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: CShieldErrorCode.nativeError,
                                         message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Helpers

    private func invalidArg() -> FlutterError {
        FlutterError(code: CShieldErrorCode.invalidArgument, message: "Missing or invalid arguments", details: nil)
    }
}
