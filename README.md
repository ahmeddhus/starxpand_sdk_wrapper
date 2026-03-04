# starxpand_sdk_wrapper

A Flutter plugin that provides a simple interface to Star Micronics receipt printers using the official StarXpand SDK for Android and iOS.

## Features

- 🔍 **Device Discovery** - Automatically discover Star printers on your network or connected via USB/Bluetooth
- 🖨️ **Image Printing** - Print images directly from Flutter
- 💰 **Cash Drawer Control** - Open cash drawers connected to Star printers
- 📊 **Status Monitoring** - Get real-time printer status (paper level, cover state, errors)
- 🔌 **Multiple Interfaces** - Support for USB & bluetooth connections

## Supported Printers

This plugin supports Star Micronics printers compatible with the StarXpand SDK, I've personally tested the TSP100III but all other StarXpand-compatible models should work.

## Platform Requirements

- **iOS**: 13.0 or higher
- **Android**: API 26 (Android 8.0) or higher
- Star Micronics printer with StarXpand SDK support

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  starxpand_sdk_wrapper: ^1.0.3
```

Then run:
flutter pub get

### iOS Setup

Add these keys to your ios/Runner/Info.plist:

```xml
<!--> For Bluetooth -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to Star printers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to Star printers</string>

<!--> For USB -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>jp.star-m.starpro</string>
</array>
```

### Android Setup

This plugin depends on `com.starmicronics:stario10:1.11.0`, which requires:

- `minSdkVersion 26` or higher

Set this in your app module (`android/app/build.gradle` or `android/app/build.gradle.kts`) before building.

Add these permissions to your android/app/src/main/AndroidManifest.xml:

```xml
<!-- For Bluetooth -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />

<!-- For USB -->
<uses-feature android:name="android.hardware.usb.host" />

<!-- For Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## Usage

Import the package

```dart
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';
```

### Discover Printers

```dart
// Start discovery for all interface types
await StarXpandSdkWrapper.startDiscovery(
  interfaces: [InterfaceType.bluetooth, InterfaceType.usb],
  timeoutMs: 8000,
);

// Listen for discovered devices
StarXpandSdkWrapper.onDeviceFound.listen((device) {
  print('Found printer: ${device.identifier}');
  print('Model: ${device.model}');
  print('Interface: ${device.iface}');
});

// Listen for discovery completion
StarXpandSdkWrapper.onDiscoveryDone.listen((_) {
  print('Discovery finished');
});

// Stop discovery manually if needed
await StarXpandSdkWrapper.stopDiscovery();
```

### Connect to a Printer

```dart
// Listen for connection status
StarXpandSdkWrapper.onConnectionComplete.listen((success) {
  print('Connection ${success ? "successful" : "failed"}');
});
```

### Print an Image

A simple way to design your receipt is to use the PDF package (https://pub.dev/packages/pdf) then simply convert that to a Uint8List.

```dart
// Load your image as bytes
Uint8List imageBytes = await loadImageBytes();

// Print the image (width in dots, typically 576 for 3-inch printers)
bool success = await StarXpandSdkWrapper.printImage(
  imageBytes: imageBytes,
  width: 576,
);

if (success) {
  print('Image sent to printer');
}
```

### Open Cash Drawer

```dart
bool success = await StarXpandSdkWrapper.openCashDrawer();

if (success) {
  print('Cash drawer opened');
}
```

### Get Printer Status

```dart
Status status = await StarXpandSdkWrapper.getStatus();

print('Online: ${status.online}');
print('Cover Open: ${status.coverOpen}');
print('Paper Empty: ${status.paperEmpty}');

// Monitor status changes in real-time (if monitor: true was set during connect)
StarXpandSdkWrapper.onStatus.listen((status) {
  if (status.paperEmpty) {
    print('Warning: Printer is out of paper!');
  }
});
```

### Disconnect

```dart
await StarXpandSdkWrapper.disconnect();
```

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';

class PrinterExample extends StatefulWidget {
  @override
  _PrinterExampleState createState() => _PrinterExampleState();
}

class _PrinterExampleState extends State<PrinterExample> {
  List<Device> _devices = [];
  Device? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    StarXpandSdkWrapper.onDeviceFound.listen((device) {
      setState(() {
        _devices.add(device);
      });
    });

    await StarXpandSdkWrapper.startDiscovery();
  }

  Future<void> _connectToPrinter(Device device) async {
    bool connected = await StarXpandSdkWrapper.connect(
      identifier: device.identifier,
      iface: device.iface,
      monitor: true,
    );

    if (connected) {
      setState(() {
        _selectedDevice = device;
      });
    }
  }

  Future<void> _printTestImage() async {
    // Load your image bytes here
    Uint8List imageBytes = ...;

    await StarXpandSdkWrapper.printImage(
      imageBytes: imageBytes,
      width: 576,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Star Printer Example')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  title: Text(device.model ?? 'Unknown'),
                  subtitle: Text(device.identifier ?? ''),
                  trailing: Icon(
                    _selectedDevice == device
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  onTap: () => _connectToPrinter(device),
                );
              },
            ),
          ),
          if (_selectedDevice != null)
            ElevatedButton(
              onPressed: _printTestImage,
              child: Text('Print Test Image'),
            ),
        ],
      ),
    );
  }
}
```

## API Reference

### Methods

| Method                                    | Description                | Returns          |
| ----------------------------------------- | -------------------------- | ---------------- |
| `startDiscovery({interfaces, timeoutMs})` | Start discovering printers | `Future<void>`   |
| `stopDiscovery()`                         | Stop discovery             | `Future<void>`   |
| `connect({identifier, iface, monitor})`   | Connect to a printer       | `Future<bool>`   |
| `disconnect()`                            | Disconnect from printer    | `Future<void>`   |
| `printImage({imageBytes, width})`         | Print an image             | `Future<bool>`   |
| `openCashDrawer()`                        | Open cash drawer           | `Future<bool>`   |
| `getStatus()`                             | Get printer status         | `Future<Status>` |

### Streams

| Stream                 | Type             | Description                        |
| ---------------------- | ---------------- | ---------------------------------- |
| `onDeviceFound`        | `Stream<Device>` | Emits when a printer is discovered |
| `onDiscoveryDone`      | `Stream<void>`   | Emits when discovery completes     |
| `onConnectionComplete` | `Stream<bool>`   | Emits connection result            |
| `onStatus`             | `Stream<Status>` | Emits printer status updates       |

## Types

InterfaceType

```dart
enum InterfaceType { bluetooth, usb }
```

Device

```dart
class Device {
  String? identifier;  // Connection identifier
  InterfaceType? iface; // Interface type
  String? model;        // Printer model
}
```

Status

```dart
class Status {
  bool? online;      // Printer is online and ready
  bool? coverOpen;   // Printer cover is open
  bool? paperEmpty;  // Printer is out of paper
  String? raw;       // Raw status data
}
```

## Troubleshooting

### iOS

#### Problem: Printer not discovered via Bluetooth

Ensure Bluetooth permissions are added to Info.plist
Check that Bluetooth is enabled on the device
Make sure the printer is in pairing mode

#### Problem: USB printer not working

Add the external accessory protocol to Info.plist
Ensure the printer is properly connected

### Android

#### Problem: Bluetooth discovery not working on Android 12+

Request BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions at runtime
Target SDK 31+ requires these permissions

#### Problem: Network printer not discovered

Ensure the device and printer are on the same network
Check firewall settings

## Acknowledgments

Star Micronics for the StarXpand Android SDK & iOS SDK

## Related Links

- [Star Micronics Developer Portal](https://www.star-m.jp/eng/products/s_print/sdk.html)
- [StarXpand SDK Documentation](https://star-m.jp/products/s_print/sdk/starxpand/manual/en/)
- [StarXpand SDK Documentation](https://star-m.jp/products/s_print/sdk/starxpand/manual/en/)
- [StarXpand-SDK-Android GitHub](https://github.com/star-micronics/StarXpand-SDK-Android)
- [StarXpand-SDK-iOS GitHub](https://github.com/star-micronics/StarXpand-SDK-iOS)
