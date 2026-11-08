# Compatibilità dispositivi

[English](../en/compatibility.md) · [README](../../README.it.md)

Versione 0.11.0, preview di sviluppo. Aggiornamento 8 novembre 2026. “Candidato” non significa collaudo hardware superato.

| Dispositivo | Video/workspace | Tracking testa | Evidenza |
| --- | --- | --- | --- |
| RayNeo GT | Implementato | Driver HID GT | Prove storiche su M2 positive; collaudo corrente pendente. |
| Altri RayNeo | Candidati sperimentali come display esterno | Nessun driver corrispondente | Non provati. |
| XREAL / VITURE / Rokid | Candidati sperimentali come display esterno | Nessun driver | Non provati; disattivare il tracking. |
| Monitor esterno normale | Possibile uscita tramite fallback sui display esterni | Nessun tracker visore | Utile per esperimenti, non certifica un visore. |
| Mac Intel | Nessun target host arm64 | — | Non supportato da questa build. |
| Apple Silicon M1/M2/M3/M4 e successivi | arm64 e macOS 26+ necessari | Dipende dal visore | Solo M2 ha prove storiche; nessuna certificazione per chip. |

L'app preferisce un display esterno con nome contenente `smartglasses` o `rayneo`, altrimenti sceglie il primo non integrato e non virtuale. Non c'è ancora un selettore manuale dell'uscita. Con Mac desktop o più monitor esterni verifica con attenzione: la scelta automatica può puntare al display sbagliato. Un nome generico non rende universale il tracking.

Il driver GT riconosce VID `0x3941`, PID `0xAF50`, usage page `0xFF00`, usage `1`. Il cavo USB-C deve trasportare video e dati HID; un cavo solo ricarica non basta. Hub e adattatori HDMI non sono collaudati. Non esiste ancora una matrice firmware. La rotazione orizzontale deriva dall'integrazione del giroscopio: non è posizionamento assoluto o tracking posizionale 6DoF.

## Companion

| Dispositivo | Requisito / limite |
| --- | --- |
| Famiglia iPhone 15 | DisplayPort USB-C supportato dalla piattaforma; flusso app/occhiali non collaudato. |
| iPhone 16 / Plus / Pro / Pro Max | Uscita video supportata dalla piattaforma; flusso app non collaudato. |
| iPhone 16e | Nessuna uscita video USB-C; non adatto agli occhiali collegati direttamente. |
| iPhone 17 / Pro / Pro Max | Candidati con uscita video di piattaforma; nessun collaudo del progetto. |
| Altri iPhone | Verificare le specifiche esatte: USB-C da sola non basta. |
| iPad | Target iPadOS 17+; uscita dipendente da modello/adattatore; non provato. |
| Dispositivi Lightning | Flusso diretto USB-C assente; configurazioni con adattatori non verificate. |
| Android / Windows | Nessun target companion/host. |

Il client richiede iOS/iPadOS 17+. La [guida USB-C Apple](https://support.apple.com/en-us/105099) descrive il supporto video della piattaforma, non certifica Spatial Workspace. Il companion seleziona un monitor manualmente. Il tracking testa iOS non è implementato. Il Mac deve essere sveglio, con sessione utente aperta e raggiungibile via LAN o VPN privata. Roundtrip rete/codec e latenza richiedono prove reali.

Nei report indica commit, Mac/OS, visore/firmware, cavo/dock e risultati separati per video, tracking, riconnessione/sospensione e durata. Per il remoto aggiungi modello/OS del telefono. Non includere codici di abbinamento.
