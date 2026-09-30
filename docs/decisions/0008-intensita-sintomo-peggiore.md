# 0008. Intensità del giorno = sintomo peggiore

- Stato: Accettata
- Data: 2026-09-30

## Contesto

Il diario registra quattro sintomi da 0 a 3. Con la media, «naso medio, occhi lieve» diventava una giornata
«lieve», e il calendario del diario sottostimava i giorni pesanti.

## Decisione

`DiaryEntry.severity` e `score` sono il sintomo peggiore del giorno. Stessa misura per calendario, statistiche,
andamento, confronto con i pollini, CSV e PDF.

## Conseguenze

- Più vicino a come una persona giudica la giornata.
- Un giorno con molti sintomi lievi pesa come uno con un solo sintomo lieve: il dettaglio resta nella voce.
