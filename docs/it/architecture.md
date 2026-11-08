# Architettura

[English](../en/architecture.md) · [README](../../README.it.md)

| Livello | Sorgenti | Responsabilità |
| --- | --- | --- |
| Lifecycle Mac | `Sources/WorkspaceDelegate*.swift`, `main.swift` | Avvio/pulizia sessione, layout uscita, UI nativa e anteprima |
| Pipeline display | `DesktopCapture.swift`, `WorkspaceView.swift`, `SpatialLayout.swift` | ScreenCaptureKit, Metal/Core Image e pannelli SceneKit |
| Tracking GT | `GTTracker.swift`, `GyroIntegrator.swift` | Protocollo HID specifico, stima bias e integrazione angolare |
| Strumenti | `WorkspaceTools.swift`, `WindowShortcuts.swift`, `MonitorTarget.swift` | Azioni esplicite su cursore/finestre/tasti e selezione monitor |
| Host remoto | `RemoteWorkspaceHost.swift`, `RemoteVideoEncoder.swift` | Peer TLS, cattura schermo selezionato e H.264 |
| Condiviso | `Shared/` | Framing, sample video e helper di localizzazione |
| Client iOS | `iPhone/` | Connessione, video, trackpad, tastiera e scena esterna |
| Lingue | `Resources/en.lproj`, `Resources/it.lproj` | Stringhe UI/stato e descrizioni privacy nei due bundle |

Impostazioni e diagnostica mantengono la directory `RayNeoWorkspace-Dev` per conservare le preferenze. Restano stabili nomi di target/file e identità del protocollo; non sono il nome pubblico dell'app.

Il riconoscimento dell'uscita permette già un display esterno generico, ma solo i GT hanno un driver IMU. Per altri visori servono adattatore specifico del protocollo, decodifica campioni, verifica unità/assi, calibrazione e test reali di riconnessione. Aggiungere un product ID non dimostra compatibilità.

Il lavoro della sessione usa una generazione per scartare callback tardive. Pulizia limitata e timeout coprono cancellazione/ordine risorse, ma un servizio di sistema bloccato può comunque creare problemi. Il recupero deve rispettare lo Stop manuale. La posizione dell'uscita viene salvata per recuperare il layout; il ripristino finestre vale nel processo.

Il remoto è opzionale e inizialmente disabilitato. Una chiave casuale autentica TLS 1.2/PSK. I frame video sono limitati senza accumulo indefinito. Gestione rete/background non sblocca il Mac e non garantisce recupero da sospensioni forzate.
