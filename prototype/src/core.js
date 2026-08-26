/**
 * ComTam Tycoon - prototype simulation core.
 *
 * A faithful JavaScript port of src/ComTam.Core, kept DOM-free for the same
 * reason the C# version is Unity-free: the rules must be testable without a
 * renderer. Every balance value below is copied from /content/balance.json.
 *
 * IMPORTANT: this is a PLAYTEST PROTOTYPE, not a second production codebase.
 * ComTam.Core (C#) remains the source of truth. This exists to answer risk R1
 * - "is the grill actually fun?" - on a real phone, today. If the two ever
 * disagree, the C# suite wins and this gets regenerated.
 */

// ---------------------------------------------------------------------------
// Balance - mirrors /content/balance.json
// ---------------------------------------------------------------------------

export const BALANCE = {
  startingMoneyDong: 100000,
  comSuonPriceDong: 45000,

  riceCostDong: 3000,
  porkCostDong: 12000,
  sauceCostDong: 1000,

  dayLengthSeconds: 150,
  customersOnDay1: 6,
  firstSpawnDelaySeconds: 2,
  spawnIntervalSeconds: 22,
  spawnJitterSeconds: 4,
  queueCapacity: 3,

  grillRawUntilSeconds: 3.0,
  grillPerfectStartSeconds: 4.6,
  grillPerfectEndSeconds: 6.0,
  grillBurntAtSeconds: 8.0,
  grillGraceSeconds: 0.08,

  porkCookingQuality: 50,
  porkOvercookedHighQuality: 70,
  porkOvercookedLowQuality: 35,

  riceQuality: 85,
  sauceQuality: 100,

  burnPatiencePenalty: 0.08,

  satWaitWeight: 40,
  satQualityWeight: 30,
  satAccuracyWeight: 20,
  satPriceWeight: 10,

  tipMinStars: 4,
  tipRateAt4Stars: 0.05,
  tipRatePerStarAbove4: 0.05,

  eatingSeconds: 3.0,
  walkToQueueSeconds: 1.0,
  orderingSeconds: 0.6,
  receivingFoodSeconds: 0.5,
  leavingSeconds: 0.8,

  day1GoalCustomers: 5,
  day1GoalBonusDong: 50000,
};

export const ARCHETYPES = [
  { id: 'student',        nameVi: 'Sinh viên',            patience: 70, spend: 0.9, tolerance: 40, tipChance: 0.10, short: 'SV'  },
  { id: 'office_worker',  nameVi: 'Nhân viên văn phòng',  patience: 50, spend: 1.0, tolerance: 60, tipChance: 0.35, short: 'VP'  },
  { id: 'busy_customer',  nameVi: 'Khách vội',            patience: 30, spend: 1.2, tolerance: 55, tipChance: 0.50, short: 'VỘI' },
];

export const NAMES = [
  'Nguyễn Minh', 'Trần Thu Hà', 'Lê Văn Dũng', 'Phạm Thị Mai',
  'Hoàng Anh Tuấn', 'Vũ Ngọc Lan', 'Đặng Quốc Bảo', 'Bùi Thanh Trúc',
  'Đỗ Hải Nam', 'Ngô Kim Chi', 'Dương Tấn Phát', 'Lý Bích Ngọc',
];

/** Canonical full-menu weights; normalised over components present. */
export const QUALITY_WEIGHTS = { rice: 0.20, pork: 0.40, egg: 0.20, sauce: 0.20 };
export const REQUIRED = ['rice', 'pork', 'sauce'];

export const DONENESS = {
  RAW: 'raw', COOKING: 'cooking', PERFECT: 'perfect',
  OVERCOOKED: 'overcooked', BURNT: 'burnt',
};

export const STATE = {
  WALKING: 'walking', ORDERING: 'ordering', WAITING: 'waiting',
  RECEIVING: 'receiving', EATING: 'eating', LEAVING: 'leaving',
  ANGRY: 'angry', DONE: 'done',
};

// ---------------------------------------------------------------------------
// Money - integer đồng, never floating point (see Money.cs)
// ---------------------------------------------------------------------------

/** Round half away from zero, matching C# MidpointRounding.AwayFromZero. */
export function roundAway(v) {
  return v < 0 ? -Math.round(-v) : Math.round(v);
}

export function scaleMoney(dong, multiplier) {
  return roundAway(dong * multiplier);
}

export function formatMoney(dong) {
  return dong.toLocaleString('en-US') + 'đ';
}

// ---------------------------------------------------------------------------
// Deterministic RNG (mulberry32)
//
// Not the same algorithm as the C# xorshift128+ - cross-language stream parity
// isn't required here, only that a seed replays identically within this build.
// ---------------------------------------------------------------------------

export function makeRng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    range: (lo, hi) => lo + Math.floor(next() * (hi - lo)),
    chance: (p) => (p <= 0 ? false : p >= 1 ? true : next() < p),
  };
}

// ---------------------------------------------------------------------------
// Cooking
// ---------------------------------------------------------------------------

export const PROFILE = {
  rawUntil: BALANCE.grillRawUntilSeconds,
  perfectStart: BALANCE.grillPerfectStartSeconds,
  perfectEnd: BALANCE.grillPerfectEndSeconds,
  burntAt: BALANCE.grillBurntAtSeconds,
};

export function evaluateDoneness(t, p = PROFILE) {
  if (t < p.rawUntil) return DONENESS.RAW;
  if (t < p.perfectStart) return DONENESS.COOKING;
  if (t <= p.perfectEnd) return DONENESS.PERFECT;
  if (t < p.burntAt) return DONENESS.OVERCOOKED;
  return DONENESS.BURNT;
}

export function qualityAt(t, p = PROFILE) {
  switch (evaluateDoneness(t, p)) {
    case DONENESS.RAW: return 0;
    case DONENESS.COOKING: return BALANCE.porkCookingQuality;
    case DONENESS.PERFECT: return 100;
    case DONENESS.OVERCOOKED: {
      const span = p.burntAt - p.perfectEnd;
      const k = span <= 0 ? 1 : Math.min(1, Math.max(0, (t - p.perfectEnd) / span));
      const hi = BALANCE.porkOvercookedHighQuality;
      const lo = BALANCE.porkOvercookedLowQuality;
      return roundAway(hi + (lo - hi) * k);
    }
    default: return 0;
  }
}

// ---------------------------------------------------------------------------
// Plate
// ---------------------------------------------------------------------------

export function plateQuality(components) {
  if (!components.length) return 0;
  let weighted = 0;
  let total = 0;
  for (const c of components) {
    const w = QUALITY_WEIGHTS[c.id] || 0;
    if (w <= 0) continue;
    weighted += c.quality * w;
    total += w;
  }
  if (total <= 0) return 0;
  return Math.min(100, Math.max(0, roundAway(weighted / total)));
}

export function plateMatches(components) {
  return REQUIRED.every((r) => components.some((c) => c.id === r));
}

// ---------------------------------------------------------------------------
// Satisfaction
// ---------------------------------------------------------------------------

export function starsFromScore(score) {
  return Math.min(5, Math.max(1, roundAway(score / 20)));
}

export function evaluateSatisfaction(patience01, quality, accurate) {
  const b = BALANCE;
  const score = Math.min(100, Math.max(0,
    b.satWaitWeight * Math.min(1, Math.max(0, patience01)) +
    b.satQualityWeight * Math.min(1, Math.max(0, quality / 100)) +
    b.satAccuracyWeight * (accurate ? 1 : 0) +
    b.satPriceWeight * 1));
  const rounded = roundAway(score);
  return { score: rounded, stars: starsFromScore(rounded) };
}

export function calculateTip(archetype, stars, priceDong, rng) {
  if (stars < BALANCE.tipMinStars) return 0;
  if (!rng.chance(archetype.tipChance)) return 0;
  const rate = BALANCE.tipRateAt4Stars
    + BALANCE.tipRatePerStarAbove4 * (stars - BALANCE.tipMinStars);
  return scaleMoney(priceDong, rate);
}

// ---------------------------------------------------------------------------
// Day simulation
// ---------------------------------------------------------------------------

export const CMD = {
  OK: 'ok',
  WRONG_STATE: 'wrong_state',
  GRILL_OCCUPIED: 'grill_occupied',
  GRILL_EMPTY: 'grill_empty',
  PORK_RAW: 'pork_raw',
  ALREADY_ON_PLATE: 'already_on_plate',
  NO_CUSTOMER: 'no_customer',
  PLATE_INCOMPLETE: 'plate_incomplete',
};

export class DaySimulation {
  constructor(seed = 1) {
    this.rng = makeRng(seed);
    this.seed = seed;
    this.listeners = {};
    this.reset();
  }

  on(evt, fn) {
    (this.listeners[evt] ||= []).push(fn);
    return this;
  }

  emit(evt, payload) {
    for (const fn of this.listeners[evt] || []) fn(payload);
  }

  reset() {
    this.day = 1;
    this.money = BALANCE.startingMoneyDong;
    this.elapsed = 0;
    this.over = false;
    this.customers = [];
    this.slots = new Array(BALANCE.queueCapacity).fill(null);
    this.plate = [];
    this.grill = { occupied: false, elapsed: 0 };
    this.nextId = 1;
    this.spawned = 0;
    this.toSpawn = BALANCE.customersOnDay1;
    this.nextSpawnAt = BALANCE.firstSpawnDelaySeconds;
    this.result = {
      revenue: 0, tips: 0, ingredientCost: 0, goalBonus: 0,
      served: 0, lost: 0, burned: 0, totalStars: 0,
      bestName: null, bestStars: -1, goalMet: false,
      goalTarget: BALANCE.day1GoalCustomers,
    };
  }

  get timeRemaining() { return Math.max(0, BALANCE.dayLengthSeconds - this.elapsed); }
  get windowClosed() { return this.elapsed >= BALANCE.dayLengthSeconds; }
  get profit() {
    const r = this.result;
    return r.revenue + r.tips + r.goalBonus - r.ingredientCost;
  }
  get averageStars() {
    return this.result.served ? this.result.totalStars / this.result.served : 0;
  }

  // -- tick -----------------------------------------------------------------

  tick(dt) {
    if (this.over || dt <= 0) return;
    this.elapsed += dt;
    this.#tickSpawn();
    this.#tickGrill(dt);
    this.#tickCustomers(dt);
    if (this.#shouldClose()) this.#close();
  }

  #freeSlot() { return this.slots.indexOf(null); }

  #tickSpawn() {
    if (this.windowClosed || this.spawned >= this.toSpawn) return;
    if (this.elapsed < this.nextSpawnAt) return;
    const slot = this.#freeSlot();
    if (slot < 0) return;

    const archetype = ARCHETYPES[this.rng.range(0, ARCHETYPES.length)];
    const c = {
      id: this.nextId++,
      archetype,
      name: NAMES[this.rng.range(0, NAMES.length)],
      state: STATE.WALKING,
      slot,
      patience: 1,
      stateElapsed: 0,
      stars: 0,
      paid: 0,
      tip: 0,
    };
    this.slots[slot] = c;
    this.customers.push(c);
    this.spawned++;

    const jitter = (this.rng.next() * 2 - 1) * BALANCE.spawnJitterSeconds;
    this.nextSpawnAt = this.elapsed + BALANCE.spawnIntervalSeconds + jitter;
    this.emit('arrive', c);
  }

  #tickGrill(dt) {
    if (!this.grill.occupied) return;
    const was = evaluateDoneness(this.grill.elapsed) === DONENESS.BURNT;
    this.grill.elapsed += dt;
    const now = evaluateDoneness(this.grill.elapsed) === DONENESS.BURNT;
    if (!(now && !was)) return;

    this.grill.occupied = false;
    this.grill.elapsed = 0;
    this.result.burned++;
    this.result.ingredientCost += BALANCE.porkCostDong;
    for (const c of this.customers) {
      if (c.state === STATE.WAITING) {
        c.patience = Math.max(0, c.patience - BALANCE.burnPatiencePenalty);
      }
    }
    this.emit('burn');
  }

  #tickCustomers(dt) {
    for (const c of this.customers) {
      if (c.state === STATE.DONE) continue;
      c.stateElapsed += dt;

      switch (c.state) {
        case STATE.WALKING:
          if (c.stateElapsed >= BALANCE.walkToQueueSeconds) this.#setState(c, STATE.ORDERING);
          break;
        case STATE.ORDERING:
          if (c.stateElapsed >= BALANCE.orderingSeconds) {
            this.#setState(c, STATE.WAITING);
            this.emit('order', c);
          }
          break;
        case STATE.WAITING:
          c.patience = Math.max(0, c.patience - dt / c.archetype.patience);
          if (c.patience <= 0) {
            this.#setState(c, STATE.ANGRY);
            this.#freeCustomerSlot(c);
            this.result.lost++;
            this.emit('angry', c);
          }
          break;
        case STATE.RECEIVING:
          if (c.stateElapsed >= BALANCE.receivingFoodSeconds) this.#setState(c, STATE.EATING);
          break;
        case STATE.EATING:
          if (c.stateElapsed >= BALANCE.eatingSeconds) {
            this.#setState(c, STATE.LEAVING);
            this.#freeCustomerSlot(c);
          }
          break;
        case STATE.LEAVING:
        case STATE.ANGRY:
          if (c.stateElapsed >= BALANCE.leavingSeconds) this.#setState(c, STATE.DONE);
          break;
      }
    }
  }

  #setState(c, s) { c.state = s; c.stateElapsed = 0; }

  #freeCustomerSlot(c) {
    if (c.slot >= 0 && this.slots[c.slot] === c) this.slots[c.slot] = null;
    c.slot = -1;
  }

  #shouldClose() {
    if (!this.windowClosed) return false;
    if (this.spawned < this.toSpawn) return true;
    return this.customers.every((c) => c.state === STATE.DONE);
  }

  #close() {
    const r = this.result;
    r.goalMet = r.served >= r.goalTarget;
    r.goalBonus = r.goalMet ? BALANCE.day1GoalBonusDong : 0;
    this.money += r.goalBonus;
    this.over = true;
    this.emit('dayend', r);
  }

  forceClose() {
    if (this.over) return;
    this.elapsed = BALANCE.dayLengthSeconds;
    for (const c of this.customers) c.state = STATE.DONE;
    this.#close();
  }

  // -- commands -------------------------------------------------------------

  hasComponent(id) { return this.plate.some((c) => c.id === id); }

  scoopRice() {
    if (this.over) return CMD.WRONG_STATE;
    if (this.hasComponent('rice')) return CMD.ALREADY_ON_PLATE;
    this.plate.push({ id: 'rice', quality: BALANCE.riceQuality });
    this.emit('rice');
    return CMD.OK;
  }

  placePork() {
    if (this.over) return CMD.WRONG_STATE;
    if (this.hasComponent('pork')) return CMD.ALREADY_ON_PLATE;
    if (this.grill.occupied) return CMD.GRILL_OCCUPIED;
    this.grill.occupied = true;
    this.grill.elapsed = 0;
    this.emit('place');
    return CMD.OK;
  }

  takePork() {
    if (this.over) return CMD.WRONG_STATE;
    if (!this.grill.occupied) return CMD.GRILL_EMPTY;

    const t = this.grill.elapsed;
    const raw = evaluateDoneness(t);
    if (raw === DONENESS.RAW) return CMD.PORK_RAW;

    // Late-tap grace: a tap just past the window still reads as Perfect.
    let effective = t;
    if (raw === DONENESS.OVERCOOKED && t - PROFILE.perfectEnd <= BALANCE.grillGraceSeconds) {
      effective = PROFILE.perfectEnd;
    }

    const doneness = evaluateDoneness(effective);
    const quality = qualityAt(effective);
    this.grill.occupied = false;
    this.grill.elapsed = 0;
    this.plate.push({ id: 'pork', quality });
    this.emit('cooked', { doneness, quality });
    return CMD.OK;
  }

  nextServable() {
    let best = null;
    for (const c of this.customers) {
      if (c.state !== STATE.WAITING) continue;
      if (!best || c.id < best.id) best = c;
    }
    return best;
  }

  serve() {
    if (this.over) return CMD.WRONG_STATE;
    const c = this.nextServable();
    if (!c) return CMD.NO_CUSTOMER;
    if (!this.hasComponent('rice') || !this.hasComponent('pork')) return CMD.PLATE_INCOMPLETE;

    // Sauce is automatic - a tap that can never be wrong is not a mechanic.
    if (!this.hasComponent('sauce')) {
      this.plate.push({ id: 'sauce', quality: BALANCE.sauceQuality });
    }

    const quality = plateQuality(this.plate);
    const accurate = plateMatches(this.plate);
    const sat = evaluateSatisfaction(c.patience, quality, accurate);
    const paid = scaleMoney(BALANCE.comSuonPriceDong, c.archetype.spend);
    const tip = calculateTip(c.archetype, sat.stars, paid, this.rng);

    this.money += paid + tip;
    const r = this.result;
    r.served++;
    r.totalStars += sat.stars;
    r.revenue += paid;
    r.tips += tip;
    r.ingredientCost += BALANCE.riceCostDong + BALANCE.porkCostDong + BALANCE.sauceCostDong;
    if (sat.stars > r.bestStars) { r.bestStars = sat.stars; r.bestName = c.name; }

    c.stars = sat.stars;
    c.paid = paid;
    c.tip = tip;
    this.#setState(c, STATE.RECEIVING);

    this.plate = [];
    this.emit('served', { customer: c, stars: sat.stars, quality, paid, tip });
    return CMD.OK;
  }

  discardPlate() {
    if (this.over) return CMD.WRONG_STATE;
    this.plate = [];
    this.emit('discard');
    return CMD.OK;
  }
}

export function moodOf(patience) {
  if (patience >= 0.8) return 'happy';
  if (patience >= 0.5) return 'normal';
  if (patience >= 0.2) return 'impatient';
  return 'angry';
}
