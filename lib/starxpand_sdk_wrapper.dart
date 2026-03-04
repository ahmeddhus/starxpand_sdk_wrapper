import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'src/pigeon.g.dart';

enum StarInterfaceType { lan, bluetooth, usb }

class StarDevice {
  final String identifier;
  final StarInterfaceType interface;
  final String? model;
  StarDevice(this.identifier, this.interface, {this.model});
}

class StarStatus {
  final bool online, coverOpen, paperEmpty;
  final String? raw;
  StarStatus({
    required this.online,
    required this.coverOpen,
    required this.paperEmpty,
    this.raw,
  });
}

typedef DeviceCallback = void Function(StarDevice);
typedef StatusCallback = void Function(StarStatus);

class StarXpand implements StarFlutterApi {
  StarXpand._() {
    // Use the exact setup function your generated file exposes:
    // If your generated code has `setup`, use that instead.
    StarFlutterApi.setUp(this);
  }
  static final StarXpand instance = StarXpand._();

  final _host = StarHostApi();

  // Renamed callbacks to avoid colliding with StarFlutterApi method names
  DeviceCallback? deviceFound;
  VoidCallback? discoveryDone;
  StatusCallback? statusChanged;
  void Function(String message)? logMessage;
  void Function(bool success)? connectionComplete;

  // ---------- Public API (calls native via HostApi) ----------

  Future<void> startDiscovery({
    Set<StarInterfaceType> interfaces = const {},
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await _host.startDiscovery(
      DiscoverOptions(
        interfaces: interfaces.map((e) => InterfaceType.values[e.index]).toList(),
        timeoutMs: timeout.inMilliseconds,
      ),
    );
  }

  Future<void> stopDiscovery() => _host.stopDiscovery();

  Future<bool> connect(StarDevice d, {bool monitor = true}) {
    return _host.connect(
      ConnectRequest(
        identifier: d.identifier,
        iface: InterfaceType.values[d.interface.index],
        monitor: monitor,
      ),
    );
  }

  Future<void> disconnect() => _host.disconnect();

  /// Print a PDF by converting it to an image
  Future<bool> printPdf(Uint8List pdfBytes, {int? width}) async {
    try {
      // Convert PDF to image (203 DPI for thermal printers)
      final imageStream = Printing.raster(pdfBytes, dpi: 203);

      // Get the first page from the stream
      PdfRaster page;
      try {
        page = await imageStream.first;
      } catch (e) {
        logMessage?.call('No pages in PDF or PDF error: $e');
        return false;
      }

      // Convert page to PNG bytes
      final imageBytes = await page.toPng();

      return _host.printImage(
        ImageRequest(
          imageBytes: imageBytes.toList(),
          width: width ?? 576, // 576 dots = 80mm at 203 DPI
        ),
      );
    } catch (e) {
      logMessage?.call('PDF print error: $e');
      return false;
    }
  }

  /// Print raw PNG bytes directly.
  Future<bool> printImageBytes(Uint8List imageBytes, {int width = 576}) {
    return _host.printImage(
      ImageRequest(
        imageBytes: imageBytes.toList(),
        width: width,
      ),
    );
  }

  Future<bool> openCashDrawer() => _host.openCashDrawer();

  Future<StarStatus> getStatus() async {
    final s = await _host.getStatus();
    return StarStatus(
      online: s.online ?? false,
      coverOpen: s.coverOpen ?? false,
      paperEmpty: s.paperEmpty ?? false,
      raw: s.raw,
    );
  }

  // ---------- Callbacks from native (FlutterApi) ----------
  // These method names MUST match what Pigeon generated.

  @override
  void onDeviceFound(Device d) {
    final dev = StarDevice(
      d.identifier ?? '',
      StarInterfaceType.values[d.iface!.index],
      model: d.model,
    );
    deviceFound?.call(dev);
  }

  @override
  void onDiscoveryDone() {
    discoveryDone?.call();
  }

  @override
  void onStatus(Status s) {
    statusChanged?.call(
      StarStatus(
        online: s.online ?? false,
        coverOpen: s.coverOpen ?? false,
        paperEmpty: s.paperEmpty ?? false,
        raw: s.raw,
      ),
    );
  }

  @override
  void onLog(String message) {
    logMessage?.call(message);
  }

  @override
  void onConnectionComplete(bool success) {
    connectionComplete?.call(success);
  }
}
