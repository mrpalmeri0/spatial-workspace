# Spatial Workspace

Italiano · [English](README.md)

**Il tuo Mac, oltre un solo schermo.** Un desktop spaziale nativo con uno, due o tre monitor virtuali indipendenti, anteprima live, strumenti Focus e companion iPhone sperimentale.

![Spatial Workspace in italiano](docs/images/workspace-it.jpg)

**0.11.0 · preview di sviluppo · Apple Silicon · macOS 26+**

Spatial Workspace è un nome generico. Il tracking dispone attualmente di un solo driver hardware implementato: **RayNeo GT**. Gli altri visori con uscita video sono candidati sperimentali come schermo, con tracking disattivato; i loro protocolli non sono implementati. È un progetto indipendente della community.

## Funzioni

| Funzione | Comportamento |
| --- | --- |
| Cinema / Doppio / Trio | 1–3 desktop macOS indipendenti a 1920 × 1080 |
| Tracking della testa | Integrazione del giroscopio GT, calibrazione, ricentratura e correzione della deriva |
| App Mac reali | Finestre, mouse, tastiera, scroll e trascinamento nativi |
| Anteprima | Layout 3D oppure vista live degli occhiali sul Mac |
| Strumenti Focus | Richiamo cursore, radar, blocco vista e pannello con tastiera |
| Companion | Remoto iPhone/iPad sperimentale TLS/PSK e H.264, trackpad e selezione manuale monitor |
| Lingue | Italiano e inglese; lingua del sistema o selezione nelle impostazioni dell'app |

## Avvio rapido

```sh
git clone https://github.com/mrpalmeri0/spatial-workspace.git
cd spatial-workspace
SIGNING_IDENTITY=- bash build.sh
open build/dev/RayNeoWorkspace-Dev.app
```

Serve Xcode con SDK macOS 26+. Il comando produce una preview locale con firma ad hoc, non un'app notarizzata. Seleziona Cinema, Doppio o Trio, collega il visore, premi **Avvia sessione** e autorizza Registrazione schermo e audio di sistema quando richiesto. L'app non cattura audio. Tieni fermi i GT per la calibrazione e ricentra quando serve. Ferma la sessione prima di scollegarli.

L'input ordinario non richiede Accessibilità; spostamento finestre, tasti sintetici e controllo remoto sì. [Configurazione completa](docs/it/quickstart.md).

## Dispositivi e limiti

| Componente | Requisito / evidenza |
| --- | --- |
| Mac | Apple Silicon, macOS 26+. Esistono prove storiche su M2 e GT; la versione attuale non è certificata su ogni chip. |
| RayNeo GT | Uscita video e tracking HID implementati; USB-C con video e dati, modalità Follow. Collaudo completo corrente ancora da eseguire. |
| Altri visori | Uso sperimentale come display esterno, disattivando il tracking. Nessun driver tracking XREAL/VITURE/Rokid/altri RayNeo incluso. |
| iPhone/iPad | Target iOS/iPadOS 17+. L'uscita video richiede un modello compatibile. Flusso remoto completo ancora da collaudare. |
| Intel / Windows / Android | Nessun target supportato. |

La [matrice dispositivi](docs/it/compatibility.md) separa capacità video, driver implementati e risultati effettivi. I display virtuali usano API macOS private e possono rompersi con gli aggiornamenti. Il giroscopio può derivare e non offre tracking posizionale 6DoF. Il remoto 1080p/30 fps è un obiettivo di configurazione, non una prestazione misurata.

## Guide

| Guida | Italiano | English |
| --- | --- | --- |
| Configurazione e lingue | [Inizia](docs/it/quickstart.md) | [Start](docs/en/quickstart.md) |
| Dispositivi | [Compatibilità](docs/it/compatibility.md) | [Compatibility](docs/en/compatibility.md) |
| Schermate e flussi | [Guida d'uso](docs/it/guide.md) | [User guide](docs/en/guide.md) |
| Architettura | [Architettura](docs/it/architecture.md) | [Architecture](docs/en/architecture.md) |
| Build, test, diagnostica | [Sviluppo](docs/it/development.md) | [Development](docs/en/development.md) |
| Pubblicazione sorgenti/app | [Pubblicazione](docs/it/release.md) | [Release](docs/en/release.md) |
| Permessi e privacy | [Privacy](docs/it/privacy.md) | [Privacy](docs/en/privacy.md) |

[Preset di esempio](examples/README.it.md) · [Contributi](CONTRIBUTING.it.md) · [Changelog](CHANGELOG.it.md) · [Sicurezza](SECURITY.it.md) · [Note](NOTICE.it.md)

Il contenuto degli schermi resta locale finché non abiliti la condivisione remota. Il codice di abbinamento concede accesso al desktop: non pubblicarlo. Fuori casa usa una VPN privata. Nessun firmware viene modificato. La guida privacy descrive dati locali, permessi e remoto.
