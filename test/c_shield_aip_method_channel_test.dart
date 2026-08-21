import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:c_shield_aip/src/internal/platform/c_shield_aip_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelCShieldAip platform = MethodChannelCShieldAip();
  const MethodChannel channel = MethodChannel('c_shield_aip');

  final calls = <MethodCall>[];

  setUp(() {
    platform = MethodChannelCShieldAip();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'sdk.initialize' => null,
        'ssl.configure' => null,
        'ssl.updatePins' => null,
        'ssl.isConfigured' => false,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('initialize sends sdk.initialize', () async {
    await platform.initialize();
    expect(calls.single.method, 'sdk.initialize');
  });

  test('sslIsConfigured returns bool', () async {
    final result = await platform.sslIsConfigured();
    expect(result, false);
    expect(calls.single.method, 'ssl.isConfigured');
  });
}
