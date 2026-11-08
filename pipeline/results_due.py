"""Is a result due? Prints 'due=true' (for GitHub's step outputs) when a fixture kicked off between
FULL_TIME minutes and GIVE_UP hours ago. Finished Tests leave fixtures.json once the refresh has their
result, so a fixture still listed after full time means its result hasn't been picked up yet.

Used by .github/workflows/results-watch.yml, which then starts the data refresh. Run by hand:
    python pipeline/results_due.py
"""
import datetime as dt, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
FULL_TIME = 100        # minutes after kick-off: 80 minutes of play, half-time and stoppages
GIVE_UP = 8            # hours: after that the twice-daily refresh will catch it


def due(fixtures, now):
    out = []
    for f in fixtures:
        if not f.get('ko'): continue
        ko = dt.datetime.fromisoformat(f['ko'].replace('Z', '+00:00'))
        if dt.timedelta(minutes=FULL_TIME) <= now - ko <= dt.timedelta(hours=GIVE_UP):
            out.append('%s v %s (kick-off %s)' % (f['h'], f['a'], f['ko']))
    return out


if __name__ == '__main__':
    fixtures = json.load(open(os.path.join(HERE, 'fixtures.json'), encoding='utf-8'))
    waiting = due(fixtures, dt.datetime.now(dt.timezone.utc))
    for w in waiting:
        print('Result due:', w, file=sys.stderr)
    print('due=%s' % ('true' if waiting else 'false'))
