import AppKit
import SceneKit
import IOKit.hid
import ScreenCaptureKit
import CoreImage
import CoreMedia
import Carbon

@MainActor final class WorkspaceDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var view: WorkspaceView!
    var hud: NSTextField!
    let tracker = GTTracker()
    let camera = SCNNode()
    var timer: Timer?
    var yawAxis = 1
    var direction = 1.0
    var paused = false
    var controlWindow: NSWindow!
    var controlStatus: NSTextField!
    var dashboardTabs: NSTabView?
    var statusItem: NSStatusItem!
    var panels: [SCNNode] = []
    // Anteprima illustrativa per configurare la disposizione degli schermi.
    var previewView: SCNView?
    let previewCamera = SCNNode()
    var previewPanels: [SCNNode] = []
    var glassesPreviewView: SCNView?
    var glassesPreviewPlaceholder: NSTextField?
    var virtualDisplays: [CGVirtualDisplay] = []
    var captures: [DesktopCapture] = []
    var startupTask: Task<Void, Never>?
    var stopTask: Task<Void, Never>?
    var terminating = false
    var generation = 0
    var desktopStatus = L("Schermi virtuali indipendenti non ancora avviati")
    var starting = false
    var testWindows: [NSWindow] = []
    var lastTelemetry = 0.0
    var lastHUD = 0.0
    var panelScale: Float = 1.0
    let shortcuts = WindowShortcuts()
    let tools = WorkspaceTools()
    let nativeModel = NativeWorkspaceModel()
    let remoteHost = RemoteWorkspaceHost()
    var outputDisplayID: CGDirectDisplayID = 0
    var lastExternalPID: pid_t?
    let dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("RayNeoWorkspace-Dev", isDirectory: true)
    lazy var settingsStore = SettingsStore(url: dataDirectory.appendingPathComponent("settings.json"))
    lazy var layoutManager = DisplayLayoutManager(snapshotURL: dataDirectory.appendingPathComponent("pending-layout.json"))
    var settings = WorkspaceSettings()
    var recovery = RecoveryPolicy()
    var sleeping = false
    var lastHIDRetry = 0.0
    var lastRestoreAttempt = 0.0
    // Numero di schermi virtuali mostrati negli occhiali: scelto dall'utente (1, 2 o 3).
    var screenCount: Int { settings.screenCount }
    var retainedFrames: [CapturedFrame?] = []
    let diagnostics = RuntimeDiagnostics()
    let benchmark = BenchmarkController()
    var settingsControls: [String: NSControl] = [:]


    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = settingsStore.load()
        yawAxis = settings.yawAxis; direction = settings.direction; panelScale = Float(settings.scale)
        recovery.automaticallyRecover = settings.automaticRecovery
        tracker.integrator.adaptiveBias = settings.adaptiveBias
        let screen = findOutputScreen() ?? NSScreen.main ?? NSScreen.screens[0]
        outputDisplayID = findOutputScreen().flatMap(displayID) ?? 0
        NotificationCenter.default.addObserver(self, selector: #selector(updateOutputScreen), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        window.setFrame(screen.frame, display: true)
        // Cover the physical GT menu bar without hiding the Mac's own menu bar.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self
        window.ignoresMouseEvents = true
        window.title = L("Spatial Workspace — output occhiali")
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = container
        view = WorkspaceView(frame: container.bounds)
        view.autoresizingMask = [.width, .height]
        view.backgroundColor = NSColor(calibratedRed: 0.012, green: 0.018, blue: 0.028, alpha: 1)
        view.preferredFramesPerSecond = settings.renderFPS
        view.antialiasingMode = .multisampling4X
        view.isPlaying = false
        container.addSubview(view)
        let scene = SCNScene()
        view.scene = scene
        camera.camera = SCNCamera()
        camera.camera?.projectionDirection = .horizontal
        // Ogni schermo riempie bene l'inquadratura quando lo guardi; gli altri li raggiungi girando la testa.
        camera.camera?.fieldOfView = 52
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 50
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        rebuildPanels()
        applyBackground()
        hud = NSTextField(labelWithString: L("Inizializzazione"))
        hud.frame = NSRect(x: 24, y: 18, width: container.bounds.width - 48, height: 54)
        hud.autoresizingMask = [.width]
        hud.textColor = .white
        hud.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        hud.maximumNumberOfLines = 3
        container.addSubview(hud)
        shortcuts.requestMove = { [weak self] index in self?.moveFocusedWindow(index) }
        tools.engine = self
        shortcuts.requestAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case 0: self.tools.bringCursor()
            case 1: self.tools.showRadar()
            case 2: self.tools.togglePanel()
            default: self.tools.toggleFocus()
            }
        }
        shortcuts.install()
        view.handleKey = { [weak self] key in
            guard let self else { return }
            switch key {
            case "r": self.tracker.recenter()
            case "c": self.tracker.recalibrate()
            case " ": self.paused.toggle()
            case "f": self.direction *= -1; self.persistSettings()
            case "x": self.yawAxis = 0; self.tracker.recenter(); self.persistSettings()
            case "y": self.yawAxis = 1; self.tracker.recenter(); self.persistSettings()
            case "z": self.yawAxis = 2; self.tracker.recenter(); self.persistSettings()
            case "+", "=": self.changeScale(1)
            case "-": self.changeScale(-1)
            case "h": self.hud.isHidden.toggle()
            default: break
            }
        }
        // Non mostrare la finestra sugli occhiali all'avvio: resta nascosta finché una sessione non è pronta,
        // così il Mac non lampeggia nero mentre gli schermi vengono creati.
        window.makeFirstResponder(view)
        createControls()
        NSApp.activate(ignoringOtherApps: true)
        tracker.onConnectionChanged = { [weak self] connected in
            guard let self, !self.terminating else { return }
            if !connected && !self.sleeping {
                self.recovery.interrupted()
                self.beginStopping(message: L("GT scollegati, in attesa di riconnessione"))
            }
        }
        tracker.start()
        updateOutputScreen()
        if layoutManager.hasPendingRestore, let message = layoutManager.restore() { desktopStatus = message }

        timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.update() } }
        RunLoop.main.add(timer!, forMode: .common)
    }
    @objc func showControls() {
        guard !CommandLine.arguments.contains("--render-controls"), controlWindow != nil else { return }
        // Always recover onto the Mac, including after display reconfiguration or minimization.
        if let screen = NSScreen.screens.first(where: { displayID($0).map { CGDisplayIsBuiltin($0) != 0 } ?? false }) ?? NSScreen.screens.first(where: { displayID($0) != outputDisplayID && !virtualDisplays.map(\.displayID).contains(displayID($0) ?? 0) }) {
            let frame = screen.visibleFrame
            let size = controlWindow.frame.size
            controlWindow.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                                y: max(frame.minY, frame.midY - size.height / 2)))
        }
        if controlWindow.isMiniaturized { controlWindow.deminiaturize(nil) }
        controlWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControls()
        return false
    }
    @objc func recenter() { if tools.focusLocked { tools.toggleFocus() }; tracker.recenter() }
    @objc func smallerPanel() { changeScale(-1) }
    @objc func largerPanel() { changeScale(1) }
    @objc func toggleStatus() { hud.isHidden.toggle() }
    func changeScale(_ direction: Float) {
        panelScale = min(max(panelScale + direction * 0.05, 0.65), 1.25)
        settings.scale = Double(panelScale)
        SpatialLayout.apply(panels: panels, settings: settings)
        updatePreview(); persistSettings(); syncSettingsControls()
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func moveWindowButton(_ sender: NSButton) { moveFocusedWindow(sender.tag) }
    func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
    func findOutputScreen() -> NSScreen? {
        // Adattato: usa qualsiasi schermo esterno (non il display del Mac e non i nostri schermi virtuali),
        // così funziona con occhiali di qualunque nome, non solo quelli chiamati "smartglasses".
        let virtualIDs = Set(virtualDisplays.map { $0.displayID })
        // Preferisci un display che si chiami esplicitamente occhiali, altrimenti il primo esterno disponibile.
        let externals = NSScreen.screens.filter { screen in
            guard let id = displayID(screen) else { return false }
            return CGDisplayIsBuiltin(id) == 0 && !virtualIDs.contains(id)
        }
        return externals.first { $0.localizedName.lowercased().contains("smartglasses") || $0.localizedName.lowercased().contains("rayneo") }
            ?? externals.first
    }
    @objc func updateOutputScreen() {
        guard !terminating else { return }
        guard !sleeping, let screen = findOutputScreen(), let id = displayID(screen) else {
            let wasConnected = outputDisplayID != 0
            outputDisplayID = 0
            window?.orderOut(nil)
            if wasConnected && (!virtualDisplays.isEmpty || starting) {
                recovery.interrupted()
                beginStopping(message: L("Uscita visore scollegata, in attesa di riconnessione"))
            }
            return
        }
        if outputDisplayID != 0 && outputDisplayID != id && (!virtualDisplays.isEmpty || starting) {
            recovery.interrupted()
            beginStopping(message: L("Il display del visore è cambiato, ricostruzione della sessione in corso"))
        }
        outputDisplayID = id
        window?.setFrame(screen.frame, display: true)
        // Mostra la finestra sugli occhiali solo quando una sessione è attiva (schermi pronti), mai prima.
        if !virtualDisplays.isEmpty { window?.orderFront(nil) }
    }
    @objc func willSleep() {
        sleeping = true; recovery.sleeping = true; recovery.interrupted()
        tracker.stop(); benchmark.stop()
        beginStopping(message: L("In pausa, ripresa dopo il risveglio"))
        window?.orderOut(nil)
    }
    @objc func didWake() {
        guard !terminating else { return }
        sleeping = false; recovery.sleeping = false
        tracker.start(); updateOutputScreen()
        desktopStatus = L("Sistema risvegliato, in attesa che visore e desktop siano pronti")
    }
    @objc func startDesktops() {
        guard stopTask == nil, !terminating else { return }
        recovery.requestStart()
        startSession()
    }
    func startSession() {
        guard !terminating, stopTask == nil, !starting, virtualDisplays.isEmpty else { return }
        // Adattato: non serve più il sensore di movimento. Basta che gli occhiali siano collegati come schermo.
        guard !sleeping, outputDisplayID != 0 else {
            desktopStatus = L("In attesa del display degli occhiali. Collega gli occhiali al Mac come schermo e premi Avvia."); return
        }
        guard CGPreflightScreenCaptureAccess() else {
            recovery.failed = true

            _ = CGRequestScreenCaptureAccess()
            desktopStatus = L("Consenti Spatial Workspace in Impostazioni di Sistema → Privacy e sicurezza → Registrazione schermo e audio di sistema. Se il sistema lo richiede, esci e riapri l'app, poi premi Avvia.")
            controlStatus.stringValue = desktopStatus
            return
        }
        guard NSClassFromString("CGVirtualDisplay") != nil else {
            recovery.failed = true
            desktopStatus = L("Il sistema non offre alcuna interfaccia per i display virtuali"); return
        }
        view.preferredFramesPerSecond = settings.renderFPS
        starting = true; generation += 1
        let ticket = generation
        let sessionSettings = settings
        desktopStatus = LF("Creazione di %d desktop indipendenti…", screenCount)
        startupTask = Task { @MainActor [self] in
            do {
                for (i, name) in (0..<screenCount).map({ "Spatial \($0 + 1)" }).enumerated() {
                    let descriptor = CGVirtualDisplayDescriptor()
                    descriptor.name = name; descriptor.maxPixelsWide = 1920; descriptor.maxPixelsHigh = 1080
                    descriptor.sizeInMillimeters = CGSize(width: 530, height: 298)
                    descriptor.vendorID = 0xC0D3; descriptor.productID = 0x4754; descriptor.serialNum = UInt32(1001+i)
                    descriptor.setDispatchQueue(.main)
                    guard let display = CGVirtualDisplay(descriptor: descriptor) else { throw NSError(domain: "RayNeo", code: 1, userInfo: [NSLocalizedDescriptionKey: LF("Creazione di %@ non riuscita", name)]) }
                    let settings = CGVirtualDisplaySettings(); settings.hiDPI = 0
                    settings.modes = [CGVirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60)]
                    guard display.apply(settings) else { throw NSError(domain: "RayNeo", code: 2, userInfo: [NSLocalizedDescriptionKey: L("Impostazione della modalità dello schermo virtuale non riuscita")]) }
                    virtualDisplays.append(display)
                }
                try await waitForDesktopScreens()
                guard generation == ticket else { return }
                let layoutDeadline = ProcessInfo.processInfo.systemUptime + 8
                while true {
                    try Task.checkCancellation()
                    do { try arrangeDesktops(); break }
                    catch {
                        guard ProcessInfo.processInfo.systemUptime < layoutDeadline else { throw error }
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
                try await waitForDesktopScreens(requireExtendedLayout: true)
                guard generation == ticket else { return }
                updateOutputScreen()
                view.isPlaying = true
                desktopStatus = L("Desktop indipendenti registrati, avvio delle catture…")
                let content = try await AsyncDeadline.run(seconds: 8, label: L("enumerazione schermi da catturare")) {
                    while true {
                        try Task.checkCancellation()
                        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                        if self.virtualDisplays.allSatisfy({ virtual in content.displays.contains { $0.displayID == virtual.displayID } }) { return content }
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
                guard generation == ticket, !Task.isCancelled else { return }
                for (index, virtual) in virtualDisplays.enumerated() {
                    guard generation == ticket else { return }
                    guard let display = content.displays.first(where: { $0.displayID == virtual.displayID }) else {
                        throw NSError(domain: "RayNeo", code: 3, userInfo: [NSLocalizedDescriptionKey: L("La cattura schermo non ha riconosciuto gli schermi virtuali")])
                    }
                    let capture = DesktopCapture(settings: sessionSettings, device: view.device)
                    capture.onFrame = { [weak self] image in
                        guard let self, self.generation == ticket else { return }
                        self.retainedFrames[index] = image
                        self.panels[index].geometry?.firstMaterial?.diffuse.contents = image.contents
                    }
                    capture.onError = { [weak self] error in
                        guard let self, self.generation == ticket else { return }
                        self.recovery.startFailed(now: ProcessInfo.processInfo.systemUptime)
                        self.beginStopping(message: LF("Cattura interrotta: %@; verrà tentato il ripristino secondo le impostazioni", error))
                    }
                    captures.append(capture)
                    try await AsyncDeadline.run(seconds: 8, label: L("avvio cattura")) { try await capture.start(display) }
                    guard generation == ticket, !Task.isCancelled else { return }
                }
                // Create content after capture starts so all three streams receive a fresh desktop update.
                if sessionSettings.showTestWindows { createTestWindows() }
                desktopStatus = LF("In attesa del primo frame dei %d desktop…", screenCount)
                try await StartupReadiness.wait(seconds: 8, label: LF("primo frame dei %d desktop", screenCount)) {
                    self.captures.count == self.screenCount && self.captures.allSatisfy { $0.frames > 0 }
                }
                guard generation == ticket, !Task.isCancelled else { return }
                desktopStatus = LF("%d schermi affiancati avviati. Porta il mouse oltre il bordo destro del Mac per raggiungerli e trascinarci le finestre.", screenCount)
                panels.forEach { $0.isHidden = false }
                window.orderFront(nil)
                view.isPlaying = true
                hud.isHidden = tracker.calibrated
                starting = false
                recovery.succeeded()
                tools.restoreWindows()
                showControls()
            } catch {
                guard generation == ticket else { return }
                let message = error.localizedDescription
                recovery.startFailed(now: ProcessInfo.processInfo.systemUptime)
                beginStopping(message: LF("Avvio non riuscito: %@", message))
            }
        }
    }
    func waitForDesktopScreens(requireExtendedLayout: Bool = false) async throws {
        let ids = virtualDisplays.map(\.displayID)
        try await StartupReadiness.wait(seconds: 8, label: L("registrazione dei desktop indipendenti"), stableSeconds: 0.5) {
            let screens = NSScreen.screens
            return ids.count == self.screenCount && ids.allSatisfy { id in
                guard CGDisplayIsOnline(id) != 0, CGDisplayIsActive(id) != 0 else { return false }
                // Mirrored displays can be online before AppKit exposes separate NSScreens.
                guard requireExtendedLayout else { return true }
                guard let screen = screens.first(where: { self.displayID($0) == id }), screen.frame.width > 0 else { return false }
                return CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay &&
                    abs(screen.frame.minX - CGDisplayBounds(id).minX) < 1
            } && (!requireExtendedLayout || Set(ids.map { Int(CGDisplayBounds($0).minX) }).count == self.screenCount)
        }
    }
    func arrangeDesktops() throws {
        try layoutManager.arrange(virtualIDs: virtualDisplays.map { $0.displayID }, output: outputDisplayID)
    }
    @objc func restoreLayout() {
        guard virtualDisplays.isEmpty, stopTask == nil else {
            desktopStatus = L("Ferma prima gli schermi, poi ripristina il layout"); return
        }
        desktopStatus = layoutManager.restore() ?? L("Layout del visore ripristinato")
    }
    @objc func stopDesktops() {
        recovery.requestStop()
        benchmark.stop()
        beginStopping(message: L("Gli schermi virtuali sono stati rimossi; puoi riavviare"))
    }
    func beginStopping(message: String) {
        guard stopTask == nil else { return }
        tools.stop()
        generation += 1
        starting = false
        let pendingStart = startupTask
        pendingStart?.cancel()
        captures.forEach { $0.invalidate() }
        desktopStatus = L("Arresto della cattura e ripristino del layout dei desktop…")
        stopTask = Task { @MainActor [self] in
            // A pending startCapture must finish before stopCapture and display release.
            var errors: [String] = []
            if let pendingStart {
                do { try await AsyncDeadline.run(seconds: 2, label: L("attesa annullamento avvio")) { await pendingStart.value } }
                catch { errors.append(error.localizedDescription) }
            }
            startupTask = nil
            let old = captures
            old.forEach { $0.invalidate() }
            for capture in old {
                if let error = await capture.stop() { errors.append(error) }
            }
            captures.removeAll()
            if let error = layoutManager.restore() { errors.append(error) }
            testWindows.forEach { $0.close() }; testWindows.removeAll()
            virtualDisplays.removeAll()
            panels.forEach {
                $0.isHidden = true
                $0.geometry?.firstMaterial?.diffuse.contents = NSColor.black
            }
            retainedFrames = Array(repeating: nil, count: screenCount)
            benchmark.stop()
            view?.isPlaying = false
            // Nascondi la finestra sugli occhiali quando gli schermi si fermano: niente nero residuo.
            window?.orderOut(nil)
            hud?.isHidden = false
            desktopStatus = message
            if !errors.isEmpty { desktopStatus += L("; note di pulizia: ") + errors.joined(separator: " / ") }
            stopTask = nil
        }
    }
    func createTestWindows() {
        for (index, display) in virtualDisplays.enumerated() {
            guard let screen = NSScreen.screens.first(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID
            }) else { continue }
            let name = LF("Schermo %d", index + 1)
            let test = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
                                styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false, screen: screen)
            test.isReleasedWhenClosed = false
            test.title = LF("Spatial %@ · test desktop indipendente", name)
            test.setFrameOrigin(NSPoint(x: screen.frame.midX - 600, y: screen.frame.midY - 380))
            let scroll = NSScrollView(frame: test.contentView!.bounds)
            scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true
            let editor = NSTextView(frame: scroll.bounds)
            editor.isEditable = true; editor.isRichText = false
            editor.font = .monospacedSystemFont(ofSize: 28, weight: .regular)
            editor.textContainerInset = NSSize(width: 24, height: 24)
            editor.autoresizingMask = [.width, .height]
            editor.string = name + "\n\n" + L("Questo è un desktop virtuale macOS indipendente. Puoi modificare questo testo o trascinare qui browser, editor e terminale. La finestra è contenuto di prova e si può chiudere. Per il tracking GT usa Follow e Ricentra.")
            scroll.documentView = editor; test.contentView?.addSubview(scroll)
            test.orderFront(nil); testWindows.append(test)
        }
    }
    func update() {
        let uptime = ProcessInfo.processInfo.systemUptime
        if !sleeping && !terminating && uptime - lastHIDRetry > 3 {
            lastHIDRetry = uptime; tracker.retryConnection()
        }
        if !terminating && !sleeping && stopTask == nil && virtualDisplays.isEmpty {
            if layoutManager.hasPendingRestore && uptime - lastRestoreAttempt > 3 {
                lastRestoreAttempt = uptime
                if let message = layoutManager.restore() { desktopStatus = message }
            }
            if recovery.shouldResume(now: uptime, ready: outputDisplayID != 0 && tracker.connected, idle: !starting) {
                startSession()
            }
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier { lastExternalPID = front.processIdentifier }
        if !paused {
            // Se il tracking è attivo, la camera segue la testa; altrimenti resta centrata (schermi fissi).
            camera.eulerAngles.y = settings.headTracking ? CGFloat(direction * tracker.angles[yawAxis]) : 0
        }
        updateGlassesPreview()
        tools.updateRadar()
        if uptime - lastHUD >= 0.25 {
            lastHUD = uptime
            let axis = ["X", "Y", "Z"][yawAxis]
            hud.stringValue = "\(tracker.status) · \(L("campioni")) \(tracker.samples) · Yaw \(axis)\(direction > 0 ? "+" : "−")\(paused ? L(" · in pausa") : "")\n\(desktopStatus)"
            refreshDashboardStatus()
        }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTelemetry >= 1 {
            lastTelemetry = now
            var status: [String: Any] = ["status": desktopStatus, "imuSamples": tracker.samples,
                                       "virtualIDs": virtualDisplays.map { $0.displayID },
                                       "captureFrames": captures.map { $0.frames }, "inputMode": "native", "displayBounds": virtualDisplays.map { NSStringFromRect(CGDisplayBounds($0.displayID)) }]
            status["version"] = "0.10.1-dev"
            status["sessionState"] = stopTask != nil ? "stopping" : starting ? "starting" : virtualDisplays.isEmpty ? "idle" : "running"
            status["recovery"] = ["wanted": recovery.wantsSession, "sleeping": sleeping, "attempts": recovery.attempts, "failed": recovery.failed]
            status["capture"] = captures.map { ["frames": $0.frames, "mergedFrames": $0.dropped, "gpuFrames": $0.gpuFrames, "fallbackFrames": $0.fallbackFrames, "deliveryMS": $0.deliveryMS, "sourceAgeMS": $0.sourceAgeMS] as [String: Any] }
            status["imu"] = ["biasDPS": tracker.integrator.bias, "stationarySeconds": tracker.integrator.stationarySeconds, "rejectedGaps": tracker.integrator.rejectedGaps, "temperature": tracker.integrator.temperature, "yawDegrees": tracker.angles[yawAxis] * 180 / .pi]
            status["tracking"] = ["calibrated": tracker.calibrated, "status": tracker.status,
                                  "rawGyroDPS": tracker.integrator.lastGyroDPS,
                                  "calibrationVariance": tracker.integrator.calibrationVariance,
                                  "angles": tracker.angles, "axis": yawAxis, "paused": paused]
            status["process"] = diagnostics.sample()
            if let data = try? JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys]) {
                do {
                    try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
                    try data.write(to: dataDirectory.appendingPathComponent("runtime-status.json"), options: .atomic)
                } catch { diagnostics.lastError = error.localizedDescription }
            }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        remoteHost.stop()
        recovery.requestStop()
        benchmark.stop()
        beginStopping(message: L("Uscita in corso"))
        let cleanup = stopTask
        Task { @MainActor [self] in
            await cleanup?.value
            tracker.stop()
            timer?.invalidate()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        tracker.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
