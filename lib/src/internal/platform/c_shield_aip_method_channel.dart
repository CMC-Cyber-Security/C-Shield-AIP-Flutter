import 'package:c_shield_aip/src/sdk/exceptions/c_shield_exception.dart';
import 'package:c_shield_aip/src/internal/channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'c_shield_aip_platform_interface.dart';

/// An implementation of [CShieldAipPlatform] that uses method channels.
class MethodChannelCShieldAip extends CShieldAipPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('c_shield_aip');

  // Native call
  Future<T> _invoke<T>(String method, [dynamic args]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, args) as T;
    } on PlatformException catch (e) {
      throw CShieldException(CShieldErrorCode.fromPlatformCode(e.code), e.message ?? e.code, e);
    }
  }

  // ── Initialization ──────────────────────────────────────────────────────────────────

  @override
  Future<void> initialize() => _invoke(CShieldChannels.sdkInitialize);

  // ── SSL ──────────────────────────────────────────────────────────────────

  @override
  Future<void> sslConfigure({required List<String> pins, required String hostname}) => _invoke(CShieldChannels.sslConfigure, {'pins': pins, 'hostname': hostname});

  @override
  Future<void> sslUpdatePins({required List<String> pins, required String hostname}) => _invoke(CShieldChannels.sslUpdatePins, {'pins': pins, 'hostname': hostname});

  @override
  Future<bool> sslIsConfigured() => _invoke<bool>(CShieldChannels.sslIsConfigured);

  @override
  Future<bool> sslCheckServerTrusted({required String certDerBase64, required String host}) => _invoke<bool>(CShieldChannels.sslCheckServerTrusted, {'certDer': certDerBase64, 'host': host});

  @override
  Future<Map<Object?, Object?>> sslHttpRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    Uint8List? body,
    int? connectTimeoutMs,
    int? receiveTimeoutMs,
    bool followRedirects = true,
  }) => _invoke<Map<Object?, Object?>>(CShieldChannels.sslHttpRequest, {
    'method': method,
    'url': url,
    'headers': headers,
    'body': body,
    'connectTimeoutMs': connectTimeoutMs,
    'receiveTimeoutMs': receiveTimeoutMs,
    'followRedirects': followRedirects,
  });

  // ── AP (API Protection) ─────────────────────────────────────────────────
  // Only sign/verify cross to native; normalization and payload construction
  // are done in Dart (see CShieldAP / APNormalizer).

  @override
  Future<String> apSign({required String payload}) => _invoke<String>(CShieldChannels.apSign, {'payload': payload});

  @override
  Future<void> apVerify({required String payload, required String signature}) => _invoke(CShieldChannels.apVerify, {'payload': payload, 'signature': signature});
}
