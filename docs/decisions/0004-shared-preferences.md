# 0004. Tutto in SharedPreferences, niente database

- Stato: Accettata
- Data: 2026-09-30

## Contesto

Da salvare: impostazioni, una voce di diario al giorno (circa 200 byte), la cache delle ultime risposte. Il
background e il widget nativo devono leggere gli stessi dati.

## Decisione

Tutto in `shared_preferences`, con valori JSON dove serve. Il widget Kotlin legge `flutter.widget_data` dal file
`FlutterSharedPreferences`.

## Alternative considerate

- drift o SQLite: più potenti, ma una dipendenza e uno schema da migrare per poche decine di KB all'anno.

## Conseguenze

- Backup semplice: si esportano le chiavi elencate in `AppState.backupKeys` e `DiaryState.backupKeys`.
- Il diario si riscrive tutto a ogni salvataggio: va bene per anni di voci. Se diventasse lento, si passa a un database con un nuovo ADR.
