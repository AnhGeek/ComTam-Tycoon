# 04 — Risk Register

**Status:** Proposed, awaiting approval
**Scoring:** Impact × Likelihood, both 1–5. Score ≥ 12 needs an owner and a date.

---

## 1. Ranked risks

| # | Risk | I | L | Score | Phase |
|---|---|---|---|---|---|
| R1 | Grill minigame is not fun at scale | 5 | 4 | **20** | 2 |
| R2 | No Unity Editor in this dev environment | 4 | 5 | **20** | 0 |
| R3 | Feature creep from the 56-section brief | 4 | 4 | **16** | all |
| R4 | Tutorial fails; players quit on day 1 | 5 | 3 | **15** | 1 |
| R5 | Vietnamese diacritics break at submission | 4 | 3 | **12** | 0 |
| R6 | Portrait too cramped for late-game density | 3 | 4 | **12** | 5 |
| R7 | Economy inflates; late game trivial | 3 | 4 | **12** | 3 |
| R8 | Employees automate away the core mechanic | 4 | 3 | **12** | 4 |
| R9 | Art throughput becomes the bottleneck | 3 | 4 | **12** | 4 |
| R10 | Ad SDK integration slips / breaks | 3 | 3 | 9 | 8 |
| R11 | Save corruption loses player progress | 5 | 2 | 10 | 1 |
| R12 | Performance on low-end Android | 3 | 3 | 9 | 9 |
| R13 | Unity licensing / pricing changes | 4 | 2 | 8 | — |
| R14 | Cultural authenticity feels shallow | 3 | 2 | 6 | 7 |
| R15 | App Store rejection | 3 | 2 | 6 | 9 |

---

## 2. The high scorers

### R1 — The grill minigame is not fun at scale (20)

**The failure:** a single tap-in-the-zone bar is satisfying for 20 reps and
tedious for 2,000. By day 30 the player has done it a thousand times, and if the
only change is that the window got smaller, it reads as harassment rather than
mastery.

**Why it is the top risk:** it is the *only* skill mechanic in the MVP. Every
other system decorates it.

**Mitigations:**
- Prototype it **standalone in Phase 1**, before the surrounding game exists, and
  test it in isolation. If it is not fun with nothing else on screen, it will
  never be fun.
- Give it a **layer to master, not just a shrinking target**: multi-slot grills
  where the skill becomes *ordering and interleaving* several chops, not hitting
  one bar. Depth from concurrency scales; depth from precision does not.
- ~80 ms input-grace at the zone boundary so near-misses read as generous.
- Escape hatch: if it still fails in Phase 2, replace with a rhythm-style
  flip-at-the-right-moment mechanic. **Budget 5 spare days for this.**

**Owner:** Gameplay Programmer + Game Designer · **Decide by:** end of Phase 2.

### R2 — No Unity Editor in this environment (20)

**The failure:** Unity code written here cannot be compiled, run, or verified. If
it is written in volume and assumed to work, the first Editor session becomes a
multi-day debugging slog, and brief §43 ("never hide errors") is already broken.

**Mitigations:**
- **ADR-0001** puts the majority of logic in pure C#, verifiable headlessly.
- Install the .NET SDK in this container so `dotnet test` actually runs. *(It is
  currently absent — this is a live blocker for Phase 0.)*
- Unity-side code is written in small, reviewable increments and **explicitly
  labelled unverified** until a human runs it in the Editor.
- Add a GameCI GitHub Action so Unity at least *compiles* on every push.

**Owner:** Technical Architect · **Decide by:** Phase 0.

### R3 — Feature creep (16)

**The failure:** the brief specifies 56 sections including weather, maps,
seasonal events, chains, and delivery. Building toward all of it produces a game
that is 60% finished in every direction and shippable in none.

**Mitigations:**
- The phase gates in `03-ROADMAP.md` are hard gates, not suggestions.
- A written **Postponed list** — nothing is rejected, only sequenced. This is
  what makes saying "not now" politically survivable.
- Brief §4's own test applied to every proposed feature: is it fun / a
  meaningful decision / progression / Vietnamese? Two "no"s means postpone.
- The MVP cut list in `02-MVP-SCOPE.md` is treated as a contract.

**Owner:** Product Manager · **Ongoing.**

### R4 — The tutorial fails (15)

**The failure:** 20–40% of casual-game installs churn in the first session. A
tutorial that explains instead of teaching, or that gates the fun behind
instruction, is the usual cause.

**Mitigations:**
- Interactive only. Brief §28 is right: no text walls. Maximum one short line
  per step, in the player's language.
- The first customer has **infinite patience** — no fail state while learning.
- Day 1 is pre-stocked and free, so the player cannot softlock (see
  `02-MVP-SCOPE.md` §5.6).
- Test with **5 people who have never seen the game**, three separate rounds.
- Instrument it in Phase 8: a funnel showing exactly which step loses people.

**Owner:** UX Designer + PM · **Decide by:** end of Phase 1.

### R5 — Vietnamese diacritics (12)

Covered in detail in ADR-0005. Summary: Latin Extended Additional
(U+1EA0–U+1EF9) must be in the TMP atlas and the font licence must permit
embedding. **The failure mode is silent** — tone marks vanish and text becomes a
different word — so it needs a visual smoke test per milestone, checked by
someone who reads Vietnamese.

**Owner:** Art Director + Developer · **Decide by:** Phase 0.

### R6 — Portrait density (12)

Late game wants 5–8 concurrent customers (brief §40) on a 9:19.5 screen that
already carries a HUD, an order rail, and a station bar.

**Mitigations:** cap at 3 visible customers with a `+N` badge; order tickets in
a compact rail rather than speech bubbles; never scroll the camera during play.
Prototype the *worst-case* density in Phase 5 with placeholder boxes before
committing art.

### R7 — Economy inflation (12)

Multiplicative upgrades plus rising customer counts compound. By day 60 money is
either meaningless or unobtainable, and both kill the "one more day" hook.

**Mitigations:** the headless 60-day balance simulation with asserted bounds on
the profit curve, run in CI at three skill levels. Upgrade costs scale ~1.8× per
level against sub-linear revenue growth. Money sinks scale with restaurant level.

### R8 — Employees delete the core mechanic (12)

If a hired cook grills perfectly, the player has bought their way out of the only
skill in the game, and the game becomes an idle clicker by accident.

**Mitigation:** employees are strictly worse than a competent player — slower,
capped at ~70 quality, and they occasionally burn food. Hiring buys *capacity*,
never *quality*. Revisit only if playtesting says otherwise.

### R9 — Art throughput (12)

This genre is art-hungry: customers need walk/sit/eat/angry/happy states, and
each restaurant level needs a full environment.

**Mitigations:** lock a style guide before bulk production; modular customer
construction (shared body rig + swappable head/clothing/props) so N customers
cost far less than N × full character; placeholder-to-final swap points named up
front (brief §44); keep gameplay development unblocked by art at all times.

---

## 3. Risks I am explicitly accepting

| Risk | Why accepted |
|---|---|
| No cloud save in MVP | Local save covers the large majority; conflict resolution is a Phase 6 problem |
| No fail state / bankruptcy | Casual retention beats simulation fidelity; revisit only if the game feels stakeless |
| Single location for Phases 1–5 | Depth in one restaurant beats breadth across six |
| English + Vietnamese only at launch | Additional languages are cheap once the pipeline exists |
| Unity runtime-fee exposure | ADR-0001's pure-C# core makes a Godot port weeks, not months |

---

## 4. Early warning signals

Watch for these; each one means stop and reassess rather than push forward:

- Playtesters complete day 3 but **do not ask for day 4** → R1, the core loop is
  not hooking.
- Someone proposes a feature not on the roadmap **before the current gate is
  met** → R3.
- A phase ends without a build on real hardware → R12 is accumulating silently.
- Balance changes start being made "by feel" instead of against the simulation →
  R7.
- Unity code is being written faster than a human can verify it in the Editor →
  R2.
