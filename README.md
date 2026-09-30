![Banner](assets/images/banner.png)

# 🌾 Allergy Radar

[![CI](https://github.com/lorenzocaputodev/allergy_radar/actions/workflows/ci.yml/badge.svg)](https://github.com/lorenzocaputodev/allergy_radar/actions/workflows/ci.yml) ![License](https://img.shields.io/badge/license-MIT-blue) ![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B)

> **Pollini della tua zona e i tuoi sintomi, con la fonte sempre in vista.**

- 🌿 Graminacee, Parietaria e altri 8 allergeni in tutta Italia, con il livello di oggi e dei prossimi giorni
- 📓 Un diario dei sintomi che dopo due settimane ti dice quali pollini ti danno davvero fastidio
- 🔒 Senza account e senza pubblicità: i tuoi dati restano solo sul tuo telefono

## 📲 Scarica l’app

Scarica l’APK dall’**[ultima versione pubblicata](https://github.com/lorenzocaputodev/allergy_radar/releases/latest)** e aprilo dal telefono: Android ti chiederà di consentire l’installazione di app scaricate dal browser.

## 📸 Schermate

<p align="center">
  <img src="assets/screenshots/app_oggi.webp" alt="Oggi" width="23%">
  <img src="assets/screenshots/app_diario.webp" alt="Diario" width="23%">
  <img src="assets/screenshots/app_andamento.webp" alt="Andamento" width="23%">
  <img src="assets/screenshots/app_calendario.webp" alt="Calendario" width="23%">
</p>

<p align="center"><sub>Oggi · Diario · Andamento · Calendario</sub></p>

---

## ✨ Funzionalità principali

- 🧭 **Oggi**: livello della giornata, i tuoi allergeni, prossimi giorni, aria (ozono, PM2.5, polvere sahariana) e altri pollini in zona
- 🏷️ Ogni valore dice da dove arriva: **Previsione**, **Misurato** o **Stima**
- 🔎 Dettaglio di ogni allergene: ora per ora, prossimi giorni o ultime misure, stagione e soglia personale
- 📓 **Diario**: naso, occhi, gola, respiro, sonno, farmaci, ore all’aperto e nota, con i pollini del giorno salvati insieme
- 📈 **Andamento**: sintomi, farmaci e un allergene negli ultimi 30 giorni, con il confronto «sopra o sotto il livello moderato»
- 🗓️ **Calendario** stagionale misurato per **Nord**, **Centro** e **Sud e Isole**
- 🔔 **Avvisi**: briefing del mattino, «domani peggiora» e promemoria del diario
- 📲 Widget Android **«La tua giornata»**
- 📍 Luogo da ricerca città o dalla **posizione approssimativa** del telefono
- 📄 **PDF per l’allergologo**, diario in **CSV**, **backup** e ripristino
- 🎨 Tema **sistema / chiaro / scuro**
- 👋 Primo avvio guidato: allergeni, luogo e avvisi

---

## 🧭 Da dove arrivano i dati

| Tipo | Fonte | Allergeni | Note |
|---|---|---|---|
| **Previsione** | [Open-Meteo Air Quality](https://open-meteo.com/en/docs/air-quality-api), modello CAMS Europa | Graminacee, olivo, ambrosia, artemisia, betulla, ontano; ozono, PM2.5, polvere | Orario, circa 4 giorni, celle di circa 11 km. Gratuito, senza chiave |
| **Misurato** | [POLLnet](https://pollnet.isprambiente.it/opendata/) (ISPRA e ARPA), servizio WFS open data | Parietaria (Urticacee), cipresso, quercia, piantaggine, Alternaria | Valori giornalieri, pubblicati con alcuni giorni di ritardo. Solo stazioni entro 60 km con misure degli ultimi 10 giorni |
| **Stima** | Media storica del mese nelle stazioni POLLnet dell’area, 2016–2025 | Quelli senza previsione né misura | Indica la stagione, non il giorno. Sempre dichiarata |

- **La Parietaria non ha previsioni**: nessun modello europeo la calcola. Dove c’è una stazione POLLnet attiva vicina l’app mostra la misura, altrimenti la media storica.
- **Puglia**: le stazioni di Bari e Brindisi non hanno misure nella banca dati nazionale, quindi in Salento la Parietaria è una media storica.
- **Area del calendario**: quella della regione della stazione POLLnet più vicina al luogo scelto.
- **Soglie**: classi POLLnet (bassa, media, alta) lette dal servizio ISPRA. «Molto alto» vale 3 volte la soglia alta.

---

## 🔔 Sistema avvisi

Un controllo in background circa ogni ora aggiorna i dati e il widget, poi manda gli avvisi dovuti, al massimo uno per tipo al giorno:

- ☀️ **Briefing del mattino** (07:30): livelli di oggi dei tuoi allergeni, anche solo nei giorni sopra soglia
- 📈 **Domani peggiora** (19:00): se domani un tuo allergene sale e supera la soglia
- 📓 **Promemoria diario** (21:00): solo se oggi non hai ancora registrato

Orari e interruttori si cambiano dal Profilo. Le notifiche sono gestite su Android tramite:

- `flutter_local_notifications`
- `workmanager`

---

## 🛠️ Piattaforme

- 🤖 **Android**: piattaforma prioritaria
- 🖥️ **Windows**: supporto utile per debug e test locali (niente avvisi né widget)

---

## 🧰 Requisiti per compilare

Prerequisiti, con le versioni su cui la build è verificata:

- Flutter **3.47.5** stable (Dart 3.13.4)
- Android SDK con platform **android-36**, build-tools 36.0.0 e NDK 28.2.13676358
- **JDK 21** — Gradle 8.14.5 non supporta JDK 25, quindi va agganciato con
  `flutter config --jdk-dir "<percorso del JDK 21>"`
- Visual Studio Code

La catena di build usa Gradle 8.14.5, AGP 8.13.2 e Kotlin 2.2.21, volutamente
entro la linea 8.x di AGP, come My Tracking App.

Senza `android/key.properties`, `flutter build apk --release` usa la chiave di debug.

`android/gradle.properties` dimensiona il daemon Gradle a 2 GB di heap: su
macchine con poca RAM valori più alti fanno terminare il daemon a metà build.

---

## ⚡ Compilare il progetto

### 1. Clona la repository
```bash
git clone https://github.com/lorenzocaputodev/allergy_radar.git
cd allergy_radar
```

### 2. Installa le dipendenze
```bash
flutter pub get
```

### 3. Avvia l’app
```bash
flutter run
```

### 4. Controlli
```bash
flutter analyze
flutter test
```

---

## 🧪 Revisione visiva e asset generati

La cartella `test_screens/` non fa parte della suite: genera immagini dal codice.

| Comando | Cosa produce |
|---|---|
| `flutter test test_screens/screens_test.dart --update-goldens` | Screenshot di tutte le schermate a 412 dp in `test_screens/out/` (fuori da git) |
| `python tool/readme_images.py` | Schermate WebP e banner del README, dagli screenshot `readme_*` |
| `flutter test test_screens/icons_test.dart --update-goldens` | Icona dell’app e sagoma per le notifiche, dal marchio in `lib/widgets/radar_mark.dart` |
| `dart run flutter_launcher_icons` | Mipmap Android dall’icona |
| `node tool/build_calendar.mjs > tool/calendar.txt` | Calendari per area dagli storici ISPRA, da copiare in `lib/models/allergen.dart` |

---

## 📂 Struttura essenziale

- `lib/models/` → allergeni e calendari, livelli e soglie, aree, luoghi, stazioni, diario, impostazioni degli avvisi
- `lib/services/` → client Open-Meteo e POLLnet, avvisi, posizione, widget, file, backup e PDF
- `lib/data/` → `PollenRepository`: sceglie la fonte di ogni allergene e tiene la cache
- `lib/state/` → `AppState` e `DiaryState` (provider) e persistenza
- `lib/screens/` → schermate
- `lib/widgets/` → componenti riutilizzabili: barra del rischio, chip della fonte, card, ricerca luogo, marchio
- `lib/theme/` → token di colore e tipografia (Fraunces, Figtree)
- `android/app/src/main/kotlin/dev/lorenzocaputo/allergyradar/widget/` → widget Android nativo
- `assets/data/stations.json` → stazioni POLLnet
- `test/fixtures/` → risposte reali di Open-Meteo e ISPRA per i test

---

## 🔐 Privacy e dati

- Nessun account, nessuna pubblicità, nessuna analisi d’uso
- Nessun backend: l’app parla solo con Open-Meteo e ISPRA
- A Open-Meteo vanno coordinate arrotondate a circa 1 km, a ISPRA solo il codice della stazione
- Posizione solo approssimativa, e solo se la chiedi tu
- Diario e impostazioni salvati localmente; il backup lo esporti tu

L’app informa, non sostituisce il medico.

---

## 🧩 Note per chi continua lo sviluppo

- **Onestà dei dati**: ogni valore mostra la sua fonte (`DataKind`). Una stima non va mai presentata come misura.
- **Un solo posto per le decisioni**: `PollenRepository.build` sceglie previsione, misura o stima; `AlertPlanner` decide gli avvisi ed è una funzione pura, testata senza plugin.
- **Background**: `AlertsService.runInBackground` riusa `AppState` e `DiaryState`; il widget legge `flutter.widget_data` dalle SharedPreferences.
- **Piattaforma**: i servizi controllano `Platform.isAndroid`, non `defaultTargetPlatform`, che nei test vale «android» anche su Windows.
- **ISPRA**: si usa l’output CSV del WFS, perché in quello JSON le date risultano spostate indietro di un giorno.
- **Stile**: formattazione a 120 colonne (`analysis_options.yaml`), commenti in italiano solo dove spiegano il perché.
- **Commit**: Conventional Commits in italiano (`feat:`, `fix:`, `docs:`, `build:`, `chore:`…), senza numeri di versione tranne che in `chore: porta la versione a …`.
- **Test su Windows**: su alcune macchine `flutter_tester` va in crash (0xC0000005) anche con test banali: se un file segnala «did not complete» senza messaggio, rilancialo.

---

## 👨‍💻 Sviluppo

Durante lo sviluppo, il debugging e la rifinitura del progetto è stato utilizzato supporto AI come assistenza tecnica per progettazione, troubleshooting, revisione della documentazione e scrittura e pulizia del codice.

---

## 📜 Licenze e attribuzioni

- Codice: [MIT](LICENSE)
- Previsioni: © Copernicus Atmosphere Monitoring Service, tramite Open-Meteo (CC BY 4.0)
- Misure: rete POLLnet-SNPA, ISPRA (CC BY 4.0)
- Font Fraunces e Figtree: SIL Open Font License (`assets/fonts/OFL-*.txt`)

---

## 👤 Autore

**Lorenzo Caputo**  
GitHub: [lorenzocaputodev](https://github.com/lorenzocaputodev)  
Portfolio: [lorenzocaputo.is-a.dev](https://lorenzocaputo.is-a.dev/)
