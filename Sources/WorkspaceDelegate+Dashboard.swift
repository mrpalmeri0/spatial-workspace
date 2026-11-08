import AppKit
import SwiftUI
import Combine
import SceneKit

@MainActor final class NativeWorkspaceModel: ObservableObject {
    weak var engine: WorkspaceDelegate?
    @Published var settings = WorkspaceSettings()
    @Published var status = L("Pronto per una nuova sessione")
    @Published var running = false
    @Published var starting = false
    @Published var stopping = false
    @Published var connected = false
    @Published var calibrated = false
    @Published var focus = false
    @Published var remoteEnabled = false
    @Published var remoteStatus = L("Condivisione disattivata")
    @Published var pairing = ""
    @Published var angle = 0.0
    @Published var monitors = 0
    func refresh() {
        guard let e = engine else { return }
        if settings != e.settings { settings = e.settings }
        if status != e.desktopStatus { status = e.desktopStatus }
        if starting != e.starting { starting = e.starting }
        let isStopping = e.stopTask != nil
        if stopping != isStopping { stopping = isStopping }
        let isRunning = !e.virtualDisplays.isEmpty
        if running != isRunning { running = isRunning }
        if monitors != e.virtualDisplays.count { monitors = e.virtualDisplays.count }
        if connected != e.tracker.connected { connected = e.tracker.connected }
        if calibrated != e.tracker.calibrated { calibrated = e.tracker.calibrated }
        if focus != e.tools.focusLocked { focus = e.tools.focusLocked }
        let degrees = e.tracker.angles[e.yawAxis] * 180 / .pi
        let displayAngle = degrees.isFinite ? (degrees * 10).rounded() / 10 : 0
        if angle != displayAngle { angle = displayAngle }
        if remoteEnabled != e.remoteHost.enabled { remoteEnabled = e.remoteHost.enabled }
        if remoteStatus != e.remoteHost.status { remoteStatus = e.remoteHost.status }
        if pairing != e.remoteHost.pairing { pairing = e.remoteHost.pairing }
    }
    func change<Value>(_ key: WritableKeyPath<WorkspaceSettings, Value>, _ value: Value) {
        guard let e = engine else { return }
        let previous = e.settings
        e.settings[keyPath: key] = value
        e.settings = e.settings.validated()
        guard e.settings != previous else { return }
        e.panelScale = Float(e.settings.scale)
        e.yawAxis = e.settings.yawAxis; e.direction = e.settings.direction
        if previous.yawAxis != e.settings.yawAxis || previous.direction != e.settings.direction {
            e.tracker.recenter()
        }
        if !e.settings.headTracking && !e.paused { e.camera.eulerAngles.y = 0 }
        e.recovery.automaticallyRecover = e.settings.automaticRecovery
        e.tracker.integrator.adaptiveBias = e.settings.adaptiveBias
        if previous.screenCount != e.settings.screenCount && e.virtualDisplays.isEmpty && !e.starting && e.stopTask == nil { e.rebuildPanels() }
        SpatialLayout.apply(panels: e.panels, settings: e.settings)
        if previous.background != e.settings.background { e.applyBackground() }
        e.updatePreview(); e.persistSettings(); refresh()
    }
    func binding<Value>(_ key: WritableKeyPath<WorkspaceSettings, Value>) -> Binding<Value> {
        Binding(get: { self.settings[keyPath: key] }, set: { self.change(key, $0) })
    }
    func preset(_ index: Int) {
        let button = NSButton(); button.tag = index; engine?.applyPreset(button); refresh()
    }
    func toggleRemote() { if remoteEnabled { engine?.remoteHost.stop() } else { engine?.remoteHost.start() }; refresh() }
}

extension WorkspaceDelegate {
    func buildControlWindow() {
        nativeModel.engine = self; nativeModel.refresh()
        controlWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1220, height: 860),
                                 styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                 backing: .buffered, defer: false)
        controlWindow.title = "Spatial Workspace"
        controlWindow.titlebarAppearsTransparent = true
        controlWindow.toolbarStyle = .unified
        controlWindow.contentMinSize = NSSize(width: 880, height: 620)
        controlWindow.setFrameAutosaveName("RayNeoNativeDashboard")
        controlWindow.isReleasedWhenClosed = false
        controlWindow.contentViewController = NSHostingController(rootView: NativeWorkspaceView(model: nativeModel))
        controlStatus = NSTextField(labelWithString: "")
    }
    func refreshDashboardStatus() { nativeModel.refresh() }
}

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case workspace = "Workspace", tools = "Strumenti", remote = "iPhone e remoto", advanced = "Impostazioni"
    var id: String { rawValue }
    var title: String { L(rawValue) }
    var icon: String {
        switch self { case .workspace: "vision.pro"; case .tools: "cursorarrow.motionlines"; case .remote: "iphone.and.arrow.right.inward"; case .advanced: "slider.horizontal.3" }
    }
}

private final class WorkspaceViewState: ObservableObject {
    @Published var section: WorkspaceSection? = .workspace
    @Published var live = false
}

private struct NativeWorkspaceView: View {
    @ObservedObject var model: NativeWorkspaceModel
    @StateObject private var state = WorkspaceViewState()
    private var section: WorkspaceSection? { state.section }
    private var live: Bool { state.live }
    @AppStorage("rayneo.liquidGlass") private var glass = true
    @AppStorage("spatial.language") private var language = "system"
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "vision.pro.fill")
                        .font(.title2).foregroundStyle(.indigo)
                        .frame(width: 40, height: 40)
                        .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Spatial").font(.title3.bold())
                        Text("WORKSPACE").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 28)
                List(selection: $state.section) {
                    Section(L("Il tuo spazio")) {
                        ForEach(WorkspaceSection.allCases) { item in
                            Label(item.title, systemImage: item.icon)
                                .padding(.vertical, 5).tag(item)
                        }
                    }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Circle().fill(model.connected ? Color.green : Color.secondary).frame(width: 7, height: 7)
                        Text(model.connected ? L("Visore collegato") : L("Collega il tuo visore")).font(.callout.weight(.medium))
                    }
                    Text(model.connected ? (model.calibrated ? L("Tracking pronto. Il tuo spazio ti aspetta.") : L("Tieni gli occhiali fermi per la calibrazione.")) : L("Collega gli occhiali via USB-C per iniziare la sessione."))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(16).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14)).padding(12)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch section ?? .workspace {
                case .workspace: workspace
                case .tools: tools
                case .remote: remote
                case .advanced: advanced
                }
            }
            .navigationTitle((section ?? .workspace).title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { sessionBar }
        }
        .tint(.indigo)
        .id(language)
    }
    private var sessionBusy: Bool { model.running || model.starting || model.stopping }
    private var sessionTitle: String {
        model.stopping ? L("Arresto in corso") : model.starting ? L("Preparazione dello spazio") : model.running ? L("Sessione attiva") : L("Il tuo prossimo spazio")
    }
    private var workspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(L("IL TUO DESKTOP, OLTRE LO SCHERMO"))
                            .font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary)
                        Text(L("Spazio alle tue idee.")).font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(L("Scegli un layout e trova la tua prospettiva.")).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    WorkspaceStatusPill(title: model.running ? L("Sessione attiva") : L("In configurazione"), icon: model.running ? "circle.fill" : "slider.horizontal.3", active: model.running)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L("Scegli il tuo spazio")).font(.headline)
                        Spacer()
                        if sessionBusy { Text(L("Layout bloccato durante la sessione")).font(.caption).foregroundStyle(.secondary) }
                    }
                    HStack(spacing: 12) {
                        preset(L("Cinema"), subtitle: L("Un solo schermo. Tutta la scena."), icon: "rectangle", index: 0)
                        preset(L("Doppio"), subtitle: L("Due prospettive, un solo flusso."), icon: "rectangle.split.2x1", index: 1)
                        preset(L("Trio"), subtitle: L("Tutto il tuo lavoro, intorno a te."), icon: "rectangle.split.3x1", index: 2)
                    }
                }
                previewCard
                layoutCard
            }
            .padding(28).frame(maxWidth: 1120).frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    private var previewCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(L("Il tuo spazio"), systemImage: "viewfinder").font(.headline)
                Spacer()
                Picker(L("Modalità anteprima"), selection: $state.live) {
                    Text(L("Layout 3D")).tag(false); Text(L("Vista live")).tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }.padding(18)
            ZStack {
                Color.black
                if let engine = model.engine {
                    WorkspaceScenePreview(engine: engine, live: live)
                }
                if live && (!model.running || model.starting || model.stopping) {
                    VStack(spacing: 12) {
                        Image(systemName: "vision.pro").font(.system(size: 36, weight: .light)).foregroundStyle(.white.opacity(0.8))
                        Text(model.starting ? L("Preparazione della vista live…") : L("La tua vista, in tempo reale"))
                            .font(.headline).foregroundStyle(.white)
                        Text(L("Avvia la sessione per vedere ciò che appare negli occhiali."))
                            .font(.callout).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.85))
                }
            }
            .aspectRatio(16.0 / 8.0, contentMode: .fit)
            .clipped()
            HStack(spacing: 18) {
                Label("\(model.settings.screenCount) monitor", systemImage: "display.2")
                Spacer()
                Label("\(model.angle, specifier: "%.1f")°", systemImage: "gyroscope")
                    .monospacedDigit().accessibilityLabel(L("Rotazione della testa") + ": " + String(format: "%.1f°", model.angle))
                Label(model.focus ? L("Focus bloccato") : L("Vista libera"), systemImage: model.focus ? "lock" : "viewfinder")
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 13)
        }.modifier(WorkspaceCard())
    }
    private var layoutCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(L("Su misura per te"), systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Picker("Monitor", selection: model.binding(\.screenCount)) {
                    ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.segmented).frame(width: 160).disabled(sessionBusy)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 24)], alignment: .leading, spacing: 18) {
                layoutSlider(L("Dimensione"), icon: "arrow.up.left.and.arrow.down.right", key: \.scale, range: 0.65...1.25, suffix: "×")
                layoutSlider(L("Distanza"), icon: "arrow.left.and.right", key: \.distance, range: 2...5, suffix: "")
                layoutSlider(L("Spaziatura"), icon: "rectangle.split.3x1", key: \.spacingDegrees, range: 18...65, suffix: "°")
                    .disabled(model.settings.screenCount == 1)
            }
            Divider()
            Toggle(isOn: model.binding(\.headTracking)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Segui il tuo sguardo")).font(.callout.weight(.medium))
                    Text(L("Muovi la testa per esplorare i monitor.")).font(.caption).foregroundStyle(.secondary)
                }
            }.toggleStyle(.switch)
        }.padding(20).modifier(WorkspaceCard())
    }
    private func layoutSlider(_ title: String, icon: String, key: WritableKeyPath<WorkspaceSettings, Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(model.settings[keyPath: key], specifier: "%.2f")\(suffix)")
                    .font(.callout.weight(.semibold)).monospacedDigit()
            }
            Slider(value: model.binding(key), in: range) { Text(title) }
                .labelsHidden().accessibilityLabel(title)
        }
    }
    private func preset(_ title: String, subtitle: String, icon: String, index: Int) -> some View {
        WorkspacePresetCard(title: title, subtitle: subtitle, icon: icon, count: index + 1,
                            selected: model.settings.screenCount == index + 1) { model.preset(index) }
            .disabled(sessionBusy)
    }
    private var sessionBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if model.starting || model.stopping { ProgressView().controlSize(.small) }
                else { Circle().fill(model.running ? Color.green : Color.indigo).frame(width: 7, height: 7) }
                Text(sessionTitle).font(.callout.weight(.semibold))
                Spacer()
                if !model.running && !model.starting { Text(L("⌘↵ per avviare")).font(.caption).foregroundStyle(.secondary) }
            }
            Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Button(model.starting ? L("Avvio…") : L("Avvia sessione"), systemImage: "play.fill") {
                    model.engine?.startDesktops(); model.refresh()
                }.modifier(WorkspacePrimaryButton(glass: glass))
                    .disabled(sessionBusy).keyboardShortcut(.return, modifiers: .command)
                Button(model.stopping ? L("Arresto…") : L("Ferma"), systemImage: "stop.fill") {
                    model.engine?.stopDesktops(); model.refresh()
                }.disabled(model.stopping || (!model.running && !model.starting))
                Spacer(minLength: 8)
                Button(L("Ricentra"), systemImage: "scope") { model.engine?.recenter(); model.refresh() }
                    .disabled(!model.running || model.starting || model.stopping).help(L("Centra di nuovo la vista negli occhiali"))
                Button(L("Pannello"), systemImage: "command") { model.engine?.tools.togglePanel() }
                    .disabled(!model.running || model.starting || model.stopping).help(L("Mostra i comandi rapidi nello spazio virtuale"))
            }.controlSize(.large).modifier(WorkspaceGlassButtons(enabled: glass))
        }.padding(.horizontal, 24).padding(.vertical, 16).background(.bar)
            .overlay(alignment: .top) { Divider() }
    }
    private var tools: some View {
        Form {
            Section {
                WorkspacePageHeading(title: L("A portata di sguardo"), subtitle: L("Cursore, finestre e comandi nel punto giusto."), icon: "cursorarrow.motionlines")
            }
            Section(L("Controlli nello spazio")) {
                tool(L("Portami il cursore"), subtitle: L("⌘⌥P · Puntatore al centro del monitor guardato"), icon: "cursorarrow") { model.engine?.tools.bringCursor() }
                tool(L("Radar dei monitor"), subtitle: L("⌘⌥M · Mostra sguardo e puntatore per quattro secondi"), icon: "map") { model.engine?.tools.showRadar() }
                tool(model.focus ? L("Sblocca Focus") : L("Blocca Focus"), subtitle: L("⌘⌥F · Centra il monitor guardato e sospende il tracking"), icon: "viewfinder") { model.engine?.tools.toggleFocus(); model.refresh() }
                tool(L("Pannello e tastiera"), subtitle: L("⌘⌥K · Tasti rapidi senza perdere il focus sul campo"), icon: "keyboard") { model.engine?.tools.togglePanel() }
            }.disabled(!model.running || model.starting || model.stopping)
            Section(L("Finestre")) {
                if model.monitors == 0 {
                    Label(L("Avvia una sessione per spostare le finestre sui monitor virtuali."), systemImage: "display.2")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(0..<model.monitors, id: \.self) { index in
                    Button(LF("Porta la finestra sul monitor %d · ⌘⌥%d", index + 1, index + 1)) { model.engine?.moveFocusedWindow(index) }
                }
                Button(L("Riporta la finestra sul Mac · ⌘⌥0")) { model.engine?.moveFocusedWindow(3) }
                Button(L("Ritrova le finestre della sessione precedente")) { model.engine?.tools.restoreWindows() }
                Text(L("Il recupero conserva le finestre delle app aperte durante arresto e riconnessione. Richiede Accessibilità.")).font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden).background(Color(nsColor: .windowBackgroundColor))
    }
    private var remote: some View {
        Form {
            Section {
                WorkspacePageHeading(title: L("Il tuo Mac, con te"), subtitle: L("Continua il tuo spazio di lavoro su iPhone."), icon: "iphone.and.arrow.right.inward")
            }
            Section(L("Il Mac, anche sul tuo iPhone")) {
                Label(L("Desktop remoto nativo"), systemImage: "desktopcomputer.and.arrow.down").font(.title2)
                Text(L("Collega iPhone e Mac alla stessa rete, oppure alla tua VPN privata. Gli occhiali si collegano all’iPhone via USB-C."))
                Button(model.remoteEnabled ? L("Disattiva condivisione") : L("Attiva condivisione")) { model.toggleRemote() }
                LabeledContent("Stato", value: model.remoteStatus)
                if !model.pairing.isEmpty {
                    Text(L("Codice di abbinamento")).font(.headline)
                    Text(model.pairing).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Button(L("Copia per iPhone"), systemImage: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.pairing, forType: .string) }
                    Text(L("Il codice concede accesso al desktop. Cambia a ogni nuova attivazione della condivisione.")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(L("Controllo")) {
                Text(L("Video H.264 1080p con obiettivo 30 fps, cambio monitor, trackpad, scorrimento, testo e tasti rapidi. Connessione cifrata TLS con chiave di abbinamento."))
                Button(L("Autorizza controllo del Mac")) { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) }
                Text(L("Il Mac resta sveglio durante una connessione. Il tracking testa su iPhone non è implementato; puoi cambiare monitor manualmente.")).font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden).background(Color(nsColor: .windowBackgroundColor))
    }
    private var advanced: some View {
        Form {
            Section {
                WorkspacePageHeading(title: L("La tua prospettiva"), subtitle: L("Aspetto, fluidità e tracking, come li preferisci."), icon: "slider.horizontal.3")
            }
            Section(L("Aspetto")) {
                Picker(L("Lingua"), selection: $language) {
                    Text(L("Sistema")).tag("system")
                    Text("English").tag("en")
                    Text("Italiano").tag("it")
                }
                Text(L("I controlli cambiano subito; riavvia l’app per aggiornare tutti i messaggi e i menu.")).font(.caption).foregroundStyle(.secondary)
                Toggle(L("Liquid Glass nei controlli"), isOn: $glass)
                Picker(L("Sfondo"), selection: model.binding(\.background)) {
                    Text(L("Nero")).tag(0); Text(L("Grigio")).tag(1); Text(L("Blu notte")).tag(2); Text(L("Sfumatura")).tag(3); Text(L("Immagine")).tag(4)
                }
                Button(L("Scegli immagine…")) { model.engine?.chooseBackgroundImage(); model.refresh() }
                adjustment(L("Luminosità"), key: \.brightness, range: 0.35...1, suffix: "")
                adjustment(L("Inclinazione"), key: \.tilt, range: -20...20, suffix: "°")
            }
            Section(L("Qualità e tracking")) {
                Picker(L("Frame cattura"), selection: model.binding(\.captureFPS)) { ForEach([15, 30, 60], id: \.self) { Text("\($0) fps").tag($0) } }
                Picker(L("Frame scena"), selection: model.binding(\.renderFPS)) { Text("30 fps").tag(30); Text("60 fps").tag(60) }
                Toggle(L("Texture GPU"), isOn: model.binding(\.useGPUTextures))
                Text(L("Frame e texture si applicano al prossimo avvio.")).font(.caption).foregroundStyle(.secondary)
                Picker(L("Asse"), selection: model.binding(\.yawAxis)) { Text("X").tag(0); Text("Y").tag(1); Text("Z").tag(2) }
                Picker(L("Direzione"), selection: model.binding(\.direction)) { Text(L("Normale")).tag(1.0); Text(L("Invertita")).tag(-1.0) }
                Toggle(L("Correzione deriva a riposo"), isOn: model.binding(\.adaptiveBias))
                Button(L("Ricalibra")) { model.engine?.recalibrate() }
            }
            Section(L("Sessione")) {
                Toggle(L("Riprendi dopo riconnessione"), isOn: model.binding(\.automaticRecovery))
                Toggle(L("Finestre di prova"), isOn: model.binding(\.showTestWindows))
                Button(L("Apri diagnostica")) { model.engine?.openDiagnostics() }
                Button(L("Test prestazioni")) { model.engine?.toggleBenchmark() }
                Button(L("Ripristina layout fisico")) { model.engine?.restoreLayout() }.disabled(model.running)
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden).background(Color(nsColor: .windowBackgroundColor))
    }
    private func tool(_ title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon).font(.title3).foregroundStyle(.indigo)
                .frame(width: 38, height: 38).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.callout.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
            Spacer(); Button(L("Esegui"), systemImage: "arrow.up.right", action: action).buttonStyle(.bordered)
        }
    }
    private func adjustment(_ title: String, key: WritableKeyPath<WorkspaceSettings, Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            Slider(value: model.binding(key), in: range)
            Text("\(model.settings[keyPath: key], specifier: "%.2f")\(suffix)").monospacedDigit().frame(width: 65, alignment: .trailing)
        }
    }
}
private struct WorkspacePageHeading: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 26, weight: .light)).foregroundStyle(.indigo)
                .frame(width: 56, height: 56).background(.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 12).accessibilityElement(children: .combine)
    }
}

private struct WorkspaceCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.07), lineWidth: 1) }
    }
}

private struct WorkspaceStatusPill: View {
    let title: String
    let icon: String
    let active: Bool
    var body: some View {
        Label(title, systemImage: icon).font(.caption.weight(.medium))
            .foregroundStyle(active ? Color.green : Color.secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background((active ? Color.green : Color.secondary).opacity(0.09), in: Capsule())
    }
}

private final class WorkspacePresetHover: ObservableObject {
    @Published var hovering = false
}

private struct WorkspacePresetCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let count: Int
    let selected: Bool
    let action: () -> Void
    @StateObject private var hover = WorkspacePresetHover()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).font(.system(size: 25, weight: .light))
                        .foregroundStyle(selected ? Color.indigo : Color.secondary)
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.indigo) }
                    else { Text("0\(count)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary) }
                }.frame(height: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        .frame(minHeight: 30, alignment: .top)
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? Color.indigo.opacity(0.10) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.indigo.opacity(0.6) : Color.primary.opacity(hover.hovering ? 0.22 : 0.07), lineWidth: 1) }
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).onHover { hover.hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hover.hovering)
            .accessibilityLabel("\(title), \(count) monitor")
            .accessibilityValue(selected ? L("Numero di monitor selezionato") : "")
            .help(LF("Applica il preset %@", title))
    }
}

private struct WorkspacePrimaryButton: ViewModifier {
    let glass: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if glass { content.buttonStyle(.glassProminent) }
        else { content.buttonStyle(.borderedProminent) }
    }
}

private struct WorkspaceGlassButtons: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { GlassEffectContainer { content.buttonStyle(.glass) } }
        else { content.buttonStyle(.bordered) }
    }
}
private struct WorkspaceScenePreview: NSViewRepresentable {
    let engine: WorkspaceDelegate
    let live: Bool
    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 450))
        engine.buildPreview(in: container); engine.buildGlassesPreview(in: container)
        return container
    }
    func updateNSView(_ view: NSView, context: Context) {
        engine.previewView?.isHidden = live
        engine.updateGlassesPreview()
    }
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        for view in nsView.subviews { (view as? SceneKit.SCNView)?.isPlaying = false }
    }
}
