# Pubblicare sorgenti e applicazione

[English](../en/release.md) · [README](../../README.it.md)

Repository: [mrpalmeri0/spatial-workspace](https://github.com/mrpalmeri0/spatial-workspace). La 0.11.0 è una preview di sviluppo. Pubblicazione dei sorgenti e app notarizzata scaricabile sono deliverable separati.

Per i sorgenti controlla `git status`, esegui le verifiche di development.md e ispeziona lo ZIP pubblico prodotto da `python3 scripts/package-source.py`. Conserva le note dei componenti. La situazione licenza è in [NOTICE.it.md](../../NOTICE.it.md); non è stata presunta una licenza generale.

Per il binario Mac distribuito direttamente imposta nomi, versione/build e firma in `Config/release.env`, rigenera il progetto, installa un certificato Developer ID Application e salva un profilo notarytool nel portachiavi. `bash scripts/release-mac.sh` esegue archivio, export, notarizzazione, stapling e DMG. Il pacchetto finale richiede ancora verifica firma/Gatekeeper e hardware. L'esistenza dello script non significa che esista una release notarizzata.

L'host usa API private per display virtuali e controllo desktop senza sandbox. Il Mac App Store non è il percorso attuale. Il companion iPhone ha un processo firma/App Store separato. Non creare una 1.0 stabile né dichiarare tracking di altri visori prima di implementazione e collaudo.

Non caricare `.signing-config`, `.signing-identity`, chiavi private, profili provisioning, codici remoti o diagnostica personale. Il Team ID pubblico non è una chiave privata, ma chi compila una propria copia deve configurare la propria firma.
