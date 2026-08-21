enum CShieldErrorCode {
  apMissingHeader('ap_missing_header'),
  apTimestampExpired('ap_timestamp_expired'),
  apInvalidSignature('ap_invalid_signature'),
  apSigningFailed('ap_signing_failed'),
  apDetectProxyCA('ap_proxy_ca'),
  sslNotConfigured('ssl_not_configured'),
  sslPinMismatch('ssl_pin_mismatch'),
  notInitialized('not_initialized'),
  invalidArgument('invalid_argument'),
  nativeError('native_error');

  const CShieldErrorCode(this.platformCode);

  /// The string code used on the native platform (Android/iOS) side.
  final String platformCode;

  static CShieldErrorCode fromPlatformCode(String code) => values.firstWhere((e) => e.platformCode == code, orElse: () => nativeError);
}

class CShieldException implements Exception {
  final CShieldErrorCode code;
  final String message;
  final Object? nativeCause;

  const CShieldException(this.code, this.message, [this.nativeCause]);

  @override
  String toString() => 'CShieldException(${code.name}): $message';
}
