# Permessi e privacy

[English](../en/privacy.md) · [README](../../README.it.md)

| Permesso / dato | Scopo |
| --- | --- |
| Registrazione schermo e audio di sistema | Immagini desktop per monitor virtuali locali o video remoto abilitato esplicitamente; nessuna cattura audio. |
| Accessibilità | Spostamenti espliciti di finestre, strumenti cursore/tasti e input remoto. L'input ordinario resta nativo. |
| Rete locale | Connessione iPhone-Mac. |
| Impostazioni/diagnostica locale | Preferenze, posizione dell'uscita per il recupero, CPU/memoria/frame. Nessun video/audio registrato. |

I file sono in `~/Library/Application Support/RayNeoWorkspace-Dev/`: `settings.json`, `pending-layout.json`, `runtime-status.json`. Preferenze lingua e Liquid Glass usano anche UserDefaults. Percorsi sfondo e diagnostica possono rivelare nomi personali: controllali prima di condividerli.

La condivisione parte spenta. Ogni attivazione genera una nuova chiave casuale. TLS 1.2/PSK protegge un client sulla porta TCP 9847. Il codice concede accesso al desktop: tienilo privato e non esporre la porta su Internet. Fuori casa usa una VPN privata già sotto il tuo controllo. Il Mac resta sveglio durante la connessione, ma deve avere una sessione utente già aperta; sospensioni forzate e chiusura del coperchio non vengono aggirate. Il client si disconnette in background.

Non ci sono audit indipendenti, relay cloud, aggiornamenti/flashing firmware, registrazioni video/audio o sblocco Mac. [Segnalazioni sicurezza](../../SECURITY.it.md).
