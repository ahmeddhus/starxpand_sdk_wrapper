import 'package:flutter/material.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';
// Components
import 'constants.dart';
import 'example_receipt_pdf.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final xp = StarXpand.instance;
  final _seen = <_StateDeviceKey>{};
  final devices = <StarDevice>[];
  bool _scanning = false;
  bool _connecting = false;
  bool _printing = false;
  StarDevice? _selectedDevice;
  StarDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    xp.deviceFound = (d) {
      final k = _StateDeviceKey(d.identifier, d.interface);
      if (_seen.add(k)) setState(() => devices.add(d));
    };
    xp.discoveryDone = () => setState(() => _scanning = false);
    xp.statusChanged = (s) {
      debugPrint(
        'Status: online=${s.online}, coverOpen=${s.coverOpen}, paperEmpty=${s.paperEmpty}',
      );
    };
    xp.logMessage = (m) => debugPrint('LOG: $m');
    xp.connectionComplete = (success) {
      setState(() => _connecting = false);
      if (success) {
        setState(() {
          _connectedDevice = _selectedDevice;
        });
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Connected to ${_selectedDevice!.identifier}')),
        );
      } else {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Connection failed')),
        );
      }
    };
  }

  @override
  void dispose() {
    xp.stopDiscovery();
    xp.disconnect();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _seen.clear();
      devices.clear();
      _selectedDevice = null;
      _connectedDevice = null;
    });

    await xp.startDiscovery(
      interfaces: {
        StarInterfaceType.usb, // Focus on USB for now
        // Add others if needed:
        // StarInterfaceType.lan,
        // StarInterfaceType.bluetooth,
      },
      timeout: const Duration(seconds: 10),
    );
  }

  Future<void> _stop() async {
    await xp.stopDiscovery();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect() async {
    if (_selectedDevice == null) return;

    setState(() => _connecting = true);

    try {
      final success = await xp.connect(_selectedDevice!, monitor: true);
      if (success) {
        setState(() {
          _connectedDevice = _selectedDevice;
          _connecting = false;
        });
        if (mounted) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('Connected to ${_selectedDevice!.identifier}')),
          );
        }
      } else {
        setState(() => _connecting = false);
        if (mounted) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Connection failed')),
          );
        }
      }
    } catch (e) {
      setState(() => _connecting = false);
      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await xp.disconnect();
    setState(() {
      _connectedDevice = null;
    });
  }

  Future<void> _printTestReceipt() async {
    if (_connectedDevice == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Please connect to a printer first')),
      );
      return;
    }

    setState(() => _printing = true);

    try {
      // Generate PDF receipt
      final pdfBytes = await generateExampleReceiptPdf(context: context);

      // Print the PDF as image
      final success = await xp.printPdf(
        pdfBytes,
        width: 576, // 80mm paper = 576 dots at 203 DPI
      );

      setState(() => _printing = false);

      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(success ? 'Receipt printed!' : 'Print failed')),
      );
    } catch (e) {
      setState(() => _printing = false);
      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  IconData _getInterfaceIcon(StarInterfaceType type) {
    switch (type) {
      case StarInterfaceType.lan:
        return Icons.wifi;
      case StarInterfaceType.bluetooth:
        return Icons.bluetooth;
      case StarInterfaceType.usb:
        return Icons.usb;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StarXpand Demo'),
        actions: [
          IconButton(
            tooltip: 'Scan',
            icon: const Icon(Icons.search),
            onPressed: _scanning ? null : _scan,
          ),
          IconButton(
            tooltip: 'Stop',
            icon: const Icon(Icons.stop),
            onPressed: _scanning ? _stop : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          if (_connectedDevice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade100,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected: ${_connectedDevice!.identifier}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(onPressed: _disconnect, child: const Text('Disconnect')),
                ],
              ),
            ),

          // Device list - hide when connected to a device
          if (_connectedDevice == null)
            Expanded(
              child: devices.isEmpty
                  ? Center(child: Text(_scanning ? 'Scanning…' : 'No devices found'))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, i) {
                        final d = devices[i];
                        final isSelected = _selectedDevice?.identifier == d.identifier;
                        final isConnected = _connectedDevice?.identifier == d.identifier;

                        return ListTile(
                          selected: isSelected,
                          leading: Icon(
                            isConnected
                                ? Icons.check_circle
                                : _getInterfaceIcon(d.interface),
                            color: isConnected ? Colors.green : null,
                          ),
                          title: Text(d.identifier),
                          subtitle: Text(
                            '${d.interface.name.toUpperCase()} - ${d.model ?? "Unknown"}',
                          ),
                          trailing: isSelected && !isConnected
                              ? const Icon(Icons.arrow_forward)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedDevice = d;
                            });
                          },
                        );
                      },
                    ),
            ),

          // Action buttons
          if (_selectedDevice != null && _connectedDevice == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _connecting ? null : _connect,
                  icon: _connecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(_connecting ? 'Connecting...' : 'Connect'),
                ),
              ),
            ),

          if (_connectedDevice != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _printing ? null : _printTestReceipt,
                      icon: _printing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print),
                      label: Text(_printing ? 'Printing...' : 'Print Test Receipt'),
                    ),
                    // const SizedBox(height: 8),
                    // ElevatedButton.icon(
                    //   onPressed: () async {
                    //     final success = await xp.openCashDrawer();
                    //     if (mounted) {
                    //       scaffoldMessengerKey.currentState?.showSnackBar(
                    //         SnackBar(
                    //           content: Text(success ? 'Drawer opened' : 'Drawer failed'),
                    //         ),
                    //       );
                    //     }
                    //   },
                    //   icon: const Icon(Icons.inbox),
                    //   label: const Text('Open Drawer'),
                    // ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
      // Hide floating action button when connected
      floatingActionButton: _connectedDevice != null
          ? null
          : _scanning
          ? FloatingActionButton.extended(
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            )
          : FloatingActionButton.extended(
              onPressed: _scan,
              icon: const Icon(Icons.search),
              label: const Text('Scan'),
            ),
    );
  }
}

class _StateDeviceKey {
  final String id;
  final StarInterfaceType iface;
  _StateDeviceKey(this.id, this.iface);

  @override
  bool operator ==(Object o) => o is _StateDeviceKey && o.id == id && o.iface == iface;

  @override
  int get hashCode => Object.hash(id, iface);
}
