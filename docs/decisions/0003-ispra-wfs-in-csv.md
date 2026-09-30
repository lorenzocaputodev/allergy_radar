# 0003. Misure ISPRA dal WFS in CSV, chiamato dall'app

- Stato: Accettata
- Data: 2026-09-30

## Contesto

Il sito `pollnet.it` è un dominio scaduto. I dati POLLnet sono esposti da ISPRA su GeoServer
(`sdi.isprambiente.it`), con filtri CQL e output JSON o CSV.

## Decisione

- Una richiesta per stazione, con tutti i taxa senza previsione e gli ultimi 30 giorni.
- Formato CSV, letto con un piccolo parser che gestisce anche le virgolette.
- Corpo decodificato in UTF-8 dai byte.

## Alternative considerate

- Output JSON: le date `REMA_DATE` arrivano come il giorno precedente con suffisso `Z` (effetto del fuso) e andrebbero corrette a mano.

## Conseguenze

- Dati giornalieri, freschi di pochi giorni, senza intermediari.
- Se ISPRA cambia schema o endpoint, `PollnetClient.parseCsv` lancia un errore: l'app ripiega sulla stima e le previsioni restano.
