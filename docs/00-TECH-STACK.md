# 00 — Technology Stack Decision

**Status:** Proposed, awaiting approval
**Author:** Lead Architect
**Date:** 2026-08-26

---

## 1. Recommendation (headline)

> **Unity 6 LTS + C#, 2D URP, portrait orientation — with the entire game
> simulation written as a pure C# library that has zero Unity dependencies.**

The second half of that sentence matters more than the first. Read §5 before
arguing about the engine.

---

## 2. Candidates evaluated

| | **Unity 6 + C#** | **Godot 4.x** | **Native Swift / SpriteKit** | **Cocos Creator 3.x** |
|---|---|---|---|---|
| 2D rendering perf | Good (URP 2D, SpriteAtlas) | **Excellent** — best-in-class 2D | Excellent on-device | Very good |
| Mobile runtime perf | Good; IL2CPP AOT | Good; iOS export less battle-tested | **Best** | Good |
| Binary size (base IPA) | ~45–60 MB | **~25–35 MB** | **~8–15 MB** | ~30–40 MB |
| UI development | uGUI (mature) + TextMeshPro | Control nodes (genuinely good) | UIKit/SwiftUI — strong, but no game-UI tooling | Good |
| Skeletal animation | **Spine / DragonBones first-class** | Spine support weak/community | None standard | Spine supported |
| Audio | Adequate; FMOD/Wwise available | Adequate | AVFoundation — excellent | Adequate |
| Touch input | Input System | Solid | **Native, lowest latency** | Solid |
| Asset management / streaming | **Addressables** (mature) | Manual / PCK | Manual | Bundles |
| App Store deployment | Extremely well-trodden | Workable, more manual | **Trivial** | Workable |
| Android portability | **One target switch** | One target switch | **Zero — full rewrite** | One target switch |
| Development speed | High (huge ecosystem) | High (fast iteration, GDScript) | Medium — build everything | Medium |
| Long-term maintainability | Good with discipline | Good; smaller talent pool | Good but platform-locked | Docs inconsistent in EN |
| **Ads / IAP integration** | **Best in class** — LevelPlay, AppLovin MAX, AdMob, Unity IAP all ship Unity-first SDKs | ⚠️ **Community plugins only**; break across engine version bumps | Native SDKs, but wire everything yourself | Good in CN/SEA ecosystem |
| **Analytics / attribution** | **First-class** — Firebase, GameAnalytics, Adjust, AppsFlyer | ⚠️ Community bridges | Native SDKs, manual | Good |

---

## 3. Why Unity wins — and it is not popularity

If you score only Phases 0–7 (build the game), **Godot 4 wins on merit.** Its 2D
renderer is better, its iteration loop is faster, its binaries are a third the
size, and its scene model is a cleaner fit for a 2D game than Unity's
GameObject soup. I want to be explicit about that, because the honest answer is
not "Unity, obviously."

Unity wins on the **tail**, not the build:

1. **The monetization tail is the real risk.** This is a free-to-play casual
   game. Phases 8–9 mean a mediation SDK, rewarded video, IAP receipt
   validation, consent/ATT flows, attribution, and remote config. In Unity these
   are supported products with vendor SLAs. In Godot they are community plugins
   that historically break on every minor engine bump, and a broken ad SDK in a
   live F2P game is a revenue outage you cannot hotfix quickly. This single
   factor outweighs Godot's rendering advantage.

2. **Content velocity for a "cute, exaggerated animation" game.** Section 45 of
   the brief asks for a lot of character animation. Spine is the industry tool
   for that, and its Unity runtime is first-class while its Godot support is
   thin. Art throughput is the schedule bottleneck on this genre, not code.

3. **Live-ops content delivery.** Seasonal events (Tết, Mid-Autumn — brief §51)
   need downloadable content without a store release. Addressables is a solved
   problem; Godot's equivalent is hand-rolled.

4. **Hiring and contracting.** Vietnamese and international casual-game
   contractors are overwhelmingly Unity-native. Godot narrows the pool sharply.

**Native Swift is disqualified outright** by the brief's own
"Android-ready architecture" requirement — 100% of client code would be thrown
away at port time. It is the best technical choice for iOS in isolation, and
the worst product choice given the stated goal.

**Cocos Creator** is a legitimate contender in the SEA market with small builds
and solid ad support, but weaker English documentation and a smaller Western
talent pool make it a worse default than Unity without a compelling upside.

---

## 4. Pinned versions

| Component | Version | Note |
|---|---|---|
| Unity | **6000.0 LTS** (Unity 6 LTS) | LTS only. Never ship on a TECH stream release. |
| Render pipeline | **URP 2D Renderer** | Needed for 2D lights on the charcoal grill glow. |
| Scripting backend | **IL2CPP**, ARM64 | Required by App Store. |
| .NET / C# | **.NET Standard 2.1 / C# 9** | The Core library targets `netstandard2.1` so both Unity and `dotnet test` consume it. |
| UI | **uGUI + TextMeshPro** | Not UI Toolkit — see ADR-0004. |
| Tween | **DOTween Pro** | Or LitMotion if we want zero-alloc. Decide at Phase 2. |
| Tests | **NUnit** (Unity Test Framework compatible) | One test framework for both Core and Unity. |

---

## 5. ADR-0001 — The simulation is a pure C# library outside Unity

**This is the most important architectural decision in the project.**

### Decision

All game logic — economy, cooking state machines, customer AI, satisfaction
math, recipes, progression, save data — lives in `src/ComTam.Core/`, a
`netstandard2.1` class library with **zero references to `UnityEngine`**. Unity
is a presentation shell that renders Core's state and forwards input into it.

```
┌─────────────────────────────────────────────┐
│  unity/  — Views, UI, Audio, VFX, Input      │  knows about Core
├─────────────────────────────────────────────┤
│  src/ComTam.Core/  — the actual game         │  knows about nothing
└─────────────────────────────────────────────┘
```

### Why

1. **It makes the brief's development philosophy actually possible.** Brief §2
   says "build the smallest playable version, test it, fix problems, only then
   continue," and §38 asks for automated tests on economy, patience, cooking
   state, upgrade costs, save/load, and inventory. Every one of those is pure
   logic. In Core they run in ~200 ms under `dotnet test` in CI with no GPU, no
   editor, no device. Inside `MonoBehaviour`s they need Unity's PlayMode runner,
   which is slow, flaky, and cannot run in most CI environments.

2. **It is the honest answer to a hard constraint in this environment.** This
   repository is being developed in a headless Linux container with **no Unity
   Editor and, currently, no .NET SDK installed** (verified: `dotnet` is absent;
   Node 22 and Python 3.11 are present). I can write Unity C# and scene YAML
   here, but I cannot compile it, cannot open a scene, and cannot verify it
   plays. Shipping unverified Unity code and calling it "done" would violate
   brief §43. Core-first means the majority of the codebase is genuinely
   verifiable here, and the Unity shell is assembled and validated by a human on
   a machine with the Editor (or by GameCI in Actions).

3. **Determinism and debuggability.** Brief §32 asks that customer AI be
   "deterministic enough for debugging." Core takes `IRandom` and `ITimeSource`
   as injected dependencies. A bug report becomes a seed plus an input log, and
   a regression test is that seed replayed. This is impossible once logic is
   scattered across `Update()`.

4. **Balance tuning without the Editor.** A designer changes `balance.json`, CI
   runs the economy simulation over 60 simulated days and asserts the profit
   curve stays inside its bounds. No one opens Unity to tune a number.

5. **It is an escape hatch.** If Unity's licensing or runtime fees become
   untenable, Godot 4 supports C#. Core ports unchanged; only the shell is
   rewritten. That converts an existential business risk into a few weeks of
   work.

### Cost, stated honestly

- One extra assembly boundary and a bridge layer (`Adapters/`) to maintain.
- Core cannot use `Vector2`, `Mathf`, coroutines, or `ScriptableObject`. We
  supply small equivalents (`Vec2`, `MathX`) — roughly 150 lines, written once.
- Developers used to putting logic in `MonoBehaviour`s need to be told, in code
  review, to stop. This requires enforcement; an asmdef reference constraint
  makes violations a compile error rather than a style opinion.

That cost is small and fixed. The benefit compounds for the life of the project.

### Enforcement

`ComTam.Core.asmdef` declares no reference to any Unity assembly, so a stray
`using UnityEngine;` in Core **fails the build**. The rule enforces itself.

---

## 6. ADR-0002 — Portrait orientation, 9:19.5 design target

### Decision

**Portrait.** Design canvas 1080×2340 (9:19.5). Safe-area aware. Locked — no
rotation support.

### Why

Brief §27 requires one-handed thumb-reachable play with 44pt minimum touch
targets. **A landscape phone game cannot be played one-handed.** That single
requirement decides it; everything else is confirmation:

- Portrait is the dominant format for modern casual/idle mobile, which is where
  this game's audience and UA channels live.
- A vertical stack maps naturally onto the screen structure the brief itself
  specifies in §47: status bar on top, restaurant in the middle, action bar in
  the thumb zone at the bottom.
- Vertical video creatives for TikTok/Reels UA are captured directly from
  gameplay with no reframing — meaningful for a game explicitly designed for
  viral moments (§52).

### Consequence to design around

Portrait is **horizontally cramped**. Five to eight simultaneous customers
(brief §40, late game) will not fit as a horizontal row. Mitigation is designed
in from the start: the queue renders **at most 3 customers** with a
`+N` overflow badge, and the camera never scrolls during play (§46). This is
recorded here so it is not "discovered" in Phase 5.

---

## 7. ADR-0003 — Balance data is JSON in the repo, not ScriptableObjects

### Decision

`content/*.json` is the **single source of truth** for all balance and content
data. Unity reads it at runtime (via `TextAsset` or Addressables). No
ScriptableObject holds authoritative values.

### Why

- ScriptableObjects are `.asset` YAML — they merge badly in git and are opaque
  in a pull request diff. Balance changes are the single most frequent change on
  a game like this, and they need to be reviewable.
- Core must load content headlessly for tests. It cannot read a
  ScriptableObject.
- JSON is directly promotable to remote config in Phase 8, so balance can be
  tuned live without a store release.

### Cost

Designers lose the Inspector's drag-and-drop and validation. Mitigated by a
small Unity Editor window that reads/writes the JSON with validation, built in
Phase 3 — **not** before, since one developer editing JSON in Phase 1 is fine.

---

## 8. ADR-0004 — uGUI, not UI Toolkit

**Decision:** uGUI + TextMeshPro for all runtime UI.

**Why:** UI Toolkit's runtime path still lags uGUI on mobile for world-space
elements, animated transitions, and third-party tween integration — and this
game needs floating damage-number-style money popups, curved customer patience
rings, and per-element juice. uGUI is the boring, well-understood choice, and
the juice layer is where the polish budget should go, not into fighting a
newer UI stack. UI Toolkit is appropriate for **Editor tooling** (the balance
editor in ADR-0003) and we will use it there.

---

## 9. ADR-0005 — Vietnamese typography is a Phase-1 blocker, not a polish item

Flagging this now because it silently kills projects at submission time.

Vietnamese requires **Latin Extended Additional** (U+1EA0–U+1EF9) — the stacked
diacritics in *cơm tấm sườn bì chả*. Most game fonts and most default
TextMeshPro atlases **do not include this range**, and the failure mode is
tofu boxes or, worse, silently dropped tone marks that make text read as a
different word.

**Actions, in Phase 1:**

- Choose a font with full Vietnamese coverage and an embeddable license.
  Recommended: **Be Vietnam Pro** (SIL OFL, designed for Vietnamese) for UI,
  with **Nunito** (OFL) as a rounded display alternative — verify its Vietnamese
  subset before committing.
- Generate the TMP atlas with an explicit character set covering
  `U+0020-U+007E, U+00C0-U+1EF9`, plus `đ` (U+0111) and the currency `đ`.
- Add a smoke-test screen rendering the full diacritic set, checked visually
  once per milestone.
- Never bake text into sprite art — it blocks localization.

---

## 10. Environment prerequisites (not yet satisfied)

| Requirement | Status | Action |
|---|---|---|
| .NET SDK 8.x | ❌ **Not installed** in this container | Needed before Core code can be compiled or tested. Install `dotnet-sdk-8.0`. |
| Unity 6 LTS + iOS/Android modules | ❌ Not available headless | Required on a developer machine or GameCI runner. |
| Apple Developer Program | Unknown | Needed from Phase 9. Enrolment takes days — start early. |
| Spine license (if used) | Unknown | Decide by Phase 4; Essential tier may suffice. |

**Consequence:** Phase 1 work in this environment should begin with
`ComTam.Core` + its test suite, which is fully verifiable once the .NET SDK is
installed. The Unity shell needs a human with an Editor. I will not report Unity
code as "working" that I could not run.

---

## 11. Open questions for approval

1. **Unity vs. Godot** — do you accept the monetization-tail argument, or is
   this project's plan closer to "premium / no ads," in which case Godot becomes
   the better recommendation? This changes everything downstream, so it is the
   one decision worth pausing on.
2. **Team shape** — solo developer, or is there an artist? The roadmap in
   `03-ROADMAP.md` assumes one developer plus contracted art; a solo
   programmer-only team should cut Phase 4 scope substantially.
3. **Target launch market** — Vietnam-first (affects device tier targets: many
   mid/low-range Android) or global-simultaneous?
