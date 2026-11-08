// The rugbyanalysis.com Worker. Pages come straight from ./site (Cloudflare serves those before this code
// runs); this script only answers what isn't a file (a 404), and keeps the results timely:
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

export default {
  fetch: (request, env) => env.ASSETS.fetch(request),
  scheduled: (event, env, ctx) => ctx.waitUntil(check(env)),
};
