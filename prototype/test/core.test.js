/**
 * Parity tests for the prototype core.
 *
 * These deliberately assert the SAME expected values as the C# suite in
 * src/ComTam.Core.Tests. If this file and the C# tests ever disagree, the
 * prototype has drifted and must be regenerated - the C# suite is the
 * source of truth.
 *
 *   node --test prototype/test/
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import {
  BALANCE, ARCHETYPES, DONENESS, STATE, CMD,
  evaluateDoneness, qualityAt, plateQuality, plateMatches,
  evaluateSatisfaction, starsFromScore, calculateTip,
  formatMoney, scaleMoney, makeRng, DaySimulation,
} from '../src/core.js';

const DT = 0.05;

// --- Money (mirrors MoneyTests) -------------------------------------------

test('money formats with separators and đ', () => {
  assert.equal(formatMoney(45000), '45,000đ');
  assert.equal(formatMoney(0), '0đ');
  assert.equal(formatMoney(1234567), '1,234,567đ');
});

test('money scaling rounds half away from zero', () => {
  assert.equal(scaleMoney(45000, 0.05), 2250);
  assert.equal(scaleMoney(45000, 1.2), 54000);
  assert.equal(scaleMoney(45000, 0.9), 40500);
  assert.equal(scaleMoney(5, 0.5), 3);
});

test('money does not drift over many transactions', () => {
  let total = 0;
  for (let i = 0; i < 100000; i++) total += scaleMoney(45000, 0.05);
  assert.equal(total, 2250 * 100000);
});

// --- Doneness (mirrors CookProfileTests) -----------------------------------

test('doneness boundaries', () => {
  const cases = [
    [0.0, DONENESS.RAW], [2.999, DONENESS.RAW],
    [3.0, DONENESS.COOKING], [4.599, DONENESS.COOKING],
    [4.6, DONENESS.PERFECT], [5.3, DONENESS.PERFECT], [6.0, DONENESS.PERFECT],
    [6.001, DONENESS.OVERCOOKED], [7.999, DONENESS.OVERCOOKED],
    [8.0, DONENESS.BURNT], [20.0, DONENESS.BURNT],
  ];
  for (const [t, expected] of cases) {
    assert.equal(evaluateDoneness(t), expected, `at t=${t}`);
  }
});

test('perfect window is 1.4 seconds', () => {
  assert.ok(Math.abs((BALANCE.grillPerfectEndSeconds - BALANCE.grillPerfectStartSeconds) - 1.4) < 1e-9);
});

test('quality by doneness', () => {
  assert.equal(qualityAt(5.3), 100);          // perfect
  assert.equal(qualityAt(4.0), 50);           // undercooked
  assert.equal(qualityAt(9.0), 0);            // burnt
  assert.ok(Math.abs(qualityAt(7.0) - 53) <= 1); // midpoint of 70 -> 35
});

// --- Plate (mirrors PlateQualityTests) -------------------------------------

test('perfect cơm sườn scores 96', () => {
  const plate = [
    { id: 'rice', quality: 85 },
    { id: 'pork', quality: 100 },
    { id: 'sauce', quality: 100 },
  ];
  assert.equal(plateQuality(plate), 96);
});

test('undercooked pork drags the plate to 71', () => {
  const plate = [
    { id: 'rice', quality: 85 },
    { id: 'pork', quality: 50 },
    { id: 'sauce', quality: 100 },
  ];
  assert.equal(plateQuality(plate), 71);
});

test('pork weight exactly balances rice plus sauce', () => {
  const goodPork = [
    { id: 'rice', quality: 0 }, { id: 'pork', quality: 100 }, { id: 'sauce', quality: 0 },
  ];
  const goodRest = [
    { id: 'rice', quality: 100 }, { id: 'pork', quality: 0 }, { id: 'sauce', quality: 100 },
  ];
  assert.equal(plateQuality(goodPork), plateQuality(goodRest));
});

test('empty plate scores zero', () => {
  assert.equal(plateQuality([]), 0);
});

test('matches requires every component', () => {
  assert.equal(plateMatches([{ id: 'rice', quality: 85 }, { id: 'pork', quality: 100 }]), false);
  assert.equal(plateMatches([
    { id: 'rice', quality: 85 }, { id: 'pork', quality: 100 }, { id: 'sauce', quality: 100 },
  ]), true);
});

// --- Satisfaction (mirrors SatisfactionTests) ------------------------------

test('instant service with a perfect plate is five stars', () => {
  const r = evaluateSatisfaction(1.0, 100, true);
  assert.equal(r.score, 100);
  assert.equal(r.stars, 5);
});

test('out of patience with a bad plate is one star', () => {
  const r = evaluateSatisfaction(0, 0, false);
  assert.equal(r.score, 10);
  assert.equal(r.stars, 1);
});

test('wrong order costs the full accuracy weight', () => {
  const a = evaluateSatisfaction(1, 100, true);
  const b = evaluateSatisfaction(1, 100, false);
  assert.equal(a.score - b.score, 20);
});

test('stars never leave 1..5', () => {
  for (let s = 0; s <= 100; s++) {
    const stars = starsFromScore(s);
    assert.ok(stars >= 1 && stars <= 5, `score ${s} -> ${stars}`);
  }
});

test('satisfaction weights sum to 100', () => {
  const b = BALANCE;
  assert.equal(b.satWaitWeight + b.satQualityWeight + b.satAccuracyWeight + b.satPriceWeight, 100);
});

test('tip rates: 5% at 4 stars, 10% at 5', () => {
  const always = { tipChance: 1.0 };
  assert.equal(calculateTip(always, 4, 45000, makeRng(1)), 2250);
  assert.equal(calculateTip(always, 5, 45000, makeRng(1)), 4500);
});

test('three star service never tips', () => {
  assert.equal(calculateTip({ tipChance: 1.0 }, 3, 45000, makeRng(1)), 0);
});

// --- Full loop (mirrors GameplayLoopTests) --------------------------------

function advanceToServable(sim, cap = 20000) {
  for (let i = 0; i < cap; i++) {
    const c = sim.nextServable();
    if (c) return c;
    if (sim.over) return null;
    sim.tick(DT);
  }
  return null;
}

function advance(sim, seconds) {
  for (let i = 0; i < Math.round(seconds / DT); i++) sim.tick(DT);
}

test('day starts with money and no customers', () => {
  const sim = new DaySimulation(12345);
  assert.equal(sim.money, 100000);
  assert.equal(sim.customers.length, 0);
});

test('a customer arrives and waits for food', () => {
  const sim = new DaySimulation(12345);
  const c = advanceToServable(sim);
  assert.ok(c);
  assert.equal(c.state, STATE.WAITING);
});

test('queue never exceeds capacity', () => {
  const sim = new DaySimulation(999);
  for (let i = 0; i < 4000; i++) {
    sim.tick(DT);
    const occupied = sim.slots.filter(Boolean).length;
    assert.ok(occupied <= BALANCE.queueCapacity);
  }
});

test('rice can only be scooped once', () => {
  const sim = new DaySimulation(1);
  assert.equal(sim.scoopRice(), CMD.OK);
  assert.equal(sim.scoopRice(), CMD.ALREADY_ON_PLATE);
});

test('raw pork cannot be taken off and stays on the grill', () => {
  const sim = new DaySimulation(1);
  sim.placePork();
  advance(sim, 1.0);
  assert.equal(sim.takePork(), CMD.PORK_RAW);
  assert.equal(sim.grill.occupied, true);
});

test('late tap inside grace still counts as perfect', () => {
  const sim = new DaySimulation(1);
  sim.placePork();
  advance(sim, 6.05);
  let doneness = null;
  sim.on('cooked', (e) => { doneness = e.doneness; });
  assert.equal(sim.takePork(), CMD.OK);
  assert.equal(doneness, DONENESS.PERFECT);
});

test('late tap beyond grace is overcooked', () => {
  const sim = new DaySimulation(1);
  sim.placePork();
  advance(sim, 6.5);
  let e = null;
  sim.on('cooked', (x) => { e = x; });
  sim.takePork();
  assert.equal(e.doneness, DONENESS.OVERCOOKED);
  assert.ok(e.quality < 100);
});

test('pork burns exactly once and clears the grill', () => {
  const sim = new DaySimulation(1);
  let burns = 0;
  sim.on('burn', () => burns++);
  sim.placePork();
  advance(sim, 12);
  assert.equal(burns, 1);
  assert.equal(sim.grill.occupied, false);
});

test('cannot serve nobody, or an incomplete plate', () => {
  const sim = new DaySimulation(12345);
  assert.equal(sim.serve(), CMD.NO_CUSTOMER);
  advanceToServable(sim);
  sim.scoopRice();
  assert.equal(sim.serve(), CMD.PLATE_INCOMPLETE);
});

test('serving a perfect plate pays, scores 96, and clears the plate', () => {
  const sim = new DaySimulation(12345);
  const c = advanceToServable(sim);
  const before = sim.money;
  sim.scoopRice();
  sim.placePork();
  advance(sim, 5.3);
  sim.takePork();

  let served = null;
  sim.on('served', (e) => { served = e; });
  assert.equal(sim.serve(), CMD.OK);

  assert.ok(served);
  assert.equal(served.quality, 96);
  assert.ok(served.stars >= 4);
  assert.ok(sim.money > before);
  assert.equal(sim.plate.length, 0);
  assert.equal(c.state, STATE.RECEIVING);
});

test('payment scales with the archetype spend multiplier', () => {
  const sim = new DaySimulation(12345);
  const c = advanceToServable(sim);
  sim.scoopRice();
  sim.placePork();
  advance(sim, 5.3);
  sim.takePork();
  sim.serve();
  assert.equal(c.paid, scaleMoney(BALANCE.comSuonPriceDong, c.archetype.spend));
});

test('ledger records ingredient cost of 16,000đ per plate', () => {
  const sim = new DaySimulation(12345);
  advanceToServable(sim);
  sim.scoopRice();
  sim.placePork();
  advance(sim, 5.3);
  sim.takePork();
  sim.serve();
  assert.equal(sim.result.ingredientCost, 16000);
  assert.equal(sim.result.served, 1);
});

test('an ignored customer leaves angry and frees their slot', () => {
  const sim = new DaySimulation(12345);
  const c = advanceToServable(sim);
  let left = false;
  sim.on('angry', () => { left = true; });
  advance(sim, c.archetype.patience + 2);
  assert.equal(left, true);
  assert.ok(sim.result.lost >= 1);
  assert.equal(c.slot, -1);
});

test('a served customer stops losing patience', () => {
  const sim = new DaySimulation(12345);
  const c = advanceToServable(sim);
  sim.scoopRice();
  sim.placePork();
  advance(sim, 5.3);
  sim.takePork();
  sim.serve();
  const after = c.patience;
  advance(sim, 2);
  assert.equal(c.patience, after);
});

test('burning angers everyone still waiting', () => {
  const sim = new DaySimulation(12345);
  const c = advanceToServable(sim);
  const before = c.patience;
  sim.placePork();
  advance(sim, 9);
  assert.equal(sim.result.burned, 1);
  assert.ok(c.patience < before - 9 / c.archetype.patience);
});

test('the day ends on its own', () => {
  const sim = new DaySimulation(12345);
  let ended = false;
  sim.on('dayend', () => { ended = true; });
  for (let i = 0; i < 20000 && !sim.over; i++) sim.tick(DT);
  assert.equal(ended, true);
  assert.equal(sim.over, true);
});

test('commands are refused once the day is over', () => {
  const sim = new DaySimulation(1);
  sim.forceClose();
  assert.equal(sim.scoopRice(), CMD.WRONG_STATE);
  assert.equal(sim.placePork(), CMD.WRONG_STATE);
  assert.equal(sim.serve(), CMD.WRONG_STATE);
});

test('no new customers after the service window closes', () => {
  const sim = new DaySimulation(12345);
  for (let i = 0; i < 20000 && !sim.windowClosed; i++) sim.tick(DT);
  const atClose = sim.customers.length;
  for (let i = 0; i < 400 && !sim.over; i++) sim.tick(DT);
  assert.equal(sim.customers.length, atClose);
});

test('a competent bot clears the day 1 goal and turns a profit', () => {
  const sim = new DaySimulation(42);
  let guard = 0;
  while (!sim.over && guard++ < 200000) {
    if (!sim.grill.occupied && !sim.hasComponent('pork') && sim.nextServable()) sim.placePork();
    if (!sim.hasComponent('rice') && sim.nextServable()) sim.scoopRice();
    if (sim.grill.occupied && evaluateDoneness(sim.grill.elapsed) === DONENESS.PERFECT) sim.takePork();
    if (sim.hasComponent('rice') && sim.hasComponent('pork')) sim.serve();
    sim.tick(DT);
  }
  assert.ok(sim.result.served >= BALANCE.day1GoalCustomers,
    `served ${sim.result.served}`);
  assert.equal(sim.result.goalMet, true);
  assert.equal(sim.result.goalBonus, 50000);
  assert.ok(sim.profit > 0, `profit ${sim.profit}`);
});

test('same seed replays identically', () => {
  const run = (seed) => {
    const sim = new DaySimulation(seed);
    const log = [];
    sim.on('arrive', (c) => log.push(`${c.id}:${c.archetype.id}:${c.name}`));
    for (let i = 0; i < 20000 && !sim.over; i++) sim.tick(DT);
    return log.join('|') + `|money:${sim.money}`;
  };
  assert.equal(run(999), run(999));
  assert.notEqual(run(999), run(1000));
});

// --- Balance parity with content/balance.json ------------------------------

test('prototype balance matches content/balance.json', async () => {
  const { readFileSync } = await import('node:fs');
  const { fileURLToPath } = await import('node:url');
  const { dirname, join } = await import('node:path');
  const here = dirname(fileURLToPath(import.meta.url));
  const json = JSON.parse(readFileSync(join(here, '../../content/balance.json'), 'utf8'));

  // JSON uses PascalCase (C# field names); the prototype uses camelCase.
  const mismatches = [];
  for (const [key, value] of Object.entries(json)) {
    if (key.startsWith('_')) continue;
    const camel = key.charAt(0).toLowerCase() + key.slice(1);
    if (!(camel in BALANCE)) { mismatches.push(`${key}: absent from prototype`); continue; }
    if (Math.abs(BALANCE[camel] - value) > 1e-9) {
      mismatches.push(`${key}: json=${value} prototype=${BALANCE[camel]}`);
    }
  }
  assert.deepEqual(mismatches, [],
    'prototype has drifted from content/balance.json:\n  ' + mismatches.join('\n  '));
});

test('archetypes match the content database', () => {
  assert.equal(ARCHETYPES.length, 3);
  const byId = Object.fromEntries(ARCHETYPES.map((a) => [a.id, a]));
  assert.equal(byId.student.patience, 70);
  assert.equal(byId.office_worker.patience, 50);
  assert.equal(byId.busy_customer.patience, 30);
  assert.equal(byId.busy_customer.spend, 1.2);
});
