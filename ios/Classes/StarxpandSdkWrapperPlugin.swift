import Flutter
import UIKit
import StarIO10

public class StarxpandSdkWrapperPlugin: NSObject, FlutterPlugin, StarHostApi {
    
    private var flutterApi: StarFlutterApi?
    private var discoveryManager: StarDeviceDiscoveryManager?
    private var discoveredDevices: Set<String> = []
    private var discoveryDelegate: DiscoveryDelegate?

    private var printer: StarPrinter?
    private var printerDelegate: PrinterStatusDelegate?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = StarxpandSdkWrapperPlugin()
        StarHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: plugin)
        plugin.flutterApi = StarFlutterApi(binaryMessenger: registrar.messenger())
    }
    
    func startDiscovery(opts: DiscoverOptions) throws {
        // Get timeout value, default 8000ms (matches Android)
        let timeoutMs = opts.timeoutMs ?? 8000
        print("[StarXpand] Starting discovery with timeout: \(timeoutMs)ms")
        
        // Stop any existing discovery (matches Android discoveryManager?.stopDiscovery())
        try? discoveryManager?.stopDiscovery()
        discoveredDevices.removeAll()
        
        // Map Pigeon InterfaceType to StarIO10 InterfaceType (matches Android mapNotNull block)
        let interfaceTypes: [StarIO10.InterfaceType]
        if let interfaces = opts.interfaces, !interfaces.isEmpty {
            // Convert each Pigeon type to StarIO10 type
            interfaceTypes = interfaces.compactMap { pigeonType -> StarIO10.InterfaceType? in
                switch pigeonType {
                case .lan: return .lan              // matches InterfaceType.Lan
                case .bluetooth: return .bluetooth   // matches InterfaceType.Bluetooth
                case .usb: return .usb              // matches InterfaceType.Usb
                default: return nil
                }
            }
        } else {
            // Default to all types (matches Android ?: listOf(...))
            interfaceTypes = [.lan, .bluetooth, .usb]
        }
        
        print("[StarXpand] Starting discovery for interfaces: \(interfaceTypes)")
        
        // Create discovery manager (matches StarDeviceDiscoveryManagerFactory.create)
        discoveryManager = try StarDeviceDiscoveryManagerFactory.create(interfaceTypes: interfaceTypes)
        
        // Create and set delegate
        discoveryDelegate = DiscoveryDelegate(plugin: self)
        discoveryManager?.delegate = discoveryDelegate
        
        // Set discovery timeout (matches discoveryManager?.discoveryTime = timeoutMs)
        discoveryManager?.discoveryTime = Int(timeoutMs)
        
        // Start discovery (matches discoveryManager?.startDiscovery())
        try discoveryManager?.startDiscovery()
        
        // Note: In iOS the delegate methods will be called automatically
        // No need for manual timeout handling - the SDK calls onFinished
    }
    
    func stopDiscovery() throws {
        print("[StarXpand] Stopping discovery")
        
        try? discoveryManager?.stopDiscovery()
        discoveryManager?.delegate = nil
        discoveryDelegate = nil
        discoveredDevices.removeAll()
        
        DispatchQueue.main.async {
            print("[StarXpand] Discovery stopped")
            self.flutterApi?.onDiscoveryDone() { _ in }
        }
    }
    
    func connect(req: ConnectRequest) throws -> Bool {
        // Disconnect if already connected
        if printer != nil {
            try? disconnect()
        }
        
        guard let identifier = req.identifier,
            let interfaceType = req.iface else {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Missing identifier or interface"
            ])
        }
        
        // Convert Pigeon InterfaceType to StarIO10 InterfaceType
        let starInterfaceType: StarIO10.InterfaceType
        switch interfaceType {
        case .lan:
            starInterfaceType = .lan
        case .bluetooth:
            starInterfaceType = .bluetooth
        case .usb:
            starInterfaceType = .usb
        }
        
        print("[StarXpand] Connecting to printer: \(identifier)")
        
        // Create connection settings
        let settings = StarConnectionSettings(
            interfaceType: starInterfaceType,
            identifier: identifier
        )
        
        // Create printer instance
        printer = StarPrinter(settings)
        
        // Set up status monitoring if requested
        if req.monitor == true {
            printerDelegate = PrinterStatusDelegate(plugin: self)
            printer?.printerDelegate = printerDelegate
        }
        
        // Open connection asynchronously
        Task {
            do {
                try await self.printer?.open()
                print("[StarXpand] Connected to printer: \(identifier)")
                
                DispatchQueue.main.async {
                    self.flutterApi?.onConnectionComplete(success: true) { _ in }
                }
            } catch {
                print("[StarXpand] Connection failed: \(error)")
                
                DispatchQueue.main.async {
                    self.flutterApi?.onConnectionComplete(success: false) { _ in }
                }
            }
        }
        
        return true
    }
    
    func disconnect() throws {
        guard let printer = printer else {
            print("[StarXpand] No printer to disconnect")
            return
        }
        
        print("[StarXpand] Disconnecting from printer")
        
        Task {
            await printer.close()
            print("[StarXpand] Disconnected from printer")
        }
        
        // Clean up
        self.printer?.printerDelegate = nil
        self.printerDelegate = nil
        self.printer = nil
    }
    
    func printImage(req: ImageRequest) throws -> Bool {
        guard let printer = printer else {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Printer not connected"
            ])
        }
        
        guard let imageBytes = req.imageBytes,
            let width = req.width else {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Missing image data or width"
            ])
        }
        
        print("[StarXpand] Printing image with width: \(width) dots")
        
        // Convert List<Long?> to Data (bytes), filtering out nils
        let data = Data(imageBytes.compactMap { $0 }.map { UInt8($0 & 0xFF) })
        
        // Create UIImage from bytes
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create image from data"
            ])
        }
        
        print("[StarXpand] Image created: \(image.size.width)x\(image.size.height) pixels")
        
        // Build StarXpand command
        let builder = StarXpandCommand.StarXpandCommandBuilder()
        
        builder.addDocument(StarXpandCommand.DocumentBuilder()
            .addPrinter(StarXpandCommand.PrinterBuilder()
                .actionPrintImage(StarXpandCommand.Printer.ImageParameter(image: image, width: Int(width)))
                .actionFeed(5.0) // Feed 5mm after image
                .actionCut(.partial) // Partial cut
            )
        )
        
        let command = builder.getCommands()
        
        // Print asynchronously
        Task {
            do {
                try await printer.print(command: command)
                print("[StarXpand] Image printed successfully")
            } catch {
                print("[StarXpand] Print failed: \(error.localizedDescription)")
            }
        }
        
        return true
    }
    
    func openCashDrawer() throws -> Bool {
        guard let printer = printer else {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Printer not connected"
            ])
        }
        
        print("[StarXpand] Opening cash drawer")
        
        // Build drawer command
        let builder = StarXpandCommand.StarXpandCommandBuilder()
        
        let openParameter = StarXpandCommand.Drawer.OpenParameter()
            .setChannel(.no1) // Default to channel 1
            .setOnTime(200) // 200ms pulse
        
        builder.addDocument(StarXpandCommand.DocumentBuilder()
            .addDrawer(StarXpandCommand.DrawerBuilder()
                .actionOpen(openParameter)
            )
        )
        
        let command = builder.getCommands()
        
        // Send command asynchronously
        Task {
            do {
                try await printer.print(command: command)
                print("[StarXpand] Cash drawer opened successfully")
            } catch {
                print("[StarXpand] Open drawer failed: \(error.localizedDescription)")
            }
        }
        
        return true
    }

    func getStatus() throws -> Status {
        guard let printer = printer else {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Printer not connected"
            ])
        }
        
        // Use semaphore to convert async to sync
        var printerStatus: StarPrinterStatus?
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                printerStatus = try await printer.getStatus()
            } catch let err {
                error = err
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = error {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get status: \(error.localizedDescription)"
            ])
        }
        
        guard let status = printerStatus else {
            throw NSError(domain: "StarXpandPlugin", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not get printer status"
            ])
        }
        
        print("[StarXpand] Status: online=\(!status.hasError), coverOpen=\(status.coverOpen), paperEmpty=\(status.paperEmpty)")
        
        // Convert to our Status type
        return Status(
            online: !status.hasError,
            coverOpen: status.coverOpen,
            paperEmpty: status.paperEmpty,
            raw: String(describing: status)
        )
    }
    
    // Internal method called by the delegate
    fileprivate func handleDiscoveredPrinter(_ printer: StarPrinter) {
        // Get connection settings
        let connectionSettings = printer.connectionSettings
        
        // Prevent duplicates
        guard !discoveredDevices.contains(connectionSettings.identifier) else { return }
        discoveredDevices.insert(connectionSettings.identifier)
        
        // Post to main thread
        DispatchQueue.main.async {
            // Convert StarIO10 interface to Pigeon interface
            let pigeonIface: InterfaceType
            switch connectionSettings.interfaceType {
            case .lan: 
                pigeonIface = .lan
            case .bluetooth: 
                pigeonIface = .bluetooth
            case .bluetoothLE: 
                pigeonIface = .bluetooth
            case .usb: 
                pigeonIface = .usb
            default: 
                pigeonIface = .lan
            }
            
            // Get model name
            let modelName: String
            if let model = printer.information?.model {
                modelName = String(describing: model)
            } else {
                modelName = "Unknown"
            }
            
            // Create Device object
            let device = Device(
                identifier: connectionSettings.identifier,
                iface: pigeonIface,
                model: modelName
            )
            
            // Log and notify Flutter
            print("[StarXpand] Found device: \(device.identifier ?? "") (\(device.model ?? ""))")
            self.flutterApi?.onDeviceFound(device: device) { _ in }
        }
    }
    
    fileprivate func handleDiscoveryFinished() {
        DispatchQueue.main.async {
            print("[StarXpand] Discovery finished")
            self.flutterApi?.onDiscoveryDone() { _ in }
        }
    }
}

// MARK: - Private Delegate Class
private class DiscoveryDelegate: NSObject, StarDeviceDiscoveryManagerDelegate {
    weak var plugin: StarxpandSdkWrapperPlugin?
    
    init(plugin: StarxpandSdkWrapperPlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func manager(_ manager: StarDeviceDiscoveryManager, didFind printer: StarPrinter) {
        plugin?.handleDiscoveredPrinter(printer)
    }
    
    func managerDidFinishDiscovery(_ manager: StarDeviceDiscoveryManager) {
        plugin?.handleDiscoveryFinished()
    }
}

// MARK: - Private Delegate Class for Printer Status
private class PrinterStatusDelegate: NSObject, PrinterDelegate {
    weak var plugin: StarxpandSdkWrapperPlugin?
    
    init(plugin: StarxpandSdkWrapperPlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func printerIsReady(_ printer: StarPrinter) {
        print("[StarXpand] Printer is ready")
    }
    
    func printerDidHaveError(_ printer: StarPrinter) {
        print("[StarXpand] Printer has error")
    }
    
    func printerIsPaperReady(_ printer: StarPrinter) {
        print("[StarXpand] Paper is ready")
    }
    
    func printerIsPaperNearEmpty(_ printer: StarPrinter) {
        print("[StarXpand] Paper near empty")
    }
    
    func printerIsPaperEmpty(_ printer: StarPrinter) {
        print("[StarXpand] Paper empty")
    }
    
    func printerIsCoverOpen(_ printer: StarPrinter) {
        print("[StarXpand] Cover open")
    }
    
    func printerIsCoverClose(_ printer: StarPrinter) {
        print("[StarXpand] Cover closed")
    }
    
    func printer(_ printer: StarPrinter, communicationErrorDidOccur error: Error) {
        print("[StarXpand] Communication error: \(error)")
    }
}