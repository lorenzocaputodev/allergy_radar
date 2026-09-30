# Architettura

## In breve

Flutter con `provider`. Due stati condivisi (`AppState`, `DiaryState`), un repository che combina le fonti dei
pollini, servizi sottili per rete, file, avvisi e widget. Tutto è salvato in `SharedPreferences`: non c'è database
né backend.

```
Open-Meteo (previsioni) ─┐
                         ├─► PollenRepository.fetch ─► RawPollenData (cache JSON)
ISPRA WFS (misure) ──────┘                               │
                                                         ▼
                              PollenRepository.build ─► PollenSnapshot ─► AppState ─► schermate
                                                                             │
                                  AlertsService (background, ogni ora) ◄────┤
                                  WidgetBridge (widget_data) ◄──────────────┘
```

## Livelli

| Cartella | Ruolo |
|---|---|
| `lib/models/` | Tipi immutabili: `Allergen` (con soglie e calendari per area), `Level`, `Area`, `Place`, `Station`, `PollenSnapshot`, `DiaryEntry`, `AlertSettings` |
| `lib/services/` | I/O e piattaforma: `OpenMeteoClient`, `PollnetClient`, `AlertsService` + `AlertPlanner`, `LocationService`, `WidgetBridge`, `FileService`, `Backup`, `ReportPdf` |
| `lib/data/` | `PollenRepository`: scarica, mette in cache, sceglie la fonte di ogni allergene |
| `lib/state/` | `AppState` (luogo, allergeni, soglie, tema, avvisi, dati) e `DiaryState` (diario e farmaci) |
| `lib/screens/` | Schermate; nessuna logica di dominio |
| `lib/widgets/` | Componenti riutilizzabili: barra del rischio, pillole, chip della fonte, card, ricerca luogo, marchio |
| `lib/theme/` | `AppPalette` (token colore, chiaro e scuro) e `AppTheme` |
| `lib/utils/format.dart` | Date e numeri in italiano, senza `intl` per le date |

## Scelta della fonte (`PollenRepository`)

`fetch(place)` scarica sempre Open-Meteo. Poi prova fino a tre stazioni POLLnet entro 60 km: tiene la prima che
ha almeno una misura negli ultimi 10 giorni. Se ISPRA non risponde, va avanti senza misure.

`build(raw)` è pura, e per ogni allergene sceglie:

1. **Previsione**, se l'allergene ha variabili Open-Meteo e ci sono giorni validi (almeno 6 ore con dati).
2. **Misura**, se non ha previsione, c'è una stazione attiva e l'ultima misura ha al massimo 10 giorni.
3. **Stima**: livello del calendario dell'area (`Allergen.calendarFor(area)`) per il mese corrente.

L'area (`Area.north/centre/south`) è quella della regione della stazione POLLnet più vicina, a qualunque distanza.

La cache salva le risposte grezze (`RawPollenData`), non lo snapshot. Così l'app si ricostruisce offline e le
correzioni alla logica di `build` valgono anche sui dati già scaricati.

## Stato

- `AppState.load()` legge preferenze e cache senza rete. `init()` = `load()` + `refresh()` se i dati hanno più di un'ora.
- `AppState.dayLevel` è il livello peggiore tra gli allergeni seguiti; `aboveThreshold` confronta con la soglia personale (predefinita: Moderato).
- `DiaryState` tiene le voci per giorno (`yyyy-mm-dd`). Ogni voce salva i livelli di tutti gli allergeni di quel giorno (`pollen`), e da lì nascono andamento e confronto.
- L'intensità del giorno è il sintomo peggiore (0–3), non la media.

## Background, avvisi e widget

- `AlertsService.sync` registra un compito periodico di `workmanager` ogni ora, oppure lo cancella se gli avvisi sono spenti.
- `alertsCallbackDispatcher` → `AlertsService.runInBackground`: crea `AppState` e `DiaryState` sulle stesse preferenze, aggiorna i dati se vecchi, salva `widget_data`, chiede ad `AlertPlanner` cosa mandare e registra gli invii in `alerts_sent`.
- `AlertPlanner.plan`: ogni avviso parte una volta al giorno, nella prima esecuzione dopo il suo orario ed entro 3 ore.
- Widget: `AllergyWidgetProvider.kt` legge `flutter.widget_data` da `FlutterSharedPreferences`. L'app aperta lo aggiorna dal canale `dev.lorenzocaputo.allergyradar/widget`; ad app chiusa si ridisegna ogni 30 minuti (`updatePeriodMillis`).

## Chiavi salvate (SharedPreferences)

| Chiave | Contenuto | Nel backup |
|---|---|---|
| `place` | luogo scelto (JSON) | sì |
| `followed` | id degli allergeni seguiti | sì |
| `thresholds` | soglie personali per id (indice di `Level`) | sì |
| `onboarded` | primo avvio completato | sì |
| `theme` | `system` / `light` / `dark` | sì |
| `alerts` | `AlertSettings` (JSON) | sì |
| `diary` | voci del diario (JSON) | sì |
| `medications` | farmaci proposti nel diario | sì |
| `cache` | ultime risposte grezze delle fonti | no |
| `alerts_sent` | ultimo invio per tipo di avviso | no |
| `widget_data` | dati per il widget | no |

## Navigazione

`main.dart` mostra `OnboardingScreen` finché `onboarded` è falso, poi `HomeShell` con quattro schede: Oggi,
Diario, Calendario, Profilo. Dettaglio allergene, ricerca luogo, registrazione del diario, andamento e avvisi si
aprono con `Navigator.push`.

## Android

- Package `dev.lorenzocaputo.allergyradar`; `MainActivity.kt` espone il canale del widget.
- Permessi: `INTERNET`, `POST_NOTIFICATIONS`, `ACCESS_COARSE_LOCATION`. `allowBackup=false`.
- Icona di stato `@drawable/ic_stat_logo`, generata (vedi `development.md`).
