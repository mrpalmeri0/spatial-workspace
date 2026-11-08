# Inizia con Spatial Workspace

[English](../en/quickstart.md) · [README](../../README.it.md)

1. Collega gli occhiali direttamente a un Mac Apple Silicon con macOS 26+. Usa USB-C con video e dati USB. Per il tracking GT scegli la modalità Follow sugli occhiali.
2. Compila dal README oppure apri `RayNeoWorkspace.xcodeproj`. I target interni sono `RayNeoWorkspace` (Mac) e `RayNeoRemote` (iPhone/iPad); i nomi pubblici sono Spatial Workspace e Spatial Remote.
3. Scegli Cinema, Doppio o Trio prima dell'avvio. Premi **Avvia sessione** e autorizza Registrazione schermo e audio di sistema in Impostazioni → Privacy e sicurezza. Riapri l'app se richiesto. Non viene catturato audio.
4. Per il tracking GT tieni fermi gli occhiali per almeno due secondi e un numero sufficiente di campioni IMU validi. Attendi il tracking pronto e ricentra guardando avanti. Con altri visori disattiva il tracking: l'uso come display è sperimentale.
5. Usa mouse e tastiera nativi. Supera il bordo destro del Mac con il puntatore per raggiungere i desktop virtuali e trascinaci le finestre. Ferma la sessione prima di scollegare.

## Lingue e aspetto

Impostazioni → Aspetto → Lingua offre **Sistema / English / Italiano**. I controlli cambiano subito; riavvia per aggiornare tutti i messaggi memorizzati e i menu. Anche il client iPhone ha il selettore lingua. Le risorse bundle italiano/inglese supportano la lingua per app del sistema. Liquid Glass è disattivabile nelle impostazioni Mac.

## Firma e permessi

`SIGNING_IDENTITY=- bash build.sh` crea una build locale ad hoc in `build/dev/`. Per uso continuativo configura un'identità esistente con `bash scripts/configure-signing.sh CERTIFICATE_SHA1` oppure creane una dedicata con `python3 scripts/setup-local-signing.py`. Quest'ultimo modifica la configurazione locale di firma/portachiavi e può mostrare richieste macOS. Mantieni la stessa identità durante il collaudo dei permessi. Xcode ha una configurazione di firma separata: lo script non la modifica automaticamente.

L'input ordinario non richiede Accessibilità. Spostamento finestre, tastiera virtuale e controllo remoto sì. Non avviare più copie contemporaneamente.

## Problemi comuni

| Problema | Controllo |
| --- | --- |
| Nessuna uscita | Cavo con video, display esterno visibile in macOS, nessuna app concorrente. Con più monitor esterni può essere selezionato quello sbagliato: prova lasciando solo il visore. |
| Nessun movimento della testa | HID GT, modalità Follow, calibrazione, asse/direzione. Gli altri visori non hanno un driver tracking. |
| Cattura nera | Permesso Registrazione schermo; riapri se richiesto; prova disattivando Texture GPU e riavviando la sessione. |
| Controlli persi | Icona Dock, barra menu o ⌘0. |
| Layout cambiato dopo crash | Riapri con l'uscita originale collegata e usa Ripristina layout fisico. |

Leggi [compatibilità](compatibility.md) e [guida d'uso](guide.md).
