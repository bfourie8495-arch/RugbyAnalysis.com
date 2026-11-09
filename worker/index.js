// The rugbyanalysis.com Worker. Pages come straight from ./site (Cloudflare serves those before this code
// runs); this script only answers what isn't a file (a 404), and keeps the results timely.
//
// Chat invites: /join/CODE is a small page that opens the app at that room (rugbyanalysis://app/join/CODE,
// see the app's AndroidManifest.xml), or sends you to Google Play if you don't have it yet. It shows the code
// too, for typing into the app by hand. The page says nothing about the room: the code is all there is.
//
// Every 15 minutes Cloudflare runs scheduled(). If a Test in the app's fixtures kicked off 100 minutes to
// 8 hours ago, its result is due but not in yet (finished Tests leave the fixtures once the refresh has them),
// so it starts GitHub's data refresh (update.yml), at most once every 25 minutes. Same rule as
// pipeline/results_due.py. GitHub's own schedules run hours late, Cloudflare's run on time.
//
// Needs the secret GH_DISPATCH_TOKEN: a fine-grained GitHub token for this repository only, with
// "Actions: read and write". It's passed in by .github/workflows/deploy.yml from the GitHub secret of the
// same name. Without it, the check runs and logs, but starts nothing.

const REPO = 'bfourie8495-arch/RugbyAnalysis.com';
const FULL_TIME_MIN = 100;
const GIVE_UP_HOURS = 8;
const GAP_MIN = 25;

export function due(fixtures, now) {
  const out = [];
  for (const f of fixtures || []) {
    if (!f.ko) continue;
    const mins = (now - Date.parse(f.ko)) / 60000;
    if (mins >= FULL_TIME_MIN && mins <= GIVE_UP_HOURS * 60) out.push(`${f.h} v ${f.a}`);
  }
  return out;
}

async function check(env) {
  const feed = await env.ASSETS.fetch('https://rugbyanalysis.com/app/matchday.json');
  if (!feed.ok) return console.log('No matchday feed:', feed.status);
  const md = await feed.json();
  const waiting = [...due(md.m && md.m.fixtures, Date.now()), ...due(md.w && md.w.fixtures, Date.now())];
  if (!waiting.length) return;
  console.log('Results due:', waiting.join(', '));
  if (!env.GH_DISPATCH_TOKEN) return console.log('No GH_DISPATCH_TOKEN, so not starting the refresh.');
  const gh = (path, init = {}) =>
    fetch(`https://api.github.com/repos/${REPO}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${env.GH_DISPATCH_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'User-Agent': 'rugbyanalysis-results-watch',
        'X-GitHub-Api-Version': '2022-11-28',
        ...(init.headers || {}),
      },
    });
  const runs = await gh('/actions/workflows/update.yml/runs?per_page=1');
  if (runs.ok) {
    const last = (await runs.json()).workflow_runs?.[0];
    if (last && Date.now() - Date.parse(last.created_at) < GAP_MIN * 60000) return console.log('A refresh started at', last.created_at);
  }
  const r = await gh('/actions/workflows/update.yml/dispatches', { method: 'POST', body: JSON.stringify({ ref: 'main' }) });
  console.log('Data refresh', r.status === 204 ? 'started' : `not started (${r.status}: ${await r.text()})`);
}

const PLAY = 'https://play.google.com/store/apps/details?id=com.rugbyanalysis.app';
const CODE = /^\/join\/([ABCDEFGHJKMNPQRSTUVWXYZ23456789]{12})\/?$/i;

export function joinPage(code) {
  const spaced = `${code.slice(0, 4)}-${code.slice(4, 8)}-${code.slice(8)}`;
  const intent = `intent://app/join/${code}#Intent;scheme=rugbyanalysis;package=com.rugbyanalysis.app;` +
    `S.browser_fallback_url=${encodeURIComponent(PLAY)};end`;
  return `<!doctype html>
<html lang="en-GB"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Join a chat on RugbyAnalysis</title>
<meta property="og:title" content="You're invited to a RugbyAnalysis chat">
<meta property="og:description" content="Watch the rugby with your friends. Tap to open the room in the RugbyAnalysis app.">
<meta property="og:image" content="https://rugbyanalysis.com/logo/icon-512.png">
<link rel="icon" type="image/png" sizes="180x180" href="/logo/icon-180.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Figtree:wght@400..800&display=swap" rel="stylesheet">
<style>
  body { margin: 0; background: #0E1B30; color: #F4EFE4; font: 400 17px/1.5 Figtree, system-ui, sans-serif; }
  main { max-width: 440px; margin: 0 auto; padding: 40px 20px; text-align: center; }
  img { width: 72px; height: 72px; border-radius: 18px; }
  h1 { font-size: 26px; margin: 18px 0 6px; }
  p { color: #A9B3C4; margin: 0 0 18px; }
  .btn { display: block; padding: 15px; border-radius: 30px; font-weight: 800; text-decoration: none; margin: 10px 0; }
  .open { background: #C9A24B; color: #10213A; }
  .get { border: 1px solid #2A4066; color: #F4EFE4; }
  .code { background: #14243D; border: 1px solid #24385A; border-radius: 16px; padding: 14px; margin: 22px 0 8px; }
  .code b { display: block; font-size: 26px; letter-spacing: 1px; color: #E2C27A; }
  small { color: #97A3BA; }
</style></head>
<body><main>
  <img src="/logo/icon-180.png" alt="RugbyAnalysis">
  <h1>You're invited to a chat</h1>
  <p>A friend wants to watch the rugby with you in the RugbyAnalysis app.</p>
  <a class="btn open" href="${intent}">Open in the app</a>
  <a class="btn get" href="${PLAY}">Get the app on Google Play</a>
  <div class="code"><small>ROOM CODE</small><b>${spaced}</b></div>
  <small>No luck? Open the app, go to Chat, tap "Join with a code" and enter the code above.</small>
</main></body></html>`;
}

export default {
  fetch: (request, env) => {
    const m = CODE.exec(new URL(request.url).pathname);
    if (m) {
      return new Response(joinPage(m[1].toUpperCase()), {
        headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'referrer-policy': 'no-referrer' },
      });
    }
    return env.ASSETS.fetch(request);
  },
  scheduled: (event, env, ctx) => ctx.waitUntil(check(env)),
};
