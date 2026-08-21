import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:c_shield_aip/src/internal/platform/c_shield_aip_platform_interface.dart';
import 'package:c_shield_aip/src/internal/platform/c_shield_aip_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCShieldAipPlatform with MockPlatformInterfaceMixin implements CShieldAipPlatform {
  @override
  Future<String> apSign({required String payload}) {
    // TODO: implement apSign
    throw UnimplementedError();
  }

  @override
  Future<void> apVerify({required String payload, required String signature}) {
    // TODO: implement apVerify
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
  final CShieldAipPlatform initialPlatform = CShieldAipPlatform.instance;

  test('$MethodChannelCShieldAip is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCShieldAip>());
  });
}
