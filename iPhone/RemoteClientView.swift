import SwiftUI

struct PhoneVideo: UIViewRepresentable {
    let client: RemoteClient
    func makeUIView(context: Context) -> RemoteVideoView { let view = RemoteVideoView(); client.register(view); return view }
    func updateUIView(_ view: RemoteVideoView, context: Context) {}
    static func dismantleUIView(_ view: RemoteVideoView, coordinator: ()) { view.displayLayer.flushAndRemoveImage() }
}
private final class ClientViewState: ObservableObject { @Published var keyboard = false }
struct RemoteClientView: View {
    @ObservedObject var client: RemoteClient
    @StateObject private var state = ClientViewState()
    @AppStorage("spatial.language") private var language = "system"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker(L("Lingua"), selection: $language) {
                        Text(L("Sistema")).tag("system"); Text("English").tag("en"); Text("Italiano").tag("it")
                    }
                    Label(L("Il tuo Mac, ovunque."), systemImage: "vision.pro").font(.title.bold())
                    Text(client.status).font(.subheadline).foregroundStyle(.secondary)
                    if !client.connected {
                        TextField(L("indirizzo:porta#codice"), text: $client.pairing)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        Button(client.connecting ? L("Connessione…") : L("Collega al Mac")) { client.connect() }
                            .buttonStyle(.borderedProminent).disabled(client.connecting)
                        Text(L("Sul Mac apri iPhone e remoto, attiva la condivisione e copia il codice. Usa la stessa rete Wi-Fi o una VPN privata."))
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        PhoneVideo(client: client).aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 16))
                        Picker("Monitor", selection: Binding(get: { client.selected }, set: { client.chooseDisplay($0) })) {
                            ForEach(Array(client.displays.enumerated()), id: \.offset) { index, name in Text(name).tag(index) }
                        }
                        Label(client.externalConnected ? L("Schermo esterno collegato") : L("Collega il visore all’iPhone via USB-C"), systemImage: "display")
                            .font(.caption).foregroundStyle(.secondary)
                        ZStack {
                            RemoteTrackpad(client: client)
                            VStack { Image(systemName: "hand.draw").font(.largeTitle); Text(L("Trackpad · due dita per scorrere")).font(.caption) }
                                .foregroundStyle(.secondary).allowsHitTesting(false)
                        }.frame(height: 200)
                        HStack {
                            ForEach(Array(zip(["Esc", "Tab", "↵", "←", "↑", "↓", "→"], [53, 48, 36, 123, 126, 125, 124])), id: \.0) { name, code in
                                Button(name) { client.key(code) }.frame(maxWidth: .infinity)
                            }
                        }.buttonStyle(.bordered)
                        Toggle(L("Tastiera software o Bluetooth"), isOn: $state.keyboard)
                        RemoteKeyboard(client: client, active: $state.keyboard).frame(height: 1).accessibilityLabel(L("Input tastiera remota"))
                        Button(L("Disconnetti"), role: .destructive) { state.keyboard = false; client.disconnect() }
                    }
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively)
            .id(language)
            .navigationTitle("Spatial Remote").navigationBarTitleDisplayMode(.inline)
        }
    }
}
