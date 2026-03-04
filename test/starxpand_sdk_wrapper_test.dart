import 'package:flutter_test/flutter_test.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper_platform_interface.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper_method_channel.dart';

void main() {
  final StarxpandSdkWrapperPlatform initialPlatform =
      StarxpandSdkWrapperPlatform.instance;

  test('$MethodChannelStarxpandSdkWrapper is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelStarxpandSdkWrapper>());
  });

  test('StarXpand singleton is available', () {
    expect(StarXpand.instance, isA<StarXpand>());
  });
}
