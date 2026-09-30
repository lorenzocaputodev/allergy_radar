# Sviluppo

## Ambiente

| Strumento | Versione verificata |
|---|---|
| Flutter | 3.47.5 stable (Dart 3.13.4) |
| Android SDK | platform android-36, build-tools 36.0.0, NDK 28.2.13676358 |
| JDK | 21 (`flutter config --jdk-dir "<percorso del JDK 21>"`) |
| Gradle / AGP / Kotlin | 8.14.5 / 8.13.2 / 2.2.21 (ADR 0006) |
| Node.js | 18 o più, solo per `tool/build_calendar.mjs` |
| Python + Pillow | solo per `tool/readme_images.py` |

`android/gradle.properties` limita il daemon Gradle a 2 GB: su macchine con poca RAM valori più alti lo fanno terminare.

## Comandi

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows          # interfaccia sul PC
flutter build apk --debug
flutter build apk --release
dart format lib test test_screens
dart fix --apply
```

## Test

| File | Cosa copre |
|---|---|
| `test/sources_test.dart` | Soglie, parsing Open-Meteo e CSV ISPRA, filtro CQL, stazioni e aree |
| `test/repository_test.dart` | Scelta previsione/misura/stima, ISPRA giù, cache |
| `test/diary_test.dart` | Voci del diario, persistenza, confronto con i pollini |
| `test/alerts_test.dart` | `AlertPlanner`: orari, finestre, niente doppioni, soglie |
| `test/backup_test.dart` | Backup e ripristino, rifiuto di file estranei, CSV, PDF |
| `test/app_smoke_test.dart` | Interfaccia a 360 dp: Oggi, schede, dettaglio, diario, primo avvio |

- Le fixture in `test/fixtures/` sono risposte reali (Open-Meteo su Lecce del 30/09/2026, ISPRA Bologna, geocoding).
- `test/helpers.dart` fornisce un `MockClient`: solo la stazione di Bologna (118) ha dati, le altre rispondono vuote come Brindisi.
- I test di interfaccia usano `hitTestWarningShouldBeFatal = true`: un tocco fuori dallo schermo è un errore.
- Crash di `flutter_tester` su Windows (0xC0000005, «did not complete» senza messaggio): è della macchina, non del codice. Succede anche con test banali e in my_tracking_app, mai sulla CI. Rilancia il file, chiudi l'app Windows e ferma Gradle (`android/gradlew --stop`) se la RAM è poca.

## Revisione visiva e asset generati

`test_screens/` non fa parte della suite: produce immagini dal codice.

| Comando | Risultato |
|---|---|
| `flutter test test_screens/screens_test.dart --update-goldens` | Screenshot di tutte le schermate a 412 dp (Motorola Edge 50 Fusion) in `test_screens/out/` (ignorata da git). Con `--plain-name "<nome>"` una sola |
| `python tool/readme_images.py` | `assets/screenshots/app_*.webp` e `assets/images/banner.png` dagli screenshot `readme_*` |
| `flutter test test_screens/icons_test.dart --update-goldens` | `assets/launcher/icon_*.png` e `res/drawable-*/ic_stat_logo.png` dal marchio (`lib/widgets/radar_mark.dart`) |
| `dart run flutter_launcher_icons` | Mipmap Android dall'icona |
| `node tool/build_calendar.mjs > tool/calendar.txt` | Calendari per area dagli storici ISPRA (vedi `data-sources.md`) |

Negli screenshot i font veri si caricano in `setUpAll`, e le icone Material da
`C:/development/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf`: se Flutter è altrove,
aggiorna il percorso.

## CI e Dependabot

- `.github/workflows/ci.yml`: su Windows `pub get --enforce-lockfile`, `analyze`, `test`; su Ubuntu build APK di debug con JDK 21.
- `.github/dependabot.yml`: pacchetti Dart ogni settimana (solo minor e patch; per i pacchetti 0.x solo patch), Actions ogni mese. Gradle, AGP e Kotlin si aggiornano a mano.

## Release

1. `flutter analyze` e `flutter test` puliti; CI verde sull'ultimo commit di `main`.
2. Versione in `pubspec.yaml` (`X.Y.Z+N`, con `N` che aumenta sempre) → commit `chore: porta la versione a X.Y.Z`.
3. `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
4. Rinomina in `allergy-radar-X.Y.Z.apk` e pubblica:
   ```bash
   gh release create vX.Y.Z allergy-radar-X.Y.Z.apk --repo lorenzocaputodev/allergy_radar \
     --title "Allergy Radar X.Y.Z" --notes-file note.md --target main
   ```
5. Note della release in italiano: installazione, novità, note (firma, limiti dei dati).

### Firma

- Senza `android/key.properties` la release usa la chiave di debug, come in `v1.0.0`.
- Per la chiave personale: `android/key.properties` con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, fuori da git (già in `android/.gitignore`). Il passaggio dalla chiave di debug a quella personale richiede di disinstallare l'app: prima va esportato il backup.

## Convenzioni

- Commit: Conventional Commits in italiano, oggetto breve, niente versioni tranne nel commit dedicato. Corpo per spiegare il perché quando serve.
- Codice: 120 colonne, commenti in italiano solo per il perché, testi dell'interfaccia in italiano naturale.
- Prima di ogni commit: `flutter analyze` e i test dell'area toccata. Dopo modifiche visive: gli screenshot della schermata.
