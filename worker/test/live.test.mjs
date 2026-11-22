// node --test worker/test/live.test.mjs  (the live scores in worker/live.js, against a real ESPN scoreboard: Wales 26-29 Australia)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { build, espnDays, game, onNow, teamName } from '../live.js';

const board = JSON.parse(readFileSync(new URL('./scoreboard_wal_aus.json', import.meta.url)));
const md = {
  m: { fixtures: [
    { h: 'Wales', a: 'Australia', c: 'Nations Championship', ko: '2026-11-21T20:10:00Z' },
    { h: 'Tunisia', a: 'Poland', c: 'Test match', ko: '2026-11-24T14:00:00Z' },
    { h: 'Fiji', a: 'Samoa', c: 'Nations Championship · Round 4', ko: '2026-11-22T20:00:00Z' },
    { h: 'Spain', a: 'Chile', c: 'Rugby Europe', ko: '2026-11-21T20:00:00Z' }, // not on ESPN
  ] },
  w: { fixtures: [] },
};
const during = Date.parse('2026-11-21T21:00:00Z');

test('only fixtures from 15 minutes before kick-off to 3 hours after, in a competition ESPN covers', () => {
  assert.deepEqual(onNow(md, during), [{ g: 'm', h: 'Wales', a: 'Australia', ko: '2026-11-21T20:10:00Z', lg: '17567' }]);
  assert.equal(onNow(md, Date.parse('2026-11-21T19:50:00Z')).length, 0);
  assert.equal(onNow(md, Date.parse('2026-11-21T19:56:00Z')).length, 1);
  assert.equal(onNow(md, Date.parse('2026-11-21T23:11:00Z')).length, 0);
  assert.equal(onNow(md, Date.parse('2026-11-22T20:30:00Z'))[0].lg, '17567'); // a round after the name
});

test('ESPN days: the UTC day, and the day before for an early-morning UTC kick-off', () => {
  assert.deepEqual(espnDays('2026-11-21T20:10:00Z'), ['20261121']);
  assert.deepEqual(espnDays('2026-11-22T02:00:00Z'), ['20261122', '20261121']);
});

test('names as the feeds write them', () => {
  assert.deepEqual(teamName('England Women'), { name: 'England', women: true });
  assert.deepEqual(teamName('USA'), { name: 'United States', women: false });
});

test('a finished game: score, state and the scoring events with players, no replacements', () => {
  const g = game(board.events[0], onNow(md, during));
  assert.equal(g.st, 'ft');
  assert.equal(g.min, '');
  assert.deepEqual([g.h, g.a, g.hs, g.as], ['Wales', 'Australia', 26, 29]);
  assert.equal(g.ev.length, 17);
  assert.deepEqual(g.ev[0], [2, 'Y', 'h', 'M. Llewellyn']);
  assert.deepEqual(g.ev[1], [21, 'T', 'a', 'T. Tupou']);
  assert.deepEqual(g.ev.at(-1), [79, 'T', 'h', 'R. Elias']);
  // the events add up to the score
  const pts = { T: 5, PT: 7, C: 2, P: 3, D: 3 };
  const sum = (s) => g.ev.filter((e) => e[2] === s).reduce((n, e) => n + (pts[e[1]] || 0), 0);
  assert.deepEqual([sum('h'), sum('a')], [26, 29]);
});

test('a live game: the minute, and sides turned round when the feed lists them the other way', () => {
  const ev = structuredClone(board.events[0]);
  ev.status = { displayClock: "54'", period: 2, type: { name: 'STATUS_IN_PROGRESS', state: 'in', completed: false } };
  const flipped = [{ g: 'm', h: 'Australia', a: 'Wales', ko: '2026-11-21T20:10:00Z', lg: '17567' }];
  const g = game(ev, flipped);
  assert.deepEqual([g.st, g.min, g.h, g.hs, g.as], ['live', '54', 'Australia', 29, 26]);
  assert.deepEqual(g.ev[0], [2, 'Y', 'a', 'M. Llewellyn']);
  ev.status = { displayClock: "40'", period: 1, type: { name: 'STATUS_HALFTIME', state: 'in', completed: false } };
  assert.equal(game(ev, flipped).st, 'ht');
  ev.status = { displayClock: "0'", type: { name: 'STATUS_SCHEDULED', state: 'pre' } };
  assert.equal(game(ev, flipped).st, 'pre');
});

test('build asks ESPN only for what is on, once per league and day', async () => {
  const asked = [];
  const doc = await build(md, during, async (lg, d) => (asked.push(`${lg}|${d}`), board.events));
  assert.deepEqual(asked, ['17567|20261121']);
  assert.equal(doc.games.length, 1);
  assert.equal(doc.asOf, '2026-11-21T21:00:00Z');
  const quiet = await build(md, Date.parse('2026-11-23T12:00:00Z'), async () => assert.fail('no ESPN call when nothing is on'));
  assert.deepEqual(quiet.games, []);
  const down = await build(md, during, async () => null);
  assert.equal(down.error, 'ESPN did not answer');
});
