class CShieldChannels {
  static const String methodChannel = 'c_shield_aip';

  static const String sdkInitialize = 'sdk.initialize';

  static const String sslConfigure = 'ssl.configure';
  static const String sslUpdatePins = 'ssl.updatePins';
  static const String sslIsConfigured = 'ssl.isConfigured';
  static const String sslCheckServerTrusted = 'ssl.checkServerTrusted';

  // Performs an HTTPS request entirely on the native side (OkHttp on Android,
  // URLSession on iOS) so that certificate pinning runs at the native TLS layer
  // with the FULL certificate chain — enabling intermediate/root pin matching
  // that pure-Dart networking cannot do (dart:io only exposes the leaf cert).
  static const String sslHttpRequest = 'ssl.httpRequest';

  // AP (API Protection) — only the cryptographic sign/verify cross to native.
  // Body normalization, payload construction and the timestamp-window check
  // are done in Dart (CShieldAP / APNormalizer).
  static const String apSign = 'ap.sign';
  static const String apVerify = 'ap.verify';
}
