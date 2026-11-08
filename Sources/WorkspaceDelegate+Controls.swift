import AppKit
import UniformTypeIdentifiers

extension WorkspaceDelegate {
    func createControls() {
        let menu = NSMenu(), appMenu = NSMenu()
        let controlsItem = NSMenuItem(title:L("Mostra pannello di controllo"),action:#selector(showControls),keyEquivalent:"0")
        controlsItem.target=self;appMenu.addItem(controlsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle:L("Esci da Spatial Workspace"),action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        let item=NSMenuItem();item.submenu=appMenu;menu.addItem(item);NSApp.mainMenu=menu
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        statusItem.button?.title=L("Schermi")
        let statusMenu=NSMenu()
        for (title,action) in [(L("Mostra pannello di controllo"),#selector(showControls)),(L("Ferma gli schermi"),#selector(stopDesktops)),(L("Ripristina layout"),#selector(restoreLayout)),(L("Pannello rapido · ⌘⌥K"),#selector(showQuickPanel)),(L("Portami il cursore · ⌘⌥P"),#selector(bringGazeCursor)),("Radar · ⌘⌥M",#selector(showMonitorRadar))] {
            let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self;statusMenu.addItem(item)
        }
        statusMenu.addItem(.separator())
        statusMenu.addItem(withTitle:L("Esci"),action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        statusItem.menu=statusMenu

        buildControlWindow()
        showControls()
    }

    @objc func showQuickPanel() { tools.togglePanel() }
    @objc func bringGazeCursor() { tools.bringCursor() }
    @objc func showMonitorRadar() { tools.showRadar() }

    func persistSettings() {
        settings.yawAxis=yawAxis;settings.direction=direction;settings.scale=Double(panelScale)
        settings=settings.validated()
        do { try settingsStore.save(settings) }
        catch { desktopStatus=LF("Salvataggio impostazioni non riuscito: %@", error.localizedDescription) }
    }
    func syncSettingsControls() {
        (settingsControls["scale"] as? NSSlider)?.doubleValue=settings.scale
        (settingsControls["distance"] as? NSSlider)?.doubleValue=settings.distance
        (settingsControls["spacing"] as? NSSlider)?.doubleValue=settings.spacingDegrees
        let values = [
            "scale": String(format: "%.0f%%", settings.scale * 100),
            "distance": String(format: "%.1f", settings.distance),
            "spacing": String(format: "%.0f°", settings.spacingDegrees),
            "brightness": String(format: "%.0f%%", settings.brightness * 100),
            "tilt": String(format: "%.0f°", settings.tilt)
        ]
        for (key, value) in values {
            (settingsControls[key + "Label"] as? NSTextField)?.stringValue = value
        }
        (settingsControls["brightness"] as? NSSlider)?.doubleValue=settings.brightness
        (settingsControls["tilt"] as? NSSlider)?.doubleValue=settings.tilt
        (settingsControls["quality"] as? NSPopUpButton)?.selectItem(at:settings.captureFPS==15 ? 0 : settings.captureFPS==60 ? 2 : 1)
        (settingsControls["texture"] as? NSPopUpButton)?.selectItem(at:settings.useGPUTextures ? 0 : 1)
        (settingsControls["axis"] as? NSPopUpButton)?.selectItem(at:yawAxis)
        (settingsControls["direction"] as? NSButton)?.state=direction<0 ? .on : .off
        (settingsControls["recovery"] as? NSButton)?.state=settings.automaticRecovery ? .on : .off
        (settingsControls["bias"] as? NSButton)?.state=settings.adaptiveBias ? .on : .off
        (settingsControls["testWindows"] as? NSButton)?.state=settings.showTestWindows ? .on : .off
        (settingsControls["screens"] as? NSPopUpButton)?.selectItem(at:min(max(settings.screenCount-1,0),2))
        (settingsControls["headTracking"] as? NSButton)?.state=settings.headTracking ? .on : .off
        (settingsControls["background"] as? NSPopUpButton)?.selectItem(at: settings.background)
        settingsControls["spacing"]?.isEnabled = settings.screenCount > 1
        (settingsControls["previewCount"] as? NSTextField)?.stringValue =
            settings.screenCount == 1 ? L("1 SCHERMO") : LF("%d SCHERMI", settings.screenCount)
    }
    @objc func changeLayout(_ sender:NSSlider) {
        switch sender.identifier?.rawValue {
        case "scale":settings.scale=sender.doubleValue;panelScale=Float(settings.scale)
        case "distance":settings.distance=sender.doubleValue
        case "spacing":settings.spacingDegrees=sender.doubleValue
        case "brightness":settings.brightness=sender.doubleValue
        case "tilt":settings.tilt=sender.doubleValue
        default:return
        }
        SpatialLayout.apply(panels:panels,settings:settings);updatePreview();persistSettings();syncSettingsControls()
    }
    @objc func changeQuality(_ sender:NSPopUpButton) {
        settings.captureFPS=[15,30,60][sender.indexOfSelectedItem];settings.renderFPS=sender.indexOfSelectedItem==0 ? 30 : 60
        persistSettings();desktopStatus=L("Fluidità salvata; attiva al prossimo avvio degli schermi")
    }
    @objc func changeTexture(_ sender:NSPopUpButton) {
        settings.useGPUTextures=sender.indexOfSelectedItem==0;persistSettings();desktopStatus=L("Resa immagine salvata; attiva al prossimo avvio degli schermi")
    }
    @objc func changeAxis(_ sender:NSPopUpButton) { yawAxis=sender.indexOfSelectedItem;tracker.recenter();persistSettings() }
    @objc func changeDirection(_ sender:NSButton) { direction=sender.state == .on ? -1 : 1;tracker.recenter();persistSettings() }
    @objc func changeOption(_ sender:NSButton) {
        let enabled=sender.state == .on
        switch sender.identifier?.rawValue {
        case "recovery":settings.automaticRecovery=enabled;recovery.automaticallyRecover=enabled
        case "bias":settings.adaptiveBias=enabled;tracker.integrator.adaptiveBias=enabled
        case "testWindows":settings.showTestWindows=enabled
        default:return
        }
        persistSettings()
    }
    @objc func changeScreenCount(_ sender:NSPopUpButton) {
        settings.screenCount=sender.indexOfSelectedItem+1
        persistSettings()
        updatePreview()
        syncSettingsControls()
        guard virtualDisplays.isEmpty, stopTask==nil, !starting else {
            desktopStatus=L("Anteprima aggiornata. Ferma gli schermi e riavvia per applicarlo davvero."); return
        }
        rebuildPanels()
        desktopStatus=LF("Numero di schermi: %d. Premi Avvia.", settings.screenCount)
    }
    @objc func changeHeadTracking(_ sender:NSButton) {
        settings.headTracking=sender.state == .on
        persistSettings()
        if !settings.headTracking { camera.eulerAngles.y=0 }
    }
    @objc func applyPreset(_ sender:NSButton) {
        switch sender.tag {
        case 0: // Cinema: un solo schermo grande dritto davanti
            settings.screenCount=1;settings.scale=1.2;settings.distance=3.2;settings.spacingDegrees=40;settings.tilt=0;settings.brightness=1.0;settings.headTracking=false
        case 1: // Doppio: due schermi vicini, leggermente inclinati
            settings.screenCount=2;settings.scale=1.0;settings.distance=3.0;settings.spacingDegrees=30;settings.tilt=3;settings.brightness=1.0;settings.headTracking=true
        default: // Trio: tre schermi a ventaglio
            settings.screenCount=3;settings.scale=0.95;settings.distance=3.3;settings.spacingDegrees=42;settings.tilt=4;settings.brightness=1.0;settings.headTracking=true
        }
        settings=settings.validated();panelScale=Float(settings.scale)
        persistSettings()
        if virtualDisplays.isEmpty && stopTask==nil && !starting { rebuildPanels() }
        applyBackground();updatePreview();syncSettingsControls()
        if !settings.headTracking { camera.eulerAngles.y=0 }
        desktopStatus = virtualDisplays.isEmpty ? L("Preset applicato. Premi Avvia.") : L("Preset applicato; ferma e riavvia per cambiare il numero di schermi.")
    }
    @objc func changeBackground(_ sender:NSPopUpButton) {
        settings.background=sender.indexOfSelectedItem
        persistSettings()
        applyBackground()
        updatePreview()
        if settings.background==4 && settings.backgroundImagePath.isEmpty { chooseBackgroundImage() }
    }
    @objc func chooseBackgroundImage() {
        let panel=NSOpenPanel()
        panel.allowedContentTypes=[.image]
        panel.canChooseFiles=true;panel.canChooseDirectories=false;panel.allowsMultipleSelection=false
        panel.message=L("Scegli un'immagine di sfondo")
        NSApp.activate(ignoringOtherApps:true)
        if panel.runModal() == .OK, let url=panel.url {
            settings.backgroundImagePath=url.path
            settings.background=4
            persistSettings()
            applyBackground()
            updatePreview()
            syncSettingsControls()
            desktopStatus=L("Sfondo impostato sull'immagine scelta.")
        }
    }
    @objc func resetSettings() {
        let keptBackgroundPath=settings.backgroundImagePath
        settings=WorkspaceSettings();settings.backgroundImagePath=keptBackgroundPath
        yawAxis=settings.yawAxis;direction=settings.direction;panelScale=Float(settings.scale)
        recovery.automaticallyRecover=settings.automaticRecovery;tracker.integrator.adaptiveBias=settings.adaptiveBias
        rebuildPanels();applyBackground();updatePreview()
        SpatialLayout.apply(panels:panels,settings:settings);persistSettings();syncSettingsControls()
        desktopStatus=L("Impostazioni predefinite ripristinate; fluidità e resa saranno attive al prossimo avvio")
    }
    @objc func recalibrate() { tracker.recalibrate();desktopStatus=L("Tieni gli occhiali fermi: nuova stima della deriva in corso") }
    @objc func openDiagnostics() {
        try? FileManager.default.createDirectory(at:dataDirectory,withIntermediateDirectories:true)
        NSWorkspace.shared.open(dataDirectory)
    }
    @objc func toggleBenchmark() {
        guard !starting,stopTask==nil,virtualDisplays.count==screenCount else { desktopStatus=L("Avvia prima gli schermi, poi esegui il test prestazioni");return }
        if benchmark.running { benchmark.stop();desktopStatus=L("Contenuto dinamico del test prestazioni fermato") }
        else { benchmark.start(displayIDs:virtualDisplays.map { $0.displayID });desktopStatus=L("Contenuto dinamico avviato; clicca di nuovo Test per fermarlo") }
    }
}
