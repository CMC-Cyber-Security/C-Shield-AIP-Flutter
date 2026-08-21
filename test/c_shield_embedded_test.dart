import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:c_shield_aip/src/api/c_shield_embedded.dart';
import 'package:c_shield_aip/src/internal/platform/c_shield_embedded_platform_interface.dart';
import 'package:c_shield_aip/src/internal/platform/c_shield_embedded_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCShieldEmbeddedPlatform with MockPlatformInterfaceMixin implements CShieldEmbeddedPlatform {
  @override
  Future<String> aipSign({required String payload}) {
    // TODO: implement aipSign
    throw UnimplementedError();
  }

  @override
  Future<void> aipVerify({required String payload, required String signature}) {
    // TODO: implement aipVerify
    throw UnimplementedError();
  }

  @override
  Future<void> initialize() {
    // TODO: implement initialize
    throw UnimplementedError();
  }

  @override
  Future<bool> sslCheckServerTrusted({required String certDerBase64, required String host}) {
    // TODO: implement sslCheckServerTrusted
    throw UnimplementedError();
  }

  @override
  Future<void> sslConfigure({required List<String> pins, required String hostname}) {
    // TODO: implement sslConfigure
    throw UnimplementedError();
  }

  @override
  Future<Map<Object?, Object?>> sslHttpRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    Uint8List? body,
    int? connectTimeoutMs,
    int? receiveTimeoutMs,
    bool followRedirects = true,
  }) {
    // TODO: implement sslHttpRequest
    throw UnimplementedError();
  }

  @override
  Future<bool> sslIsConfigured() {
    // TODO: implement sslIsConfigured
    throw UnimplementedError();
  }

  @override
  Future<void> sslUpdatePins({required List<String> pins, required String hostname}) {
    // TODO: implement sslUpdatePins
    throw UnimplementedError();
  }
}

void main() {
  final CShieldEmbeddedPlatform initialPlatform = CShieldEmbeddedPlatform.instance;

  test('$MethodChannelCShieldEmbedded is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCShieldEmbedded>());
  });
}
