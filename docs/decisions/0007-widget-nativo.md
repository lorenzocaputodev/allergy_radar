# 0007. Widget nativo che legge le SharedPreferences

- Stato: Accettata
- Data: 2026-09-30

## Contesto

Il widget deve aggiornarsi anche ad app chiusa, dopo il controllo in background. My Tracking App ha già un widget
nativo con un canale di aggiornamento.

## Decisione

- `AllergyWidgetProvider.kt` (RemoteViews) legge `flutter.widget_data`, scritto da `WidgetBridge.save` sia dall'app sia dal background.
- L'app aperta forza il ridisegno dal canale `dev.lorenzocaputo.allergyradar/widget`; altrimenti ogni 30 minuti (`updatePeriodMillis`).

## Alternative considerate

- Il pacchetto `home_widget`: comodo, ma una dipendenza in più per qualcosa che My Tracking App fa già senza.

## Conseguenze

- Nessuna dipendenza in più; i colori dei livelli sono duplicati in Kotlin e vanno tenuti allineati ad `AppPalette`.
- In background non si può chiamare il canale: il widget si aggiorna al suo giro successivo.
