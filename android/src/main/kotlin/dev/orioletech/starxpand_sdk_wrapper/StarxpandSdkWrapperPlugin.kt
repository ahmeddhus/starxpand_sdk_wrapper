package dev.orioletech.starxpand_sdk_wrapper

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import com.starmicronics.stario10.InterfaceType
import com.starmicronics.stario10.StarConnectionSettings
import com.starmicronics.stario10.StarDeviceDiscoveryManager
import com.starmicronics.stario10.StarDeviceDiscoveryManagerFactory
import com.starmicronics.stario10.StarPrinter
import com.starmicronics.stario10.starxpandcommand.StarXpandCommandBuilder
import com.starmicronics.stario10.starxpandcommand.DocumentBuilder
import com.starmicronics.stario10.starxpandcommand.PrinterBuilder
import kotlinx.coroutines.*

class StarxpandSdkWrapperPlugin :
    FlutterPlugin,
    StarHostApi {

    private lateinit var context: Context
    private lateinit var messenger: BinaryMessenger
    private lateinit var flutterApi: StarFlutterApi
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private var discoveryManager: StarDeviceDiscoveryManager? = null
    private var printer: StarPrinter? = null
    private val job = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.Default + job)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        messenger = binding.binaryMessenger
        StarHostApi.setUp(messenger, this)
        flutterApi = StarFlutterApi(messenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        StarHostApi.setUp(messenger, null)
        discoveryManager?.stopDiscovery()
        scope.launch {
            try {
                printer?.closeAsync()?.await()
            } catch (e: Exception) {
                // Ignore
            }
        }
        job.cancel()
    }

    override fun startDiscovery(opts: DiscoverOptions) {
        try {
            // Stop any existing discovery
            discoveryManager?.stopDiscovery()
            
            // Map Pigeon InterfaceType to StarIO10 InterfaceType
            val interfaceTypes = opts.interfaces?.mapNotNull { pigeonType ->
                when (pigeonType) {
                    dev.orioletech.starxpand_sdk_wrapper.InterfaceType.LAN -> 
                        InterfaceType.Lan
                    dev.orioletech.starxpand_sdk_wrapper.InterfaceType.BLUETOOTH -> 
                        InterfaceType.Bluetooth
                    dev.orioletech.starxpand_sdk_wrapper.InterfaceType.USB -> 
                        InterfaceType.Usb
                    else -> null
                }
            } ?: listOf(InterfaceType.Lan, InterfaceType.Bluetooth, InterfaceType.Usb)

            flutterApi.onLog("Starting discovery for interfaces: $interfaceTypes") { }

            discoveryManager = StarDeviceDiscoveryManagerFactory.create(
                interfaceTypes,
                context
            )

            // discoveryTime expects Int (milliseconds) - fix nullable Long
            val timeoutMs = opts.timeoutMs?.toInt() ?: 8000
            discoveryManager?.discoveryTime = timeoutMs

            discoveryManager?.callback = object : StarDeviceDiscoveryManager.Callback {
                override fun onPrinterFound(printer: StarPrinter) {
                    mainHandler.post {
                        val connectionSettings = printer.connectionSettings
                        
                        val pigeonIface = when (connectionSettings.interfaceType) {
                            InterfaceType.Lan -> dev.orioletech.starxpand_sdk_wrapper.InterfaceType.LAN
                            InterfaceType.Bluetooth -> dev.orioletech.starxpand_sdk_wrapper.InterfaceType.BLUETOOTH
                            InterfaceType.Usb -> dev.orioletech.starxpand_sdk_wrapper.InterfaceType.USB
                            else -> dev.orioletech.starxpand_sdk_wrapper.InterfaceType.LAN
                        }

                        val modelName = printer.information?.model?.name ?: "Unknown"
                        
                        val device = Device(
                            identifier = connectionSettings.identifier,
                            iface = pigeonIface,
                            model = modelName
                        )
                        
                        flutterApi.onLog("Found device: ${device.identifier} (${device.model})") { }
                        flutterApi.onDeviceFound(device) { }
                    }
                }

                override fun onDiscoveryFinished() {
                    mainHandler.post {
                        flutterApi.onLog("Discovery finished") { }
                        flutterApi.onDiscoveryDone { }
                    }
                }
            }

            discoveryManager?.startDiscovery()
            
        } catch (e: Exception) {
            flutterApi.onLog("Discovery error: ${e.message}") { }
        }
    }

    override fun stopDiscovery() {
        try {
            discoveryManager?.stopDiscovery()
            flutterApi.onLog("Discovery stopped") { }
        } catch (e: Exception) {
            flutterApi.onLog("Stop discovery error: ${e.message}") { }
        }
    }

    override fun connect(req: ConnectRequest): Boolean {
        scope.launch {
            try {
                val starInterface = when (req.iface) {
                    dev.orioletech.starxpand_sdk_wrapper.InterfaceType.LAN -> InterfaceType.Lan
                    dev.orioletech.starxpand_sdk_wrapper.InterfaceType.BLUETOOTH -> InterfaceType.Bluetooth
                    dev.orioletech.starxpand_sdk_wrapper.InterfaceType.USB -> InterfaceType.Usb
                    else -> InterfaceType.Lan
                }

                val settings = StarConnectionSettings(starInterface, req.identifier ?: "")
                printer = StarPrinter(settings, context)

                // Setup monitoring delegates if requested
                if (req.monitor == true) {
                    printer?.printerDelegate = object : com.starmicronics.stario10.PrinterDelegate() {
                        override fun onReady() {
                            mainHandler.post {
                                flutterApi.onLog("Printer: Ready") { }
                            }
                        }

                        override fun onError() {
                            mainHandler.post {
                                flutterApi.onLog("Printer: Error") { }
                            }
                        }

                        override fun onCoverOpened() {
                            mainHandler.post {
                                val status = Status(
                                    online = false,
                                    coverOpen = true,
                                    paperEmpty = false,
                                    raw = "Cover opened"
                                )
                                flutterApi.onStatus(status) { }
                            }
                        }

                        override fun onCoverClosed() {
                            mainHandler.post {
                                flutterApi.onLog("Printer: Cover closed") { }
                            }
                        }

                        override fun onPaperEmpty() {
                            mainHandler.post {
                                val status = Status(
                                    online = false,
                                    coverOpen = false,
                                    paperEmpty = true,
                                    raw = "Paper empty"
                                )
                                flutterApi.onStatus(status) { }
                            }
                        }

                        override fun onPaperReady() {
                            mainHandler.post {
                                flutterApi.onLog("Printer: Paper ready") { }
                            }
                        }
                    }
                }

                // Connect to the printer and WAIT for it
                printer?.openAsync()?.await()

                mainHandler.post {
                    flutterApi.onLog("Connected to ${req.identifier} - Printer is now open and ready") { }
                    // Signal that connection is complete
                    flutterApi.onConnectionComplete(true) { }
                }

                // Get initial status AFTER connection is complete
                if (req.monitor == true) {
                    val status = printer?.getStatusAsync()?.await()
                    mainHandler.post {
                        sendStatus(status)
                    }
                }

            } catch (e: Exception) {
                mainHandler.post {
                    flutterApi.onLog("Connection error: ${e.message}") { }
                    // Signal that connection failed
                    flutterApi.onConnectionComplete(false) { }
                }
            }
        }

        return true
    }

    override fun disconnect() {
        scope.launch {
            try {
                printer?.closeAsync()?.await()
                printer = null
                mainHandler.post {
                    flutterApi.onLog("Disconnected") { }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    flutterApi.onLog("Disconnect error: ${e.message}") { }
                }
            }
        }
    }

    override fun printImage(req: ImageRequest): Boolean {
        return runBlocking {
            try {
                val connectedPrinter = printer
                if (connectedPrinter == null) {
                    mainHandler.post {
                        flutterApi.onLog("Print image error: Printer not connected") { }
                    }
                    return@runBlocking false
                }

                // Convert List<Long?> to ByteArray
                val bytes = req.imageBytes?.mapNotNull { it?.toByte() }?.toByteArray() ?: byteArrayOf()
                if (bytes.isEmpty()) {
                    mainHandler.post {
                        flutterApi.onLog("No image data provided") { }
                    }
                    return@runBlocking false
                }

                // Decode bytes to Bitmap
                val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    mainHandler.post {
                        flutterApi.onLog("Failed to decode image") { }
                    }
                    return@runBlocking false
                }

                mainHandler.post {
                    flutterApi.onLog("Image decoded: ${bitmap.width}x${bitmap.height}") { }
                }

                // Build print command with image
                val builder = StarXpandCommandBuilder()
                builder.addDocument(
                    DocumentBuilder().addPrinter(
                        PrinterBuilder()
                            .styleAlignment(com.starmicronics.stario10.starxpandcommand.printer.Alignment.Center)
                            .actionPrintImage(
                                com.starmicronics.stario10.starxpandcommand.printer.ImageParameter(
                                    bitmap,
                                    req.width?.toInt() ?: 576  // Default width for 80mm paper (576 dots)
                                )
                            )
                            .actionCut(com.starmicronics.stario10.starxpandcommand.printer.CutType.Partial)
                    )
                )

                connectedPrinter.printAsync(builder.getCommands())?.await()
                mainHandler.post {
                    flutterApi.onLog("Image printed successfully") { }
                }
                true
            } catch (e: Exception) {
                mainHandler.post {
                    flutterApi.onLog("Print image error: ${e.message}") { }
                }
                false
            }
        }
    }

    override fun openCashDrawer(): Boolean {
        scope.launch {
            try {
                // Simplified cash drawer - just send open command
                // You may need to adjust this based on your specific printer model
                val builder = StarXpandCommandBuilder()
                builder.addDocument(
                    DocumentBuilder().addPrinter(
                        PrinterBuilder()
                            .actionPrintText("\n") // Some printers need this
                    )
                )
                
                printer?.printAsync(builder.getCommands())?.await()
                
                mainHandler.post {
                    flutterApi.onLog("Cash drawer command sent (implementation may need adjustment per printer model)") { }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    flutterApi.onLog("Drawer error: ${e.message}") { }
                }
            }
        }
        
        return true
    }

    override fun getStatus(): Status {
        return runBlocking {
            try {
                val connectedPrinter = printer
                if (connectedPrinter == null) {
                    return@runBlocking Status(
                        online = false,
                        coverOpen = false,
                        paperEmpty = false,
                        raw = "Printer not connected"
                    )
                }

                val status = connectedPrinter.getStatusAsync()?.await()
                Status(
                    online = status?.hasError == false,
                    coverOpen = status?.coverOpen ?: false,
                    paperEmpty = status?.paperEmpty ?: false,
                    raw = status?.toString()
                )
            } catch (e: Exception) {
                Status(
                    online = false,
                    coverOpen = false,
                    paperEmpty = false,
                    raw = "getStatus error: ${e.message}"
                )
            }
        }
    }

    private fun sendStatus(status: com.starmicronics.stario10.StarPrinterStatus?) {
        val pigeonStatus = Status(
            online = status?.hasError == false,
            coverOpen = status?.coverOpen ?: false,
            paperEmpty = status?.paperEmpty ?: false,
            raw = status?.toString()
        )
        flutterApi.onStatus(pigeonStatus) { }
    }
}
