import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelStarxpandSdkWrapper platform = MethodChannelStarxpandSdkWrapper();
  const MethodChannel channel = MethodChannel('starxpand_sdk_wrapper');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
