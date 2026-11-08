# Preparazione GitHub · 8 novembre 2026

Versione 0.11.0 documentata come preview autonoma. README inglese/italiano aggiornati, matrice compatibilità, esempi e preset completi, template issue, changelog, privacy e attribuzioni. Pacchetto sorgenti corretto per includere Shared, iPhone, Config e progetto Xcode. Destinazione autonoma: https://github.com/mrpalmeri0/rayneo-gt-mac-workspace. Repository creato tramite browser; primo caricamento sorgenti preparato via interfaccia GitHub. Nessuna licenza permissiva aggiunta: baseline disponibile priva di licenza esplicita. Dettagli e verifiche in docs/GITHUB_PUBLICATION.md. La storia locale è conservata; non pubblicare sul vecchio remote originale.

---

# RayNeo Workspace · stato attuale

Aggiornamento: 7 novembre 2026. Progetto corrente: `RayNeo-GT-Mac-Workspace`.

## Aggiornamento interfaccia · 7 novembre, sera

Dashboard rinnovata in `Sources/WorkspaceDelegate+Dashboard.swift`: sidebar con identità e stato del dispositivo, accenti indaco e colori semantici chiaro/scuro, preset con feedback al passaggio del puntatore, anteprima con selettore Layout 3D/Vista live e indicatori, regolazioni in griglia adattiva, barra sessione con azione primaria prominente. Schermate Strumenti, remoto e Impostazioni con intestazioni coerenti. Liquid Glass limitato ai pulsanti, con alternativa disattivabile; animazione hover rispettosa di Riduci movimento. Dimensioni iniziali 1220×860 e salvataggio posizione/dimensione finestra.

Build Xcode macOS senza firma passata dopo queste modifiche; `git diff --check` passato. Tentativo di rendering `--render-controls` terminato con codice 134: nessuna immagine ottenuta. Verifica visiva chiaro/scuro, ridimensionamento e interazione ancora da eseguire sul Mac. Nessun riavvio/installazione dichiarato.

## Da dove riprendere

Il progetto Xcode nativo è **RayNeoWorkspace.xcodeproj**, con schemi **RayNeoWorkspace** (Mac) e **RayNeoRemote** (iPhone). Versione **0.11.0 di sviluppo**, non ancora collaudata sui dispositivi. Leggere **docs/NATIVE_APP.md** per build, funzionalità, verifiche eseguite e limiti reali. **docs/ROADMAP.md** distingue implementato e da verificare.

L'interfaccia Mac ora usa SwiftUI e AppKit, sidebar, form e controlli nativi, con Liquid Glass disattivabile. Il motore preesistente mantiene display virtuali indipendenti, cattura, rendering e tracking. Sono stati aggiunti cursore su richiesta, radar, Focus, pannello non attivante, tastiera e recupero delle finestre nella sessione corrente. Il target iPhone include un primo flusso remoto cifrato, H.264 e uscita su display esterno. La navigazione tramite testa su iPhone resta da verificare.

## Validazione

Build Mac da script e Xcode e build iOS Simulator generica passate. Test core, lifecycle e protocollo passati. Nessun collaudo visuale/hardware effettuato in questa sessione: il controllo nativo non è disponibile. Listener TLS bloccato dai permessi di rete dell'ambiente; VideoToolbox non trova un encoder in questo ambiente (-12908). Non dichiarare verificati rete, video remoto, prestazioni o tracking iOS.

QA Mac: `build/native-qa/RayNeoWorkspace-Dev.app` (ad hoc). Build Xcode in `build/xcode-mac` e `build/xcode-iphone`. Nessuna installazione/sostituzione della copia esistente. La cartella copiata non include la vecchia identità di firma; non crearne o ruotarne una automaticamente. Per installazione stabile vedere docs/SIGNING.md. Il target iPhone richiede il Team del proprietario.

## Vincoli da preservare

- Mouse, tastiera, scroll e trascinamento ordinari rimangono nativi; nessun event tap o rimappatura continua. Lo spostamento del cursore introdotto in 0.11 è solo un comando esplicito approvato nella nuova roadmap.
- Runtime HID solo IMU ON/OFF; niente firmware o calibrazione permanente.
- Le chiavi di firma restano fuori da Git. La condivisione remota parte disattivata; codice di abbinamento mai in log o diagnostica.
- Non avviare contemporaneamente più copie dell'app né alternare firme durante il collaudo TCC.
- Vecchia baseline v0.8 e correzioni 0.10.1 rimangono nella storia Git. I pacchetti release obsoleti erano già stati rimossi nella sessione precedente su richiesta dell'utente.
- Esistono modifiche locali precedenti non committate: conservarle.

## File principali

- `Sources/main.swift`: lifecycle AppKit.
- `Sources/WorkspaceDelegate+Dashboard.swift`: nuova interfaccia SwiftUI e bridge osservabile.
- `Sources/WorkspaceTools.swift`, `Sources/MonitorTarget.swift`: strumenti Mac.
- `Sources/RemoteWorkspaceHost.swift`, `Sources/RemoteVideoEncoder.swift`: host remoto.
- `Shared/`: protocollo TLS/framing e ricostruzione dei sample H.264.
- `iPhone/`: client, input e scena display esterno.
- `scripts/generate-xcode-project.py`: generatore senza dipendenze del progetto Xcode.
- `Tests/run-tests.sh`, `Tests/run-remote-tests.sh`: verifiche automatiche.

Dettagli storici: docs/HANDOFF-v0.8.md e DEVELOPMENT_NOTES.md; le note cinesi precedenti non descrivono la nuova UI.
