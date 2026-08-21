import Foundation

/// Mirrors CShieldErrorCode.kt (android) — keep both in sync.
enum CShieldErrorCode {
    static let apInvalidSignature  = "ap_invalid_signature"
    static let apSigningFailed     = "ap_signing_failed"
    static let sslNotConfigured    = "ssl_not_configured"
    static let sslPinMismatch      = "ssl_pin_mismatch"
    static let invalidArgument     = "invalid_argument"
    static let nativeError         = "native_error"
}
