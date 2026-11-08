# RayNeo GT Mac Workspace · 0.11.0

App Mac nativa per usare **uno, due o tre desktop virtuali** sui RayNeo GT, con tracking della testa, anteprima live, strumenti rapidi e client iPhone/iPad sperimentale.

La versione corrente è una **preview di sviluppo**. Le prove storiche sui GT non equivalgono al collaudo completo della nuova 0.11.0. Il repository è organizzato per la pubblicazione autonoma; origine del codice e situazione licenza sono riportate in [NOTICE.md](NOTICE.md).

## Requisiti

| Componente | Requisito |
| --- | --- |
| Mac | Apple Silicon, macOS 26+. M2 provato storicamente; altri chip da verificare. |
| Occhiali | RayNeo GT, modalità Follow, USB-C con video e dati HID. |
| Build | Xcode con SDK macOS 26+; Python 3 per gli script. Nessuna dipendenza esterna. |
| Remoto | iPhone/iPad con iOS/iPadOS 17+; uscita video del dispositivo necessaria per collegare gli occhiali. Flusso hardware ancora da collaudare. |

La [matrice dispositivi](docs/COMPATIBILITY.md) distingue requisiti software, capacità video e tracking. Una porta USB-C da sola non garantisce l'uscita video. Non sono implementati tracker per altri occhiali, client Android o build Windows/Intel.

## Avvio rapido

Scarica lo ZIP sorgenti dal tuo repository GitHub, estrailo e apri il Terminale nella cartella:

```sh
SIGNING_IDENTITY=- bash build.sh
open build/dev/RayNeoWorkspace-Dev.app
```

È una build locale con firma ad hoc. Per lavorare stabilmente segui la [guida firma](docs/SIGNING.md), riutilizzando la tua identità: i cambi di firma possono richiedere nuovamente i permessi.

1. Chiudi le altre copie dell'app, collega i GT direttamente al Mac e seleziona Follow.
2. Scegli Cinema, Doppio o Trio e premi **Avvia sessione**.
3. Consenti **Registrazione schermo e audio di sistema** nelle impostazioni Privacy e sicurezza. L'app non cattura audio.
4. Tieni fermi gli occhiali per almeno due secondi e attendi il tracking attivo.
5. Disponi le finestre sui desktop, gira la testa e usa **Ricentra** quando serve.
6. Ferma la sessione prima di scollegare gli occhiali. **⌘0** riapre i controlli.

Mouse e tastiera ordinari restano nativi. Accessibilità serve per spostare le finestre, generare tasti e controllare il Mac da remoto.

## Progetto e funzioni

Apri `RayNeoWorkspace.xcodeproj`: **RayNeoWorkspace** è l'host Mac, **RayNeoRemote** il client iPhone/iPad. Per installare il client configura il tuo Team e un bundle ID disponibile.

La UI SwiftUI/AppKit offre Liquid Glass disattivabile, Layout 3D, Vista dagli occhiali e regolazioni dei pannelli. Gli strumenti includono cursore **⌘⌥P**, radar **⌘⌥M**, pannello **⌘⌥K**, Focus **⌘⌥F** e spostamento finestre **⌘⌥1/2/3/0**. Il recupero delle finestre vale nella sessione del processo e per finestre ancora aperte.

Il client remoto implementa TLS/PSK, video H.264, trackpad, testo e selezione monitor. La scena esterna è implementata, il tracking testa iOS no. Connessione, codec e resa reale richiedono ancora una prova completa sui dispositivi. Fuori casa è prevista una VPN privata già configurata.

## Guide

- [Esempi d'uso](docs/EXAMPLES.md): programmazione, Cinema, Focus e remoto.
- [Preset JSON completi](examples/README.md): esempi modificabili dei parametri.
- [Compatibilità](docs/COMPATIBILITY.md): Mac, occhiali, iPhone/iPad e cavi.
- [App nativa e collaudo](docs/NATIVE_APP.md): funzionalità e verifiche.
- [Pubblicazione GitHub](docs/GITHUB_PUBLICATION.md): stato, verifiche e passaggi di pubblicazione.
- [Distribuzione Mac](docs/RELEASE.md): firma Developer ID e notarizzazione, separate dalla pubblicazione dei sorgenti.

Il progetto usa API private per i display virtuali; la compatibilità può cambiare con macOS. Non modifica firmware. Non è un prodotto ufficiale RayNeo.
