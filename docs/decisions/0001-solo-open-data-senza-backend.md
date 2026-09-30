# 0001. Solo open data, nessun backend e nessuna chiave

- Stato: Accettata
- Data: 2026-09-30

## Contesto

L'app deve essere gratuita, rispettare la privacy come My Tracking App e non avere costi di esercizio. Servono
previsioni dei pollini e misure per quelli che i modelli non calcolano, come la Parietaria.

## Decisione

- Previsioni da Open-Meteo Air Quality (CAMS Europa): gratuito, senza chiave, con i pollini principali più ozono, PM2.5 e polvere.
- Misure dalla rete POLLnet tramite il WFS open data di ISPRA (CC BY 4.0).
- L'app chiama direttamente le due fonti: nessun server nostro, nessun account, nessuna analisi d'uso.

## Alternative considerate

- Google Pollen API: non ha le Urticacee (Parietaria), richiede la fatturazione attiva e la quota gratuita (5.000 chiamate al mese) si divide tra tutti gli utenti di un APK pubblico.
- Un job che legge i bollettini ARPA e pubblica un JSON statico: superfluo, perché il WFS dà già valori giornalieri.

## Conseguenze

- Costo zero, e la privacy si spiega in una riga.
- La qualità dipende dalle fonti: previsioni a circa 11 km, misure solo dove esistono stazioni attive.
- Nessuna notifica push dal server: gli avvisi nascono sul telefono (ADR 0005).
