// Live scores for the app: rugbyanalysis.com/app/live.json.
//
// While a Test in the app's fixtures is on (from 15 minutes before kick-off to 3 hours after), this reads ESPN's
// public scoreboard for that competition: the score, the match minute and every try, conversion, penalty goal,
// drop goal and card with the player. No key, no cost. The answer is kept at Cloudflare's edge for 20 seconds,
// so ESPN is asked at most three times a minute per competition however many phones are watching.
//
// The shape (team names as the app's feeds write them):
//   {"asOf": "2026-11-28T16:52:10Z",
//    "games": [{"id": "604012", "g": "m", "h": "England", "a": "New Zealand", "ko": "2026-11-28T16:40:00Z",
//               "st": "live", "min": "12", "hs": 7, "as": 3,
//               "ev": [[3, "P", "a", "D. McKenzie"], [9, "T", "h", "T. Curry"], [10, "C", "h", "G. Ford"]]}]}
// st: "pre" (not started), "live", "ht" (half-time), "ft" (finished). min: ESPN's clock without the ' (can be "40+2").
// ev codes as in pipeline/espn_events.json: T try, PT penalty try, C conversion, P penalty goal, D drop goal,
// Y yellow card, R red card. Replacements are left out.

// ESPN league ids and the competition names the daily refresh gives their fixtures (TEST_LEAGUES in pipeline/update.py).
export const LEAGUES = {
  'Rugby World Cup': '164205', 'Six Nations Championship': '180659', 'Rugby Championship': '244293',
  'Nations Championship': '17567', 'Test match': '289234', "Women's Rugby World Cup": '289237', 'Tri Nations': '289274',
};
// Names ESPN writes differently from the feeds (ALIAS in pipeline/update.py).
const ALIAS = {
  'United States of America': 'United States', USA: 'United States', 'Bosnia-Herzegovina': 'Bosnia and Herzegovina',
  Czechia: 'Czech Republic', 'Korea Republic': 'South Korea', "Cote d'Ivoire": 'Ivory Coast', 'Hong Kong China': 'Hong Kong',
  'Chinese Taipei': 'Taiwan', 'Russian Federation': 'Russia', 'Türkiye': 'Turkey', Turkiye: 'Turkey',
};
const CODE = { try: 'T', 'penalty try': 'PT', conversion: 'C', 'penalty goal': 'P', 'drop goal': 'D', 'yellow card': 'Y', 'red card': 'R' };
const HOSTS = ['https://site.web.api.espn.com', 'https://site.api.espn.com'];
const BEFORE_MIN = 15, AFTER_MIN = 180, CACHE_S = 20;

export function teamName(espn) {
  const n = String(espn || '');
  const women = / Women$/.test(n);
  const base = n.replace(/ Women$/, '');
  return { name: ALIAS[base] || base, women };
}

/** Fixtures from matchday.json that are on now (or about to be), with the ESPN league to ask. */
export function onNow(md, now) {
  const out = [];
  for (const g of ['m', 'w']) {
    for (const f of (md && md[g] && md[g].fixtures) || []) {
      if (!f.ko) continue;
      const mins = (now - Date.parse(f.ko)) / 60000;
      if (mins < -BEFORE_MIN || mins > AFTER_MIN) continue;
      const lg = LEAGUES[String(f.c || '').split(' · ')[0]]; // 'Nations Championship · Round 4' in some feeds
      if (lg) out.push({ g, h: f.h, a: f.a, ko: f.ko, lg });
    }
  }
  return out;
}

/** ESPN's scoreboard dates for a kick-off: its UTC day, and the US day before when it kicks off early in the UTC day. */
export function espnDays(ko) {
  const t = Date.parse(ko);
  const day = (ms) => new Date(ms).toISOString().slice(0, 10).replace(/-/g, '');
  return [...new Set([day(t), day(t - 6 * 3600000)])];
}

function status(st) {
  const type = (st && st.type) || {};
  if (type.state === 'pre') return 'pre';
  if (type.state === 'post' || type.completed) return 'ft';
  if (/HALF/i.test(type.name || '') || /^HT$/i.test(type.shortDetail || '')) return 'ht';
  return 'live';
}

/** One ESPN scoreboard event as a game for the app, or null if it isn't one of [wanted]. */
export function game(ev, wanted) {
  const comp = (ev.competitions || [])[0] || {};
  const cs = comp.competitors || [];
  const home = cs.find((c) => c.homeAway === 'home') || cs[0];
  const away = cs.find((c) => c.homeAway === 'away') || cs[1];
  if (!home || !away) return null;
  const h = teamName(home.team && home.team.displayName), a = teamName(away.team && away.team.displayName);
  const g = h.women ? 'w' : 'm';
  // the feeds may list the sides the other way round from ESPN
  const fx = wanted.find((f) => f.g === g && ((f.h === h.name && f.a === a.name) || (f.h === a.name && f.a === h.name)));
  if (!fx) return null;
  const flip = fx.h !== h.name;
  const side = {};
  side[String(home.id)] = flip ? 'a' : 'h';
  side[String(away.id)] = flip ? 'h' : 'a';
  const rows = [];
  for (const d of comp.details || []) {
    const code = CODE[String((d.type && d.type.text) || '').toLowerCase()];
    if (!code) continue;
    const m = /\d+/.exec(String((d.clock && d.clock.displayValue) || ''));
    const minute = m ? +m[0] : Math.floor(((d.clock && d.clock.value) || 0) / 60) + 1;
    const who = ((d.athletesInvolved || [])[0] || {});
    rows.push([minute, code, side[String(d.team && d.team.id)] || '?', who.shortName || who.displayName || '', (d.clock && d.clock.value) || 0]);
  }
  rows.sort((x, y) => x[0] - y[0] || x[4] - y[4]);
  const st = ev.status || comp.status || {};
  const state = status(st);
  const score = (c) => (c.score === undefined || c.score === '' ? 0 : +c.score || 0);
  const hs = score(flip ? away : home), as = score(flip ? home : away);
  return {
    id: String(ev.id), g, h: fx.h, a: fx.a, ko: fx.ko, st: state,
    min: state === 'live' ? String(st.displayClock || '').replace(/['′\s]/g, '') : '',
    hs, as, ev: rows.map((r) => r.slice(0, 4)),
  };
}

async function scoreboard(lg, day) {
  for (const host of HOSTS) {
    try {
      const r = await fetch(`${host}/apis/site/v2/sports/rugby/${lg}/scoreboard?dates=${day}`, {
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; RugbyAnalysis live scores)' },
        cf: { cacheTtl: 10 },
      });
      if (r.ok) return (await r.json()).events || [];
      console.log('ESPN', host, lg, day, r.status);
    } catch (e) {
      console.log('ESPN', host, lg, day, String(e));
    }
  }
  return null;
}

/** The live document for [now], built from the app's matchday feed and ESPN. */
export async function build(md, now, fetchBoard = scoreboard) {
  const wanted = onNow(md, now);
  const asks = new Map();
  for (const f of wanted) for (const d of espnDays(f.ko)) asks.set(`${f.lg}|${d}`, [f.lg, d]);
  const boards = await Promise.all([...asks.values()].map(([lg, d]) => fetchBoard(lg, d)));
  const games = new Map();
  for (const evs of boards) for (const ev of evs || []) {
    const gm = game(ev, wanted);
    if (gm) games.set(gm.id, gm);
  }
  const doc = { asOf: new Date(now).toISOString().slice(0, 19) + 'Z', games: [...games.values()].sort((x, y) => x.ko.localeCompare(y.ko)) };
  if (wanted.length && boards.every((b) => b === null)) doc.error = 'ESPN did not answer';
  return doc;
}

const HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'access-control-allow-origin': '*',
  'cache-control': `public, max-age=${CACHE_S}`,
};

/** GET /app/live.json, answered from the edge cache when it's under 20 seconds old. */
export async function liveResponse(request, env, ctx) {
  const cache = caches.default;
  const key = new Request('https://rugbyanalysis.com/app/live.json');
  const hit = await cache.match(key);
  if (hit) return hit;
  let doc;
  try {
    const feed = await env.ASSETS.fetch('https://rugbyanalysis.com/app/matchday.json');
    doc = await build(feed.ok ? await feed.json() : {}, Date.now());
  } catch (e) {
    console.log('live.json failed:', String(e));
    doc = { asOf: new Date().toISOString().slice(0, 19) + 'Z', games: [], error: 'unavailable' };
  }
  const res = new Response(JSON.stringify(doc), { headers: HEADERS });
  ctx.waitUntil(cache.put(key, res.clone()));
  return res;
}
