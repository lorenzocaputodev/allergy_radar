# Decisioni (ADR)

Ogni file registra una decisione importante: contesto, scelta e conseguenze. Formato: `NNNN-titolo.md`,
numerazione unica. Gli ADR non si riscrivono: se una scelta cambia, se ne aggiunge uno nuovo e il vecchio passa a
«Sostituita da NNNN». Modello: [0000-modello.md](0000-modello.md).

| N. | Decisione | Stato |
|---|---|---|
| [0001](0001-solo-open-data-senza-backend.md) | Solo open data, nessun backend e nessuna chiave | Accettata |
| [0002](0002-fonte-dichiarata-e-stima-storica.md) | Fonte sempre dichiarata; stima dalla media storica per area | Accettata |
| [0003](0003-ispra-wfs-in-csv.md) | Misure ISPRA dal WFS in CSV, chiamato dall'app | Accettata |
| [0004](0004-shared-preferences.md) | Tutto in SharedPreferences, niente database | Accettata |
| [0005](0005-avvisi-controllo-orario.md) | Avvisi da un controllo orario e da un pianificatore puro | Accettata |
| [0006](0006-toolchain-agp-8.md) | Toolchain Android sulla linea AGP 8.x | Accettata |
| [0007](0007-widget-nativo.md) | Widget nativo che legge le SharedPreferences | Accettata |
| [0008](0008-intensita-sintomo-peggiore.md) | Intensità del giorno = sintomo peggiore | Accettata |
