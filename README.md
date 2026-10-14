# RugbyAnalysis.com

This repository holds the site and the data pipeline that keeps it up to date.
Every morning a GitHub job pulls the latest results, fixtures, team stats,
line-ups, player profiles and World Rugby rankings, rebuilds the pages and saves
them here. Cloudflare sees the change and redeploys rugbyanalysis.com within a
minute or two. Nobody needs to touch anything.

## What updates by itself

| Updated daily | Source |
|---|---|
| Test results (men's; women's World Cup) | ESPN match centres |
| Upcoming Test fixtures and model picks (men's and women's) | ESPN, World Rugby rankings |
| Team match stats, line-ups, player stats | ESPN |
| New players' height, weight, date of birth | ESPN |
| World Rugby rankings (men and women) | World Rugby (Wikipedia's copy if World Rugby is down) |
| Club results, fixtures and tables: URC, Premiership, Top 14, Super Rugby Pacific, Champions Cup, Challenge Cup, NPC | ESPN |
| Currie Cup: results, scorers, cards and fixtures | Wikipedia |
| Women's Tests outside World Cups (Six Nations, WXV, Pacific Four, Rugby Europe) and men's Pacific Nations Cup and Rugby Europe Championship: results, scorers, upcoming fixtures and model picks | Wikipedia |
| Premiership Women's Rugby: results, fixtures and tables | Wikipedia |
| Japan League One: fixtures, kick-offs, venues and results | League One's official site (league-one.jp), with scorers, cards and the table from Wikipedia |
| Yellow and red cards for the Wikipedia competitions | Wikipedia (team sheets or the match box's "Cards" line) |
| Sevens: each leg's winner, runner-up and final score, and series standings | Wikipedia |
| Current squads and official caps (Mondays) | Wikipedia |

Records, win rates, head-to-heads, trophy holders, form guides, leaderboards and
league tables are all recalculated from the data on every run.

To add a fixture the feed misses (for example a women's Test), add a line to
`pipeline/fixtures.json` with `"manual": true` (and `"g": "w"` for a women's
Test); it stays in the Match Centre until its date has passed.

The Wikipedia reader (`pipeline/wiki_feed.py`) reads the standard match boxes on
each competition's page. If a page isn't up yet, or has far fewer matches than we
already hold, that competition is left as it is for the day.

ESPN is read from `site.web.api.espn.com`, because `site.api.espn.com` refuses
GitHub's servers. If a source refuses or stops answering, the run carries on with
the data it already has and shows a yellow warning on the run's page in the
Actions tab.

Cards are only filled in where Wikipedia records them; a page that notes cards
for most of its matches is taken to list all of them.

## Folder layout

```
site/                  the finished website (what Cloudflare serves)
pipeline/update.py     downloads new data into the files in pipeline/
pipeline/wiki_feed.py  reads results and fixtures from Wikipedia pages
pipeline/build_all.py  rebuilds site/ from those files
pipeline/*.csv, *.json the data
pipeline/matchday.js   the Match Centre landing page and head-to-head page
               (+ matchday.css), slotted into template.html by build.py
.github/workflows/update.yml  the daily schedule
.github/workflows/deploy.yml  publishes site/ to Cloudflare after every change
wrangler.jsonc         tells Cloudflare to serve the site/ folder
```

## Running it yourself

```
pip install -r pipeline/requirements.txt
python pipeline/update.py      # fetch new data
python pipeline/build_all.py   # rebuild site/
```

To run the refresh straight away on GitHub: Actions tab → "Daily data refresh"
→ "Run workflow".

## Deploying

`deploy.yml` publishes `site/` to Cloudflare whenever `main` changes and after
each daily refresh. It needs two repository secrets (Settings → Secrets and
variables → Actions): `CLOUDFLARE_API_TOKEN` (a Cloudflare API token made from the
"Edit Cloudflare Workers" template) and `CLOUDFLARE_ACCOUNT_ID`. To redeploy by
hand: Actions tab → "Deploy site to Cloudflare" → "Run workflow".
