import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'starxpand_sdk_wrapper_platform_interface.dart';

/// An implementation of [StarxpandSdkWrapperPlatform] that uses method channels.
class MethodChannelStarxpandSdkWrapper extends StarxpandSdkWrapperPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('starxpand_sdk_wrapper');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
