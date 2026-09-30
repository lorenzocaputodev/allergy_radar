# Documentazione

Documentazione tecnica di Allergy Radar, per chi sviluppa l'app (persone o assistenti AI) e parte senza contesto.
Il [README](../README.md) nella radice presenta l'app agli utenti; le regole da tenere sempre a mente sono in
[CLAUDE.md](../CLAUDE.md).

| Documento | Quando leggerlo |
|---|---|
| [architecture.md](architecture.md) | Prima di toccare il codice: livelli, flusso dei dati, stato, background, widget |
| [data-sources.md](data-sources.md) | Per tutto ciò che riguarda pollini, soglie, calendari, Open-Meteo e ISPRA |
| [development.md](development.md) | Ambiente, comandi, test, asset generati, CI e procedura di release |
| [design.md](design.md) | Colori, tipografia, componenti e principi dell'interfaccia |
| [roadmap.md](roadmap.md) | Limiti noti e prossimi passi |
| [decisions/](decisions/README.md) | Le decisioni importanti, con il perché (ADR) |

## Stato

- Versione pubblicata: **1.0.0**, release privata `v1.0.0` su GitHub con APK firmato con la chiave di debug.
- Piattaforma di riferimento: Android. Windows serve per provare l'interfaccia sul PC.

## Come tenere aggiornata questa cartella

- Una decisione che cambia l'architettura, una fonte di dati o la toolchain → nuovo ADR in `decisions/`.
  Gli ADR non si riscrivono: se una scelta cambia, il vecchio passa a «Sostituita da NNNN».
- Un nuovo comando, script o passaggio di release → `development.md`.
- Una nuova schermata o un nuovo componente → `architecture.md` (mappa dei file) e, se cambia lo stile, `design.md`.
- Una regola che serve in ogni sessione (e solo quella) → `CLAUDE.md`, restando sotto le 200 righe.
