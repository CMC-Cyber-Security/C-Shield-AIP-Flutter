import '../internal/platform/c_shield_embedded_platform_interface.dart';

class CShieldEmbedded {
  CShieldEmbedded._();

  /// Loads the native library and starts the SDK. Call once, as early as
  /// possible in `main()`.
  static Future<void> initialize() async {
    await CShieldEmbeddedPlatform.instance.initialize();
  }
}
