# 0005. Avvisi da un controllo orario e da un pianificatore puro

- Stato: Accettata
- Data: 2026-09-30

## Contesto

Gli avvisi dipendono da dati da scaricare (briefing, domani peggiora) o dallo stato del diario. Android limita il
lavoro in background; My Tracking App usa già `workmanager` e `flutter_local_notifications` con successo.

## Decisione

- Un compito periodico di `workmanager` ogni ora: aggiorna i dati se vecchi, salva i dati del widget, poi chiede ad `AlertPlanner` cosa mandare.
- `AlertPlanner.plan` è una funzione pura: ogni avviso parte una volta al giorno, nella prima esecuzione dopo l'orario scelto ed entro 3 ore.

## Alternative considerate

- Notifiche programmate a orario esatto (`zonedSchedule`): il testo sarebbe calcolato in anticipo con dati vecchi e servirebbero permessi di allarme esatto.

## Conseguenze

- Contenuti sempre calcolati con i dati del momento; logica testata senza plugin.
- Un avviso può arrivare fino a circa un'ora dopo l'orario. Con il risparmio energetico aggressivo può saltare: l'app suggerisce di escluderla dall'ottimizzazione della batteria.
