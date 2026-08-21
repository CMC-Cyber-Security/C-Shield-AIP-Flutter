import '../internal/platform/c_shield_aip_platform_interface.dart';

/// C-Shield AIP (API Integrity Protection) — provides two protection
/// solutions: API Protection ([CShieldAP] / [CShieldInterceptor] /
/// [CShieldDioInterceptor]) and SSL Pinning ([CShieldSSL]).
class CShieldAIP {
  CShieldAIP._();

  /// Loads the native library and starts the SDK. Call once, as early as
  /// possible in `main()`.
  static Future<void> initialize() async {
    await CShieldAipPlatform.instance.initialize();
  }
}
