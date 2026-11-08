# Build, test e diagnostica

[English](../en/development.md) · [README](../../README.it.md)

Servono Xcode con SDK macOS 26+ e iOS, Python 3 e Apple Silicon. Nessuna dipendenza esterna. I due schemi sono condivisi.

```sh
xcodebuild -project RayNeoWorkspace.xcodeproj -scheme RayNeoWorkspace \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/xcode-mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RayNeoWorkspace.xcodeproj -scheme RayNeoRemote \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/xcode-iphone CODE_SIGNING_ALLOWED=NO build
bash Tests/run-tests.sh
bash Tests/run-remote-tests.sh
bash Tests/run-texture-test.sh
python3 Tests/localization_tests.py
```

I test texture richiedono Metal funzionante. Per l'integrazione remota usa `bash Tests/run-remote-tests.sh --integration`, per il codec `--codec`. In precedenza l'ambiente di preparazione ha bloccato il listener TLS e non trovava un encoder VideoToolbox. I test protocollo non provano un roundtrip rete/video funzionante.

Dopo aggiunte/rimozioni di sorgenti o cartelle localizzate aggiorna/verifica `scripts/generate-xcode-project.py` e rigenera. Legge `Config/release.env`. Controlla la firma perché le modifiche manuali Xcode possono divergere dal generatore. Debug usa un'identità locale; l'installazione iPhone richiede il tuo Team. La build da script ha un bundle ID distinto da quella Xcode.

`L` cerca chiavi italiane leggibili nelle risorse inglesi/italiane. `LF` formatta i messaggi senza inserire dati dinamici nelle chiavi. Mantieni allineati tabelle e placeholder. Non tradurre stringhe protocollo, chiavi impostazioni, simboli di sistema o identificatori di persistenza.

```sh
python3 scripts/collect-metrics.py --duration 60
python3 scripts/package-source.py
git diff --check
```

Le metriche riportano CPU/memoria/frame senza immagini; non misurano la latenza end-to-end. Lo ZIP contiene documentazione pubblica, immagini, lingue, entrambi i target e configurazione, esclude chiavi/build e include un manifest SHA-256. Registra l'eventuale working tree modificato.

## Collaudo dispositivi ancora necessario

Verifica input nativo sui layout, leggibilità, ricentratura/deriva/rotazioni lente, 10 cicli avvio-stop, riconnessione, priorità allo Stop manuale, sospensione, recupero finestre, Focus/pannello, entrambe le pipeline grafiche e lingue. Sul remoto verifica codice corretto/errato, video leggibile, tastiera, scena esterna, VPN e disconnessione in background. Registra commit e dispositivi esatti; compilazione non significa collaudo hardware.
