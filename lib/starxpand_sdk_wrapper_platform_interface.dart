import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'starxpand_sdk_wrapper_method_channel.dart';

abstract class StarxpandSdkWrapperPlatform extends PlatformInterface {
  /// Constructs a StarxpandSdkWrapperPlatform.
  StarxpandSdkWrapperPlatform() : super(token: _token);

  static final Object _token = Object();

  static StarxpandSdkWrapperPlatform _instance = MethodChannelStarxpandSdkWrapper();

  /// The default instance of [StarxpandSdkWrapperPlatform] to use.
  ///
  /// Defaults to [MethodChannelStarxpandSdkWrapper].
  static StarxpandSdkWrapperPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [StarxpandSdkWrapperPlatform] when
  /// they register themselves.
  static set instance(StarxpandSdkWrapperPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
