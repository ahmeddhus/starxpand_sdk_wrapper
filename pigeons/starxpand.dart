import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon.g.dart',
    swiftOut: 'ios/Classes/Pigeon.g.swift',
    kotlinOut: 'android/src/main/kotlin/dev/orioletech/starxpand_sdk_wrapper/Pigeon.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.orioletech.starxpand_sdk_wrapper'),
    dartOptions: DartOptions(),
    swiftOptions: SwiftOptions(),
  ),
)
enum InterfaceType { lan, bluetooth, usb }

class Device {
  String? identifier; // IP, MAC, or USB path
  InterfaceType? iface;
  String? model; // optional model name
}

class Status {
  bool? online;
  bool? coverOpen;
  bool? paperEmpty;
  String? raw; // optional raw/native status string
}

class DiscoverOptions {
  List<InterfaceType?>? interfaces;
  int? timeoutMs; // discovery window
}

class ConnectRequest {
  String? identifier;
  InterfaceType? iface;
  bool? monitor; // start status monitoring
}

class ImageRequest {
  List<int?>? imageBytes;
  int? width;
}

@HostApi() // Dart -> Native (you call these from Dart)
abstract class StarHostApi {
  // Discovery
  void startDiscovery(DiscoverOptions opts);
  void stopDiscovery();
  // Connection
  bool connect(ConnectRequest req); // return success
  void disconnect();
  // Printing
  bool printImage(ImageRequest req);
  bool openCashDrawer();

  // Status
  Status getStatus();
}

@FlutterApi() // Native -> Dart (Native calls these to push events)
abstract class StarFlutterApi {
  void onDeviceFound(Device device);
  void onDiscoveryDone();
  void onStatus(Status status);
  void onLog(String message);
  void onConnectionComplete(bool success);
}
