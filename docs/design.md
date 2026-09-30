# Design

I mockup completi (22 tavole, con specifiche) sono nella canvas «Allergy Radar — Mockup»:
https://claude.ai/artifact/XwuwWPQwUB7GQHT9r79Kay (privata). L'app ne segue struttura e sistema visivo, con
alcune differenze venute dopo, dai dati reali: vedi in fondo.

## Principi

- **La fonte è sempre visibile**: previsione, misura o stima, con un chip accanto a ogni valore.
- **Il livello non è mai solo colore**: parola, barra a 4 segmenti e colore insieme.
- **Onestà sui dati mancanti**: se una misura non c'è si dice perché, invece di inventarla o nasconderla.
- **Una sola azione principale per schermata**; i pulsanti principali restano visibili in basso.
- **Telefono di riferimento**: 412 dp di larghezza (Motorola Edge 50 Fusion); i test di interfaccia girano a 360 dp.

## Colori (`lib/theme/palette.dart`)

| Token | Chiaro | Scuro | Uso |
|---|---|---|---|
| `bg` | #F4F2EB | #121715 | Sfondo |
| `card` | #FFFFFF | #1B221F | Card, barra di navigazione |
| `ink` / `ink2` / `ink3` | #17201C / #46514B / #5C6661 | #ECEFEA / #B9C2BC / #9AA49E | Testo principale, secondario, didascalie |
| `pine` | #1F5A4A | #7CC4A8 | Azioni, selezione |
| `hero` | #1F5A4A | #1E3A31 | Riquadro «La tua giornata» |

Scala del rischio (0–4, fill): #E4E1D7, #EFD27F, #E59A48, #C4502B, #7A2338. La luminosità scende a ogni livello,
quindi la scala si legge anche con il daltonismo rosso-verde; niente verde per «basso», perché il verde è
l'accento dell'app. Il testo sui fill è scuro per i livelli 1–2 e bianco per 3–4; le parole colorate su bianco
usano `riskText`.

La scala dei sintomi è separata e usa la tinta dell'accento: #ECEEE8, #CFE0D6, #86B5A0, #2F6B58.

## Tipografia

- **Fraunces** (titoli, livelli, numeri grandi) e **Figtree** (tutto il resto), inclusi negli asset, sottoinsieme latino.
- Il sottoinsieme non ha «≥»: si scrive «da 210». Gli spazi non separabili tengono insieme numero e unità.

## Componenti (`lib/widgets/`)

- `RiskBar`, `LevelPill` (larghezza minima uguale per tutti i livelli), `LevelWord`, `SourceChip`, `AllergenGlyph`, `SectionCard`, `SeasonStrip`
- `AllergenCard`, `PlaceSearch`, `RadarMark` (il marchio: icona, benvenuto, banner)

## Differenze rispetto ai mockup

- La Parietaria ha dati **giornalieri** da ISPRA (non bollettini settimanali) oppure una **media storica**; non esiste una «stazione di Lecce».
- Calendario per area (Nord, Centro, Sud e Isole), non solo Salento.
- Icone degli allergeni: per ora quelle di Material (i glifi botanici dei mockup sono nella roadmap).
- Un solo luogo alla volta, con ricerca o posizione; i luoghi salvati sono nella roadmap.
