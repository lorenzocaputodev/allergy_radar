# Fonti dei dati

Tre tipi di dato, sempre dichiarati nell'interfaccia con `SourceChip`.

| Tipo (`DataKind`) | Fonte | Allergeni |
|---|---|---|
| `forecast` | Open-Meteo Air Quality (CAMS Europa) | Graminacee, olivo, ambrosia, artemisia, betulla + ontano |
| `measured` | POLLnet, servizio WFS di ISPRA | Parietaria (Urticacee), cipresso, quercia, piantaggine, Alternaria |
| `estimate` | Calendario storico per area, incluso nell'app | Chi non ha né previsione né misura |

## Open-Meteo

- Previsioni: `https://air-quality-api.open-meteo.com/v1/air-quality`, gratuito e senza chiave. Parametri: `latitude` e `longitude` arrotondati a 0,01°, `timezone=Europe/Rome`, `forecast_days=5`, `hourly=` variabili dei pollini (`grass_pollen`, `olive_pollen`, `ragweed_pollen`, `mugwort_pollen`, `birch_pollen`, `alder_pollen`) più `ozone`, `pm2_5`, `dust`.
- Modello CAMS Europa: celle di circa 11 km, circa 4 giorni utili; l'ultimo giorno è spesso incompleto e viene scartato (meno di 6 ore).
- Betulla e ontano sono un solo allergene: ora per ora si prende il massimo.
- Ricerca città: `https://geocoding-api.open-meteo.com/v1/search?name=…&countryCode=IT&language=it`. Non esiste la ricerca inversa, quindi la posizione GPS diventa «La mia posizione».
- Licenza dei dati: CC BY 4.0 (Copernicus/CAMS via Open-Meteo).

## ISPRA POLLnet (WFS)

- Pagina open data: https://pollnet.isprambiente.it/opendata/ (il vecchio `pollnet.it` è un dominio scaduto, non usarlo).
- Endpoint: `https://sdi.isprambiente.it/geoserver/om/ows?service=WFS&version=2.0.0&request=GetFeature`
  - `typeName=om:Concentrazione_pollini_spore` con `cql_filter=STAT_ID=… and PART_ID IN (…) and REMA_DATE between '…' and '…'`
  - `typeName=om:Stazioni_POLLnet`: elenco delle stazioni (copiato in `assets/data/stations.json`, senza la «Stazione TEST ISPRA»)
  - `typeName=om:Pollini_spore`: taxa con le soglie `PART_LOW`, `PART_MIDDLE`, `PART_HIGH`
- **Usa `outputFormat=csv`**: nel JSON le date risultano un giorno prima (effetto del fuso orario).
- I valori sono **giornalieri** (granuli/m³), pubblicati con alcuni giorni di ritardo. Una riga senza `REMA_CONCENTRATION` è un giorno non campionato.
- Nell'app: solo stazioni entro 60 km, al massimo tre tentativi, misura valida se ha al massimo 10 giorni.
- Licenza: CC BY 4.0 (POLLnet-SNPA, ISPRA).

### PART_ID usati

| Allergene | PART_ID | Taxon |
|---|---|---|
| Graminacee | 1352 | Gramineae |
| Parietaria | 1362 | Urticaceae |
| Olivo | 1391 | Olea |
| Cipresso | 1330 | Cupressaceae/Taxaceae |
| Quercia | 1384 | Quercus |
| Piantaggine | 1350 | Plantaginaceae |
| Artemisia | 1379 | Artemisia |
| Ambrosia | 1378 | Ambrosia |
| Betulla e ontano | 1323 | Betulaceae |
| Alternaria | 1364 | Alternaria (spora) |

## Soglie e livelli

`Level` va da 0 a 4: Nessuno, Basso, Moderato, Alto, Molto alto. Le soglie (`Thresholds(low, moderate, high)`)
sono le classi POLLnet lette da ISPRA; «Molto alto» vale 3 volte la soglia alta ed è un'estensione dell'app.

| Allergene | Basso da | Moderato da | Alto da |
|---|---|---|---|
| Graminacee | 0,5 | 10 | 30 |
| Parietaria | 2 | 20 | 70 |
| Olivo | 0,5 | 5 | 25 |
| Cipresso | 4 | 30 | 90 |
| Quercia | 1 | 20 | 40 |
| Piantaggine | 0,1 | 0,4 | 2 |
| Artemisia, Ambrosia | 0,1 | 5 | 25 |
| Betulla e ontano | 0,5 | 16 | 50 |
| Alternaria | 1 | 10 | 100 |

Aria (`AirStatus`): fasce ispirate all'indice europeo EAQI, adattate alla scala 0–4.

## Calendario stagionale (stime)

- Generato da `tool/build_calendar.mjs` (output in `tool/calendar.txt`), copiato in `lib/models/allergen.dart`.
- Metodo: per ogni stazione, la media giornaliera di ogni mese nel periodo 2016–2025 (serve una copertura di almeno 20 giorni in 10 mesi su 12). Poi la mediana tra le stazioni dell'area, classificata con le soglie (0–3).
- Stazioni di pianura o costa: Nord 12 (Torino, Alessandria, Genova, Bologna, Modena, Ferrara, Padova, Verona, Venezia Mestre, Trieste, Treviso, Ravenna); Centro 10 (Firenze, Roma, Perugia, Ancona, Siena, Grosseto, Arezzo, Terni, Pesaro, Lido di Camaiore); Sud e Isole 12 (Agrigento, Siracusa, Palermo, Trapani, Caserta, Benevento, Napoli, Termoli, Pescara, Reggio Calabria, Cagliari, Sassari).
- Area di una regione: `Area.ofRegion` (Nord: Piemonte, Valle d'Aosta, Lombardia, Liguria, Alto Adige, Trentino, Veneto, Friuli Venezia Giulia, Emilia Romagna; Centro: Toscana, Umbria, Marche, Lazio; tutto il resto è Sud e Isole).
- Una stima indica la stagione, non il giorno: l'interfaccia lo dice sempre.

## Situazione verificata (settembre 2026)

- Puglia: Bari (`STAT_ID` 161) e Brindisi (160) sono nell'elenco, ma tutte le loro righe hanno la concentrazione vuota (ultime date 2022 e 2023). I bollettini ARPA Puglia si fermano al 2021–2022. A Lecce e in Salento, quindi, la Parietaria è una stima.
- Le stazioni attive più vicine al Salento (Benevento, Napoli, Caserta, Termoli) sono oltre 250 km.
- Google Pollen API non include le Urticacee e ha un costo oltre la quota gratuita: non usata (ADR 0001).
