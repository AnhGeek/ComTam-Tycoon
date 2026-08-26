# 02 — MVP Scope, Core Loop & First Playable Milestone

**Status:** Proposed, awaiting approval

---

## 1. Two design objections before we build anything

Per brief §55, I am not going to silently implement two things in the brief that
I think would make the game worse.

### ⚠️ Objection 1 — Seven taps per dish is a chore, not a minigame

Brief §7 specifies seven discrete player actions per order: take rice, prepare
rice, grill pork, fry egg, assemble plate, add sauce, serve.

At the brief's own mid-game target of 24 customers per day, that is **~168 taps
per day**, of which roughly 140 are not decisions — they are confirmations. The
genre failure mode this produces is well documented: the game stops being about
*prioritising under pressure* and becomes about *tapping fast*, and it gets
physically tiring on a phone within about ten minutes.

**Proposed alternative — one real minigame, everything else is a single tap:**

| Action | MVP interaction | Why |
|---|---|---|
| Rice | **1 tap** → instant portion | Rice is always available; no decision exists |
| Pork | **Timing minigame** ⭐ | This is the skill expression. Keep it. |
| Egg | **1 tap** → 3.0 s auto-cook | Adds parallel-timer pressure without a second skill check |
| Sauce | **Folded into serving** (auto) | A tap that can never be wrong is not a mechanic |
| Assemble | **Automatic** when components are ready | Bookkeeping, not gameplay |
| Serve | **1 tap** (or drag to customer) | The payoff moment |

That is **3–4 taps per dish**, one of which is a genuine skill check. The
difficulty comes from *managing several timers at once* — which is what makes
this genre work — rather than from tap volume.

Sauce and assembly can be promoted to real mechanics later **if** playtesting
shows the game is too easy. Adding depth later is cheap; removing a mechanic
players have learned is expensive.

### ⚠️ Objection 2 — The example economy in §22 is internally inconsistent

Brief §22 shows a day with 24 customers and 450,000đ revenue — 18,750đ per
customer — while brief §14 prices the cheapest dish at 45,000đ. Revenue should
be roughly 1,100,000đ for that day.

I have assumed §22 was illustrative formatting rather than a balance target, and
built a coherent economy from the §14 prices in §5 below. **Please confirm.** If
those revenue figures were intentional, prices need to come down by ~60% and
every upgrade cost in this document shifts with them.

---

## 2. MVP definition

**One sentence:** the player plays a complete cơm tấm day — prep, serve
customers, close, see results, buy one upgrade — and the game remembers it.

### In scope ✅

- One location: the street cart.
- One player-controlled stall, no employees.
- One customer queue, **max 3 visible**, max 4 concurrent.
- Three food components: **broken rice, grilled pork chop, fried egg** + sauce.
- Two recipes: `Cơm sườn` (45,000đ), `Cơm sườn + trứng` (55,000đ).
- Pork grilling timing minigame with 5 doneness states.
- Money system in đồng.
- Customer patience with 4 mood bands.
- Satisfaction → 1–5 stars → tips.
- One daily objective.
- Daily results screen.
- **One upgrade**: Grill Level 2.
- Local save with schema versioning.
- Interactive tutorial covering the first day.
- 3 customer archetypes (Office Worker, Student, Busy Customer).

### Explicitly out of scope ❌

Multiplayer · online · accounts · cloud save · ads · IAP · analytics ·
employees · delivery · multiple restaurants · the map · weather · random events ·
reputation · achievements · combo system · bì / chả / drinks / desserts ·
seasonal events · complex inventory · marketing · rent · ingredient spoilage ·
localisation beyond vi/en strings in JSON.

Every one of these is in `03-ROADMAP.md` with a phase. Nothing is being
forgotten; it is being **sequenced**.

---

## 3. Core gameplay loop

```
   ┌──────────────────────────────────────────────────────┐
   │                                                      │
   ▼                                                      │
PREPARATION          buy stock, see today's goal          │
   │                 ~20 s                                │
   ▼                                                      │
OPEN                 day timer starts (150 s in MVP)      │
   │                                                      │
   ├──► customer arrives ──► order shown as 3 icons       │
   │         │                                            │
   │         ▼                                            │
   │    cook: rice (tap) ─┐                               │
   │          pork (timing) ├─► plate auto-assembles      │
   │          egg  (tap+3s)─┘                             │
   │         │                                            │
   │         ▼                                            │
   │    SERVE ──► satisfaction ──► ⭐×N ──► money + tip   │
   │         │                                            │
   │         ▼                                            │
   │    customer eats, leaves, seat frees                 │
   │         │                                            │
   └─────────┘  repeat until timer expires                │
   │                                                      │
   ▼                                                      │
CLOSED               brief tally animation                │
   │                                                      │
   ▼                                                      │
DAILY RESULTS        revenue / costs / profit / ⭐ / goal  │
   │                                                      │
   ▼                                                      │
UPGRADE              spend, see the stat change           │
   │                                                      │
   └──────────────────────────────────────────────────────┘
                        NEXT DAY
```

### Target loop durations

| Stage | Early (D1–10) | Mid (D11–40) | Late (D40+) |
|---|---|---|---|
| Preparation | 15 s | 30 s | 45 s |
| Open (play) | 150 s | 240 s | 360 s |
| Closed + Results | 20 s | 25 s | 30 s |
| Upgrade | 20 s | 45 s | 60 s |
| **Total** | **~3.4 min** | **~5.7 min** | **~8.1 min** |

Matches the brief's 2–4 / 4–7 / 5–10 minute targets.

**The "one more day" hook:** the results screen shows the next upgrade's cost
and how close the player now is to it, with a progress bar that visibly moved.
The upgrade screen is the *last* thing before the day button — the player
should tap "Next Day" while still thinking about what they are saving for.

---

## 4. Game states (MVP)

| State | Player can | Blocked |
|---|---|---|
| `MAIN_MENU` | Play, Settings | everything else |
| `PREPARATION` | Buy stock, Open | cooking, serving |
| `RESTAURANT_OPEN` | Cook, assemble, serve, pause | buying, upgrading |
| `RESTAURANT_CLOSED` | *(nothing — 1.5 s transition)* | all input |
| `DAILY_RESULTS` | Continue | all gameplay |
| `UPGRADE` | Buy upgrade, Next Day | gameplay |
| `PAUSED` | Resume, Settings, Quit | gameplay (sim frozen) |

`RESTAURANT_CLOSED` exists as a real state, not a coroutine, so the tally
animation cannot be interrupted into an inconsistent ledger.

---

## 5. MVP balance numbers

All values live in `content/balance.json`. Nothing below is hardcoded.

### 5.1 Ingredients & margins

| Ingredient | Unit cost | Per dish |
|---|---|---|
| Broken rice portion | 3,000đ | 1 |
| Pork chop (sườn) | 12,000đ | 1 |
| Egg (trứng) | 4,000đ | 0–1 |
| Sauce (nước mắm) | 1,000đ | 1 |

| Recipe | Ingredient cost | Price | Margin |
|---|---|---|---|
| Cơm sườn | 16,000đ | **45,000đ** | 29,000đ (64%) |
| Cơm sườn + trứng | 20,000đ | **55,000đ** | 35,000đ (64%) |

A consistent ~64% margin keeps the mental math simple for the player: *roughly a
third of the price is cost*. A burnt pork chop wastes 12,000đ — enough to sting,
not enough to ruin a day.

### 5.2 Grilling windows (Grill Level 1)

```
 0s        3.0s      4.6s        6.0s            8.0s
 ├──RAW────┼─COOKING─┼──PERFECT──┼──OVERCOOKED───┼─BURNT──►
                      └─ 1.4 s ──┘
```

| Tap during | Quality | Feedback |
|---|---|---|
| `RAW` | *(tap ignored)* | shake, "Chưa chín!" |
| `COOKING` | 50 | dull thud, grey ring |
| `PERFECT` ⭐ | 100 | ding, gold burst, medium haptic |
| `OVERCOOKED` | 70 → 35 (linear) | flat tone, orange ring |
| `BURNT` (auto) | 0, ingredient lost | smoke puff, error haptic, −8 patience to all waiting |

**Egg:** tap → 3.0 s auto-cook → quality 100. No failure state in MVP.
**Rice:** tap → instant, quality 85 (raised by rice-cooker upgrades later).
**Sauce:** automatic on serve, quality 100.

### 5.3 Plate quality weights (brief §13)

`Rice 20% · Pork 40% · Egg 20% · Sauce 20%`

Worked example — `Cơm sườn + trứng`, perfect pork:
`85(.2) + 100(.4) + 100(.2) + 100(.2)` = **97**
Same dish, undercooked pork: `85(.2) + 50(.4) + 100(.2) + 100(.2)` = **77**

Pork carries 40% of quality, which is what makes the one skill check matter.

### 5.4 Satisfaction (brief §11)

```
satisfaction = 40·waitScore + 30·qualityScore + 20·accuracyScore + 10·priceScore
stars        = clamp(round(satisfaction / 20), 1, 5)
```

- `waitScore` = remaining patience at moment of service (0–1)
- `qualityScore` = plate quality / 100
- `accuracyScore` = 1.0 if the plate matches the order exactly, else 0.0
- `priceScore` = 1.0 in MVP (no dynamic pricing yet)

**Tip:** if `stars ≥ 4`, roll `archetype.TipChance`; on success,
`tip = price × (0.05 + 0.05 × (stars − 4))` → 5% at 4★, 10% at 5★.

### 5.5 Customer archetypes (MVP: 3 of the 6)

| Archetype | Patience | Spend | Quality tolerance | Tip chance |
|---|---|---|---|---|
| Student (Sinh viên) | 70 s | ×0.9 | 40 | 0.10 |
| Office Worker (Nhân viên VP) | 50 s | ×1.0 | 60 | 0.35 |
| Busy Customer (Khách vội) | 30 s | ×1.2 | 55 | 0.50 |

Worker, Food Lover, and Difficult Customer arrive in Phase 5 with the events
system, where their traits actually have something to interact with.

### 5.6 Day pacing & progression

| | Value |
|---|---|
| Starting money | 100,000đ |
| Day 1 stock | **Free** (tutorial pre-stocks the cart) |
| Day length (MVP) | 150 s |
| Customers on day *N* | `min(6 + floor(N × 0.8), 12)` — 6 on D1, 12 by D8 |
| Max concurrent customers | 4 (3 visible + 1 overflow badge) |
| Day 1 goal | Serve 5 customers → **+50,000đ** bonus |
| First upgrade | **Grill Lv2 — 250,000đ**: perfect window 1.4 s → 1.8 s, cook time ×0.9 |

**Day 1 projected:** 6 customers × ~48,000đ ≈ 290,000đ revenue, no stock cost,
+50,000đ goal bonus ≈ **340,000đ**. The player ends day 1 able to buy the grill
upgrade with change to spare — brief §28 step 7 wants the tutorial to end on an
upgrade, and it needs to be *affordable* for that beat to land.

**Day 2 onward:** stock is purchased in `PREPARATION`. 8 customers × ~20,000đ =
160,000đ stock against ~400,000đ revenue.

Day 1 giving free stock also removes a nasty first-run trap: 100,000đ starting
money cannot buy 6 plates of stock (120,000đ). Without the free day the player
could softlock in the tutorial.

---

## 6. First playable milestone — definition of done

Milestones 1–15 from brief §41, grouped into four verifiable checkpoints. Each
checkpoint must be **run and tested** before the next begins.

### Checkpoint A — Core simulation, headless (M1, M3–M5, M11–M12)
`ComTam.Core` + tests. No Unity involved.
- ✅ `dotnet test` green: money, quality, doneness boundaries, patience, satisfaction, save round-trip
- ✅ A headless "auto-play one day" test produces a plausible `DayResult`
- **Verifiable in this container** once the .NET SDK is installed.

### Checkpoint B — Restaurant scene renders and ticks (M2, M6–M9)
- ✅ Unity project opens, Restaurant scene runs at 60 FPS on device
- ✅ Customers spawn, walk to queue, display an order as icons
- ✅ Rice / pork / egg stations respond to tap; grill shows the doneness bar
- ✅ Plate assembles and displays

### Checkpoint C — The loop closes (M10, M13–M14)
- ✅ Serving pays out, customer eats and leaves
- ✅ Day ends, results screen shows a correct ledger
- ✅ Grill Lv2 purchasable, and its effect is measurable on day 2

### Checkpoint D — It persists, and a new player understands it (M15 + tutorial)
- ✅ Force-quitting mid-day and relaunching loses at most the current day
- ✅ Save survives backgrounding and unexpected termination
- ✅ An untutored playtester completes day 1 without help
- ✅ **5 external playtesters** complete day 3

### The MVP ships when

> A new player installs, plays 3 days without instructions, understands
> *cook → serve → earn → upgrade*, and asks to play a 4th day.

If playtesters do not ask for a 4th day, **the answer is not more features.**
The answer is to fix the grill feel, the serving payoff, and the results screen —
in that order — and re-test. Per brief §2, we do not proceed to Phase 2 until
this is true.

---

## 7. Known limitations accepted for MVP

| Limitation | Accepted because |
|---|---|
| Placeholder art (coloured shapes + emoji) | Brief §44 — gameplay must not wait on art |
| No audio beyond 5 placeholder SFX | Feel-tuning needs *some* audio; polish is Phase 7 |
| Ingredients cannot run out mid-day | Brief §15 — inventory pressure early is pure frustration |
| No fail state (can't go bankrupt) | Day-1 retention beats economic realism |
| Single save slot, local only | Cloud save is Phase 6 at the earliest |
| English + Vietnamese strings only, in JSON | Real localisation pipeline is Phase 9 |
| Day length fixed, not adaptive | Adaptive pacing needs data we do not have yet |
