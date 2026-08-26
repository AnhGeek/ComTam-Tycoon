# 03 — Development Roadmap & Complexity Estimates

**Status:** Proposed, awaiting approval
**Estimating basis:** one full-time developer of solid mid/senior ability, with
contracted art delivered on schedule. Days are working days.

---

## 1. Phase overview

| Phase | Name | Est. | Gate to exit |
|---|---|---|---|
| **0** | Architecture & setup | 5 d | Core builds, `dotnet test` green in CI, Unity project opens |
| **1** | Playable MVP | 20 d | 5 playtesters complete day 3 and want a day 4 |
| **2** | Core gameplay polish | 12 d | Grill feel rated ≥ 4/5 by testers; 60 FPS on baseline devices |
| **3** | Progression & economy | 12 d | 60-day balance sim passes; no stuck states |
| **4** | Restaurant upgrades | 15 d | Full upgrade tree, 5 restaurant levels, employees |
| **5** | Customers & events | 12 d | 6 archetypes, weather, random events |
| **6** | Meta-game | 15 d | Map, reputation, achievements, cloud save |
| **7** | Audio / VFX / polish | 15 d | Final art in, audio complete, juice pass done |
| **8** | Monetization | 10 d | Ads + IAP live, analytics firing, no gameplay interruption |
| **9** | QA & optimization | 15 d | Crash-free ≥ 99.5%, store submission ready |
| | **Total** | **~131 d** | ≈ 6.5 months at 1 FTE |

Add ~30% for the unmodelled realities of a first-time release (store rejections,
device-specific bugs, art revisions): **plan for 8–9 months.**

---

## 2. Phase detail

### Phase 0 — Architecture & setup (5 d)

Solution scaffold, `ComTam.Core` + test project, `content/*.json` schema +
validating loader, `EventBus`, `IRandom`/`ITimeSource`, GitHub Actions running
`dotnet test`, Unity project with URP 2D + asmdefs + TMP Vietnamese atlas.

**Gate:** `dotnet test` green in CI; a Vietnamese diacritic smoke screen renders
`Cơm tấm sườn bì chả trứng` correctly on device.

### Phase 1 — Playable MVP (20 d)

Everything in `02-MVP-SCOPE.md`. Build in the Checkpoint A→D order defined
there — simulation first, headless and tested, then the Unity shell.

**Gate:** the MVP ship criterion. **Do not start Phase 2 until it is met.**

### Phase 2 — Core gameplay polish (12 d)

The single most valuable phase and the one most often skipped.

- Grill minigame feel: input latency, tap forgiveness (~80 ms grace window at
  the perfect-zone boundary), animation curves
- Juice: money popups, plate slam, star bursts, screen shake, combo text
- Haptics (brief §35), audio hooks, camera micro-punch
- Combo system (brief §23) — bonus only, never required
- Object pooling, draw-call reduction, 60 FPS on baseline devices

**Gate:** testers rate the grill ≥ 4/5. If they do not, this phase is not done —
no amount of Phase 3 content rescues a mechanic that does not feel good.

### Phase 3 — Progression & economy (12 d)

Reputation 0–100, unlock gating, full recipe set (bì, chả, đặc biệt), difficulty
curve, ingredient/inventory pressure introduced gradually, the headless 60-day
balance simulation, the Unity balance-editor window (ADR-0003).

**Gate:** balance sim passes at three skill levels — perfect, average, sloppy —
with no hard-stuck state and no runaway wealth.

### Phase 4 — Restaurant upgrades (15 d)

Four upgrade tracks × 5 levels, restaurant levels 1–5 with visual progression,
employees (hire, wage, automation), rent and operating costs.

**Design risk:** employees automating the grill can delete the game's only skill
check. Employees must be *slower and lower-quality* than the player, so hiring
is a capacity decision, not an "I win" button.

### Phase 5 — Customers & events (12 d)

All 6 archetypes, weather, random events (brief §20), special customers, the
food blogger. Events must skew **fun over punitive** — a bad-luck day that
erases progress is a churn event.

### Phase 6 — Meta-game (15 d)

Map with 6 districts, per-location customer mixes, multiple branches,
achievements, statistics, cloud save.

### Phase 7 — Audio / VFX / polish (15 d)

Final art integration, full audio (SFX + ambience + original music), particles,
transitions, accessibility pass (brief §34: colour-blind-safe doneness
indicators carry colour **and** icon **and** text **and** animation).

### Phase 8 — Monetization (10 d)

Rewarded video only (double today's tips, extra prep time). **No interstitials
between customers.** IAP: remove-ads, starter pack, cosmetics. Analytics per
brief §37. ATT/GDPR consent flows.

**Rule:** nothing purchasable may increase the perfect window, cooking speed, or
quality. Money-buys-time is acceptable; money-buys-skill is not.

### Phase 9 — QA & optimization (15 d)

Device matrix testing, memory/battery profiling, crash reporting, store assets,
age rating, privacy nutrition labels, soft launch in one market.

---

## 3. Per-system complexity estimates

**S** ≤ 1 d · **M** 2–4 d · **L** 5–8 d · **XL** 9+ d

| System | Size | Est. | Risk | Note |
|---|---|---|---|---|
| `Money` + economy math | S | 1 d | Low | Pure, trivially tested |
| `ContentDatabase` + JSON validation | M | 2 d | Low | Validation is what makes it worth 2 d |
| `EventBus` | S | 0.5 d | Low | ~80 lines |
| `GameStateMachine` | S | 1 d | Low | |
| `CookingSystem` + doneness | M | 2 d | Low | Logic simple; *feel* is Phase 2 |
| **Grill minigame feel** | **L** | **6 d** | **High** | ⭐ The whole game lives here |
| `CustomerAI` state machine | M | 3 d | Low | |
| `CustomerSpawner` (seeded) | S | 1 d | Low | |
| `SatisfactionCalculator` | S | 1 d | Low | Pure fn |
| `PlateAssembly` + `ServingSystem` | M | 3 d | Med | Order-matching edge cases |
| `InventorySystem` | M | 2 d | Med | Risk is design, not code |
| `UpgradeSystem` + `StatResolver` | M | 3 d | Low | |
| `SaveSystem` + migration + atomic write | M | 3 d | Med | Corruption handling is the work |
| Tutorial / onboarding | **L** | **6 d** | **High** | Always underestimated; needs 3+ test rounds |
| HUD + gameplay UI | L | 6 d | Med | Portrait constraints (ADR-0002) |
| Daily results screen | M | 3 d | Low | High polish-per-day ratio |
| Customer/plate views + pooling | M | 4 d | Med | |
| Audio system + integration | M | 4 d | Low | |
| Juice / VFX pass | L | 6 d | Med | Where "polished" is won |
| Balance simulation harness | M | 3 d | Low | Pays for itself immediately |
| Reputation + unlocks | M | 3 d | Low | |
| Employees | L | 7 d | **High** | Design risk: can delete the core mechanic |
| Map / locations | L | 6 d | Med | |
| Weather + random events | M | 4 d | Med | |
| Achievements | M | 3 d | Low | |
| Ads + IAP + consent | L | 7 d | Med | SDK/store friction, not code |
| Analytics | M | 3 d | Low | |
| Cloud save | L | 5 d | **High** | Conflict resolution is genuinely hard |
| Localisation pipeline | M | 4 d | Med | Cheap now, expensive retrofitted |

### The three that decide the project

1. **Grill minigame feel (6 d)** — every session touches it dozens of times. If
   it is not satisfying, nothing downstream matters.
2. **Tutorial (6 d)** — determines whether players reach day 2 at all. Budget
   for three iterations against real testers, not one.
3. **Daily results screen (3 d)** — the "one more day" hook lives here. Highest
   polish return per day spent in the whole project.

---

## 4. Sequencing rules

1. **Simulation before presentation, always.** Core + tests, then views.
2. **No new system while the previous phase's gate is unmet.**
3. **Placeholder art is fine; placeholder *feel* is not.** Ugly is acceptable
   into Phase 6. Unsatisfying is a Phase 2 blocker.
4. **Every phase ends with a build on a real device.** Editor-only verification
   hides frame-rate, touch-latency, and thermal problems.
5. **Playtest with people who did not build it,** every phase from 1 onward.

---

## 5. What I recommend cutting if the schedule slips

In order, cut from the bottom:

1. **Multiple branches / chain management** (Phase 6) — large build, small
   retention gain versus deepening one restaurant.
2. **Cloud save** (Phase 6) — hard, and local save covers most users.
3. **Map districts 4–6** (Phase 6) — ship 3 locations, add more post-launch as
   live content.
4. **Weather** (Phase 5) — flavour; the events system delivers most of the value.
5. **Employees** (Phase 4) — genuinely risky to the core loop, and the game is
   complete without it.

Do **not** cut: Phase 2 polish, the tutorial, the daily results screen, or the
balance simulation. Those are load-bearing.
