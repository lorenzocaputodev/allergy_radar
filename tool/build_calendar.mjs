// --- Configurazione ---
const AREAS = {
  north: [197, 148, 91, 118, 122, 120, 166, 152, 55, 84, 104, 126],
  centre: [69, 195, 80, 163, 193, 157, 162, 140, 159, 70],
  south: [192, 165, 191, 144, 138, 137, 131, 154, 89, 156, 164, 158],
};
const ALLERGENS = {
  grass: [1352, 0.5, 10, 30], parietaria: [1362, 2, 20, 70], olive: [1391, 0.5, 5, 25],
  cypress: [1330, 4, 30, 90], oak: [1384, 1, 20, 40], plantago: [1350, 0.1, 0.4, 2],
  mugwort: [1379, 0.1, 5, 25], ragweed: [1378, 0.1, 5, 25], birch: [1323, 0.5, 16, 50],
  alternaria: [1364, 1, 10, 100], hazel: [1329, 0.5, 16, 50], plane: [1351, 1, 20, 40],
  chenopod: [1327, 0.1, 5, 25], ash: [1417, 0.5, 5, 25], chestnut: [1386, 1, 20, 40],
};
const FROM = '2016-01-01';
const TO = '2025-12-31';
const MIN_DAYS = 20;
const MIN_MONTHS = 10;
const MAX_ROWS = 3000;
const PARALLEL = 6;

// --- CSV ISPRA ---
function splitCsvLine(line) {
  const out = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quoted) {
      if (c === '"' && line[i + 1] === '"') {
        field += '"';
        i++;
      } else if (c === '"') {
        quoted = false;
      } else {
        field += c;
      }
    } else if (c === '"') {
      quoted = true;
    } else if (c === ',') {
      out.push(field);
      field = '';
    } else {
      field += c;
    }
  }
  out.push(field);
  return out;
}

async function fetchRows(station, from, to) {
  const parts = Object.values(ALLERGENS).map(([part]) => part).join(',');
  const cql = `STAT_ID=${station} and PART_ID IN (${parts}) and REMA_DATE between '${from}' and '${to}'`;
  const url = 'https://sdi.isprambiente.it/geoserver/om/ows?service=WFS&version=2.0.0&request=GetFeature'
    + `&typeName=om:Concentrazione_pollini_spore&outputFormat=csv&cql_filter=${encodeURIComponent(cql)}`;
  for (let attempt = 0; ; attempt++) {
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`ISPRA ${res.status}`);
      const [head, ...rows] = (await res.text()).trim().split(/\r?\n/).map(splitCsvLine);
      if (rows.length >= MAX_ROWS) throw new Error(`Risposta troncata: ${station} ${from}`);
      const ip = head.indexOf('PART_ID');
      const iv = head.indexOf('REMA_CONCENTRATION');
      const id = head.indexOf('REMA_DATE');
      if (ip < 0 || iv < 0 || id < 0) throw new Error('Formato CSV ISPRA inatteso');
      return rows
        .filter((r) => r.length === head.length && r[iv] !== '' && Number.isFinite(Number(r[iv])))
        .map((r) => [Number(r[ip]), Number(r[id].slice(5, 7)) - 1, Number(r[iv])]);
    } catch (e) {
      if (attempt >= 2) throw e;
      await new Promise((resolve) => setTimeout(resolve, 2000 * (attempt + 1)));
    }
  }
}

async function stationMonthlyMeans(station) {
  const quarters = [];
  for (let y = Number(FROM.slice(0, 4)); y <= Number(TO.slice(0, 4)); y++) {
    for (const [a, b] of [['01-01', '03-31'], ['04-01', '06-30'], ['07-01', '09-30'], ['10-01', '12-31']]) {
      quarters.push([`${y}-${a}`, `${y}-${b}`]);
    }
  }
  const rows = [];
  for (let i = 0; i < quarters.length; i += PARALLEL) {
    const chunk = await Promise.all(quarters.slice(i, i + PARALLEL).map(([a, b]) => fetchRows(station, a, b)));
    rows.push(...chunk.flat());
  }
  const out = {};
  for (const [part] of Object.values(ALLERGENS)) {
    const sum = Array(12).fill(0);
    const n = Array(12).fill(0);
    for (const [p, month, value] of rows) {
      if (p !== part || !(month >= 0 && month < 12)) continue;
      sum[month] += value;
      n[month]++;
    }
    out[part] = n.filter((x) => x >= MIN_DAYS).length < MIN_MONTHS ? null : sum.map((s, i) => (n[i] ? s / n[i] : null));
  }
  return out;
}

// --- Calendari ---
const median = (v) => {
  const s = v.filter((x) => x != null).sort((a, b) => a - b);
  if (!s.length) return 0;
  const k = s.length >> 1;
  return s.length % 2 ? s[k] : (s[k - 1] + s[k]) / 2;
};

const byStation = {};
for (const s of Object.values(AREAS).flat()) {
  byStation[s] = await stationMonthlyMeans(s);
  console.error(`stazione ${s} letta`);
}

const only = process.argv.slice(2);
for (const [name, [part, low, moderate, high]] of Object.entries(ALLERGENS)) {
  if (only.length && !only.includes(name)) continue;
  console.log(`${name}:`);
  for (const [area, stations] of Object.entries(AREAS)) {
    const ok = stations.map((s) => byStation[s][part]).filter(Boolean);
    const means = Array.from({ length: 12 }, (_, m) => median(ok.map((s) => s[m])));
    const cal = means.map((v) => (v < low ? 0 : v < moderate ? 1 : v < high ? 2 : 3));
    console.log(`      Area.${area}: [${cal.join(', ')}],`);
    console.error(`${name} ${area}: ${ok.length} stazioni; ${means.map((v) => v.toFixed(1)).join(' ')}`);
  }
}
