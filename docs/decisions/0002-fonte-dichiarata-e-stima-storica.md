# 0002. Fonte sempre dichiarata; stima dalla media storica per area

- Stato: Accettata
- Data: 2026-09-30

## Contesto

Nessun modello europeo prevede la Parietaria. In Puglia le stazioni POLLnet non hanno misure nella banca dati
nazionale. Mostrare un numero senza dire da dove viene sarebbe fuorviante per chi decide se uscire o prendere
un farmaco.

## Decisione

- Ogni valore ha un tipo (`DataKind`): previsione, misurato o stima, mostrato con un chip.
- Senza previsione né misura recente (stazione entro 60 km, misura di al massimo 10 giorni), il livello è la media storica del mese nell'area (Nord, Centro, Sud e Isole), calcolata dagli storici POLLnet 2016–2025.
- L'area segue la regione della stazione POLLnet più vicina.

## Alternative considerate

- Usare la stazione attiva più vicina a qualunque distanza: per il Salento sarebbe Benevento, a circa 300 km, e la Parietaria cambia molto da luogo a luogo.
- Un calendario scritto a mano: il primo, per il Sud, dava la Parietaria «alta» a settembre, mentre i dati misurati dicono «bassa».

## Conseguenze

- L'app funziona in tutta Italia, anche dove mancano stazioni.
- Una stima indica la stagione, non il giorno: il diario dei sintomi colma la differenza per il singolo utente.
- Il calendario va rigenerato ogni qualche anno con `tool/build_calendar.mjs`.
