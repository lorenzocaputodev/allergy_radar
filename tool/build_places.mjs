// --- Configurazione ---
import { readFileSync, writeFileSync } from 'node:fs';

const REGIONS = [
  'Abruzzo', 'Basilicata', 'Calabria', 'Campania', 'Emilia-Romagna', 'Friuli Venezia Giulia', 'Lazio', 'Liguria',
  'Lombardia', 'Marche', 'Molise', 'Piemonte', 'Puglia', 'Sardegna', 'Sicilia', 'Toscana', 'Trentino-Alto Adige',
  'Umbria', 'Valle d’Aosta', 'Veneto',
];
const SEATS = { PPLC: 0, PPLA: 1, PPLA2: 2, PPLA3: 3 };
const OUT = 'assets/data/places.json';

// --- Lettura del dump GeoNames ---
const input = process.argv[2];
if (!input) {
  console.error('Uso: node tool/build_places.mjs <IT.txt da https://download.geonames.org/export/dump/IT.zip>');
  process.exit(1);
}

const comuni = new Map();
const seats = new Map();
for (const line of readFileSync(input, 'utf8').split('\n')) {
  const f = line.split('\t');
  if (f.length < 15 || !f[12]) continue;
  const key = `${f[10]}|${f[11]}|${f[12]}`;
  if (f[7] === 'ADM3') comuni.set(key, f);
  if (f[6] === 'P' && f[7] in SEATS) {
    const best = seats.get(key);
    if (!best || SEATS[f[7]] < SEATS[best[7]] || (SEATS[f[7]] === SEATS[best[7]] && Number(f[14]) > Number(best[14]))) {
      seats.set(key, f);
    }
  }
}

// --- Comuni: nome ufficiale ISTAT, coordinate del capoluogo ---
const places = [];
for (const [key, c] of comuni) {
  const region = REGIONS[Number(c[10]) - 1];
  if (!region) continue;
  const seat = seats.get(key) ?? c;
  places.push({
    name: c[1].split('/')[0].trim(),
    region,
    lat: Math.round(Number(seat[4]) * 10000) / 10000,
    lon: Math.round(Number(seat[5]) * 10000) / 10000,
    pop: Math.max(Number(seat[14]) || 0, Number(c[14]) || 0),
  });
}

// --- Scrittura ---
places.sort((a, b) => b.pop - a.pop || a.name.localeCompare(b.name, 'it'));
const rows = places.map((p) => [p.name, REGIONS.indexOf(p.region), p.lat, p.lon]);
writeFileSync(OUT, JSON.stringify({ source: 'GeoNames (CC BY 4.0)', regions: REGIONS, places: rows }));
console.error(`${places.length} comuni in ${OUT}`);
