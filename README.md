# 🌾 Allergy Radar

> **Pollini della tua zona, con la fonte sempre in vista.**

- 🌿 Graminacee, Parietaria e altri 8 allergeni, con il livello di oggi e dei prossimi giorni
- 🔒 Senza account e senza pubblicità: i dati restano sul telefono

> Stato: **0.2, in sviluppo.** Funzionano primo avvio, Oggi, dettaglio allergene, Diario con andamento, Calendario e Profilo. Avvisi, posizione GPS e widget arrivano nelle prossime versioni.

---

## 🧭 Da dove arrivano i dati

Ogni valore nell'app dice di che tipo è:

| Tipo | Fonte | Allergeni | Note |
|---|---|---|---|
| **Previsione** | [Open-Meteo Air Quality](https://open-meteo.com/en/docs/air-quality-api), modello CAMS Europa | Graminacee, olivo, ambrosia, artemisia, betulla, ontano; ozono, PM2.5, polvere | Orario, circa 4 giorni, celle di circa 11 km. Gratuito, senza chiave |
| **Misurato** | [POLLnet](https://pollnet.isprambiente.it/opendata/) (ISPRA e ARPA), servizio WFS open data | Parietaria (Urticacee), cipresso, quercia, piantaggine, Alternaria | Valori giornalieri, pubblicati con alcuni giorni di ritardo. Solo stazioni entro 60 km con misure degli ultimi 10 giorni |
| **Stima** | Media storica del mese in 10 stazioni POLLnet del Sud, 2016–2025 (`tool/build_calendar.mjs`) | Quelli senza previsione né misura | Sempre marcata come stima: indica la stagione, non il giorno |

**La Parietaria non ha previsioni**: nessun modello europeo la calcola. Dove c'è una stazione POLLnet attiva vicina, l'app mostra la misura; altrimenti la media storica del mese.

**Puglia:** le stazioni di Bari e Brindisi non pubblicano più dati nella banca dati nazionale (ultime misure 2022–2023). In Salento, quindi, la Parietaria è la media storica del Sud; il diario dei sintomi aiuta a capire quanto conta per te.

Soglie: classi POLLnet (bassa, media, alta) lette dal servizio ISPRA. «Molto alto» vale 3 volte la soglia alta.

### Privacy

- Nessun account, nessuna analisi d'uso, nessun server nostro.
- A Open-Meteo vanno solo coordinate arrotondate a 0,01° (circa 1 km); a ISPRA solo il codice della stazione.
- L'ultima risposta resta in cache sul telefono: offline l'app mostra i dati con il loro orario.

---

## 🗂️ Struttura

```
lib/
  models/      Allergeni, livelli e soglie, luoghi, stazioni
  services/    Client Open-Meteo e POLLnet (ISPRA)
  data/        PollenRepository: sceglie la fonte per ogni allergene
  state/       AppState (provider) e preferenze
  screens/     Primo avvio, Oggi, dettaglio, diario, andamento, calendario, profilo
  widgets/     Barra del rischio, pillola livello, chip della fonte, card
  theme/       Token colore e tipografia (Fraunces, Figtree)
assets/data/stations.json   Stazioni POLLnet
test/fixtures/              Risposte reali di Open-Meteo e ISPRA
test_screens/               Screenshot a 412 dp per la revisione visiva (--update-goldens)
tool/build_calendar.mjs     Rigenera il calendario dagli storici ISPRA
```

Il design completo (schermate, sistema visivo, architettura) è nella canvas «Allergy Radar — Mockup».

---

## 🧰 Requisiti per compilare

Stessa toolchain di My Tracking App:

- Flutter **3.47.5** stable (Dart 3.13.4)
- Android SDK con platform **android-36**
- **JDK 21**, agganciato con `flutter config --jdk-dir "<percorso del JDK 21>"`
- Gradle 8.14.5, AGP 8.13.2, Kotlin 2.2.21

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Senza `android/key.properties` la release usa la chiave di debug.

---

## 📜 Licenze e attribuzioni

- Codice: [MIT](LICENSE)
- Dati di previsione: © Copernicus Atmosphere Monitoring Service, tramite Open-Meteo (CC BY 4.0)
- Misure: rete POLLnet-SNPA, ISPRA (CC BY 4.0)
- Font Fraunces e Figtree: SIL Open Font License (`assets/fonts/OFL-*.txt`)

L'app informa, non sostituisce il medico.
