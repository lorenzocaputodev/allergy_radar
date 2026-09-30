// Ricava il calendario stagionale dagli storici POLLnet (ISPRA, CC BY 4.0).
//
//   node tool/build_calendar.mjs            (Node 18+)
//
// Per ogni allergene: media giornaliera per mese su ogni stazione, poi mediana
// tra le stazioni, classificata con le soglie POLLnet (0 assente … 3 alto).
// Stampa gli array da copiare in lib/models/allergen.dart.

const STATIONS = {
  192: 'Agrigento', 165: 'Siracusa', 191: 'Palermo', 144: 'Trapani', 138: 'Caserta',
  137: 'Benevento', 131: 'Napoli', 154: 'Termoli', 89: 'Pescara', 156: 'Reggio Calabria',
};
const ALLERGENS = {
  grass: [1352, 0.5, 10, 30], parietaria: [1362, 2, 20, 70], olive: [1391, 0.5, 5, 25],
  cypress: [1330, 4, 30, 90], oak: [1384, 1, 20, 40], plantago: [1350, 0.1, 0.4, 2],
  mugwort: [1379, 0.1, 5, 25], ragweed: [1378, 0.1, 5, 25], birch: [1323, 0.5, 16, 50],
  alternaria: [1364, 1, 10, 100],
};
const FROM = '2016-01-01';
const TO = '2025-12-31';

async function series(station, part) {
  const cql = `STAT_ID=${station} and PART_ID=${part} and REMA_DATE between '${FROM}' and '${TO}'`;
  const url = 'https://sdi.isprambiente.it/geoserver/om/ows?service=WFS&version=2.0.0&request=GetFeature'
    + `&typeName=om:Concentrazione_pollini_spore&outputFormat=csv&cql_filter=${encodeURIComponent(cql)}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`ISPRA ${res.status}`);
  const [head, ...rows] = (await res.text()).trim().split(/\r?\n/).map((l) => l.split(','));
  const iv = head.indexOf('REMA_CONCENTRATION');
  const id = head.indexOf('REMA_DATE');
  const sum = Array(12).fill(0);
  const n = Array(12).fill(0);
  for (const r of rows) {
    if (r[iv] === '') continue;
    const m = Number(r[id].slice(5, 7)) - 1;
    sum[m] += Number(r[iv]);
    n[m]++;
  }
  // Copertura minima: almeno 20 giorni misurati in 10 mesi su 12.
  if (n.filter((x) => x >= 20).length < 10) return null;
  return sum.map((s, i) => (n[i] ? s / n[i] : null));
}

const median = (v) => {
  const s = v.filter((x) => x != null).sort((a, b) => a - b);
  if (!s.length) return 0;
  const k = s.length >> 1;
  return s.length % 2 ? s[k] : (s[k - 1] + s[k]) / 2;
};

for (const [name, [part, low, moderate, high]] of Object.entries(ALLERGENS)) {
  const perStation = (await Promise.all(Object.keys(STATIONS).map((s) => series(s, part)))).filter(Boolean);
  const means = Array.from({ length: 12 }, (_, m) => median(perStation.map((s) => s[m])));
  const cal = means.map((v) => (v < low ? 0 : v < moderate ? 1 : v < high ? 2 : 3));
  console.log(`${name.padEnd(11)} calendar: [${cal.join(', ')}],  // ${perStation.length} stazioni; medie ${means.map((v) => v.toFixed(1)).join(' ')}`);
}
