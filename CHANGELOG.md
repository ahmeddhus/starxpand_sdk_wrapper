## 1.0.3

- Added `printImageBytes(Uint8List imageBytes, {int width = 576})` to the public Dart API.
- Android: `printImage()` now returns `false` when printing fails and only returns `true` on real success.
- Android: `getStatus()` now returns real printer status instead of a placeholder.
- Updated example/test files to current API naming (`StarXpand`) so static analysis passes.

## 1.0.2

- Added android:exported="true"

## 1.0.1

- Updated read me

## 1.0.0

- Initial release
- Device discovery for Bluetooth, and USB printers
- Connect to Star Micronics printers
- Print images
- Open cash drawer
- Get printer status
- Real-time status monitoring
