import AppKit
import CoreGraphics

private struct OutputOrigin: Codable {
    let uuid: String
    let x: Double
    let y: Double
}

final class DisplayLayoutManager {
    private let snapshotURL: URL
    private var original: OutputOrigin?
    var hasPendingRestore: Bool { original != nil }
    init(snapshotURL: URL) {
        self.snapshotURL=snapshotURL
        if let data=try? Data(contentsOf:snapshotURL) { original=try? JSONDecoder().decode(OutputOrigin.self,from:data) }
    }
    static func uuid(_ id:CGDirectDisplayID) -> String? {
        guard let uuid=CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(kCFAllocatorDefault,uuid) as String
    }
    func arrange(virtualIDs:[CGDirectDisplayID],output:CGDirectDisplayID) throws {
        var online=[CGDirectDisplayID](repeating:0,count:32),count:UInt32=0
        guard CGGetOnlineDisplayList(32,&online,&count) == .success,
              online.prefix(Int(count)).contains(output) else { throw failure(L("Lo schermo di uscita è scollegato")) }
        let ours=Set(virtualIDs)
        let physical=online.prefix(Int(count)).filter { !ours.contains($0) && $0 != output }
        let rightEdge=physical.map { CGDisplayBounds($0).maxX }.max() ?? 0
        if original == nil {
            guard let uuid=Self.uuid(output) else { throw failure(L("Impossibile riconoscere il display del visore")) }
            let origin=CGDisplayBounds(output).origin
            let snapshot=OutputOrigin(uuid:uuid,x:origin.x,y:origin.y)
            try FileManager.default.createDirectory(at:snapshotURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(snapshot).write(to:snapshotURL,options:.atomic)
            original=snapshot
        } else if original?.uuid != Self.uuid(output) {
            throw failure(L("Il layout del vecchio schermo di uscita non è ancora stato ripristinato; collega prima il dispositivo originale e ripristina il layout"))
        }
        var config:CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success,let config else { throw failure(L("Impossibile avviare la configurazione del layout dei display")) }
        var committed=false
        defer { if !committed { CGCancelDisplayConfiguration(config) } }
        // Adattato: togli ogni specchio tra occhiali e schermo del Mac, così il Mac resta un display
        // indipendente e usabile (non replica più quello che vedi negli occhiali).
        if CGDisplayMirrorsDisplay(output) != kCGNullDirectDisplay {
            CGConfigureDisplayMirrorOfDisplay(config,output,kCGNullDirectDisplay)
        }
        for screen in physical where CGDisplayMirrorsDisplay(screen) != kCGNullDirectDisplay {
            CGConfigureDisplayMirrorOfDisplay(config,screen,kCGNullDirectDisplay)
        }
        guard CGConfigureDisplayOrigin(config,output,Int32(rightEdge)+Int32(virtualIDs.count*1920),0) == .success else { throw failure(L("Configurazione della posizione dello schermo di uscita non riuscita")) }
        for (i,id) in virtualIDs.enumerated() {
            if CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay {
                let result = CGConfigureDisplayMirrorOfDisplay(config,id,kCGNullDirectDisplay)
                guard result == .success else { throw failure(LF("Disattivazione del mirroring dello schermo virtuale non riuscita (%d)", result.rawValue)) }
            }
            guard CGConfigureDisplayOrigin(config,id,Int32(rightEdge)+Int32(i*1920),0) == .success else { throw failure(L("Configurazione della posizione dello schermo virtuale non riuscita")) }
        }
        let result=CGCompleteDisplayConfiguration(config,.forSession)
        committed=true // Complete consumes the configuration, including on failure.
        guard result == .success else { throw failure(LF("Invio del layout non riuscito (%d)", result.rawValue)) }
    }
    @discardableResult func restore() -> String? {
        guard let original else { return nil }
        guard let screen=NSScreen.screens.first(where:{ screen in
            guard let number=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return Self.uuid(number.uint32Value) == original.uuid
        }),let number=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return L("Visore non collegato; il record di ripristino del layout è stato conservato, si riprova dopo la riconnessione")
        }
        var config:CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success,let config else { return L("Impossibile avviare il ripristino del layout; premi Ripristina layout per riprovare") }
        guard CGConfigureDisplayOrigin(config,number.uint32Value,Int32(original.x),Int32(original.y)) == .success else {
            CGCancelDisplayConfiguration(config);return L("Ripristino del layout non riuscito; premi Ripristina layout per riprovare")
        }
        let result=CGCompleteDisplayConfiguration(config,.forSession)
        guard result == .success else { return LF("Invio del ripristino del layout non riuscito (%d)", result.rawValue) }
        do { if FileManager.default.fileExists(atPath:snapshotURL.path) { try FileManager.default.removeItem(at:snapshotURL) } }
        catch { return LF("Layout ripristinato, ma la pulizia del record di ripristino non è riuscita: %@", error.localizedDescription) }
        self.original=nil;return nil
    }
    private func failure(_ message:String) -> NSError { NSError(domain:"RayNeo.Layout",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
}
