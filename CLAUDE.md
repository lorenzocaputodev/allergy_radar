# Allergy Radar

App Flutter per Android (Windows solo per debug): pollini della zona in tutta Italia, diario dei sintomi,
avvisi e widget. Nessun account e nessun backend: parla solo con Open-Meteo e con il WFS open data di ISPRA.
Testi dell'app, commenti e commit in italiano.

Prima di lavorare su un'area, leggi il documento giusto in `docs/` (indice: `docs/README.md`):
architettura, fonti dei dati, sviluppo e release, design, decisioni (`docs/decisions/`), roadmap.

## Comandi

```bash
flutter pub get
flutter analyze                 # deve dire "No issues found!"
flutter test                    # suite in test/
flutter build apk --release     # senza android/key.properties firma con la chiave di debug
dart format lib test test_screens
```

- Screenshot per la revisione visiva: `flutter test test_screens/screens_test.dart --update-goldens` → `test_screens/out/`.
- Dopo modifiche all'interfaccia, rigenera gli screenshot della schermata toccata e guardali.

## Regole del codice

- Formattazione a 120 colonne (`analysis_options.yaml`); lint: `prefer_single_quotes`, `prefer_final_locals`,
  `directives_ordering`, `unawaited_futures`.
- Commenti solo per il perché, in italiano. Niente commenti che ripetono il codice.
- Ogni valore di polline mostra la sua fonte (`DataKind`: previsione, misurato, stima). Mai presentare una stima
  come misura.
- La scelta della fonte vive solo in `PollenRepository.build`; cosa notificare solo in `AlertPlanner.plan`
  (funzione pura, con test).
- Servizi di piattaforma: usa `Platform.isAndroid` (dart:io), non `defaultTargetPlatform`, che nei test vale
  «android» anche su Windows.
- Colori e testi dei livelli vengono da `AppPalette` (`lib/theme/palette.dart`): niente colori fissi nelle schermate.
- Nuove preferenze salvate: aggiungi la chiave a `AppState.backupKeys` o `DiaryState.backupKeys`, altrimenti
  il backup le perde.

## Insidie note

- ISPRA WFS: usa `outputFormat=csv`. Nel JSON le date sono spostate indietro di un giorno.
- `http` decodifica in Latin-1 senza charset: leggi sempre `utf8.decode(res.bodyBytes)`.
- Bari e Brindisi non hanno misure nella banca dati nazionale: in Puglia la Parietaria è una stima.
- Toolchain Android fissata: AGP 8.13.2, Kotlin 2.2.21, Gradle 8.14.5, JDK 21. Non aggiornare ad AGP 9.
- Su questo PC `flutter_tester` va a volte in crash (0xC0000005, «did not complete» senza messaggio):
  rilancia il file di test. Un errore vero ha sempre un messaggio (`Expected`, `was thrown`…).
- Con l'app Windows aperta i test possono bloccarsi: chiudila prima (`allergy_radar.exe`).
- Gradle con poca RAM: dopo una build, `android/gradlew --stop` libera memoria per i test.

## Git e release

- Conventional Commits in italiano: `feat:`, `fix:`, `refactor:`, `docs:`, `build:`, `ci:`, `chore:`, `test:`.
  Oggetto breve e senza numeri di versione, tranne `chore: porta la versione a X.Y.Z`.
- Repository privato `lorenzocaputodev/allergy_radar`. Non fare push, tag o release senza richiesta esplicita.
- Procedura di release: `docs/development.md#release`.
- Mai committare `android/key.properties` né keystore.
