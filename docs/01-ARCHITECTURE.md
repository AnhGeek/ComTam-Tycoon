# 01 — High-Level Architecture

**Status:** Proposed, awaiting approval

---

## 1. Layer model

Four layers. Dependencies point **downward only**. Nothing below knows anything
above it.

```
┌──────────────────────────────────────────────────────────────┐
│ 4. PRESENTATION            (Unity)                            │
│    Views, UI panels, VFX, audio, haptics, input               │
│    MonoBehaviours live here — and ONLY here                   │
└───────────────────────────┬──────────────────────────────────┘
                            │ reads state, sends commands
┌───────────────────────────▼──────────────────────────────────┐
│ 3. ADAPTERS                (Unity)                            │
│    GameHost, EventRelay, ContentLoader, SaveFileStore,        │
│    UnityTimeSource — the ONLY place both worlds touch         │
└───────────────────────────┬──────────────────────────────────┘
                            │ pure C# calls
┌───────────────────────────▼──────────────────────────────────┐
│ 2. SIMULATION              (ComTam.Core)                      │
│    DaySimulation, CookingSystem, CustomerAI, EconomySystem,   │
│    ServingSystem, UpgradeSystem, InventorySystem              │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│ 1. DOMAIN + CONTENT        (ComTam.Core)                      │
│    Money, Plate, Customer, RecipeDef, UpgradeDef, SaveGameV1  │
│    Value types and data. No behaviour beyond pure functions.  │
└──────────────────────────────────────────────────────────────┘
```

### The one rule

**A `MonoBehaviour` may never contain a game rule.** If a line of code decides
how much money the player earns, how fast patience drains, or whether pork is
burnt, it belongs in Core. Views only *display* and *forward input*.

This is enforced mechanically: `ComTam.Core.asmdef` references no Unity
assembly, so `using UnityEngine;` in Core is a compile error.

---

## 2. How the two worlds communicate

Core never calls Unity. Unity drives Core, then reads what changed.

**Downward — commands.** Presentation calls explicit methods on a facade:

```csharp
// Unity side, from a button handler
_game.Submit(new TapCookStationCommand(stationId: 0));
```

**Upward — events.** Core raises plain C# events on an in-process bus. Unity
subscribes and turns them into animation, sound, and haptics.

```csharp
// Core raises
_bus.Publish(new PorkCookedEvent(stationId: 0, doneness: Doneness.Perfect, quality: 100));

// Unity listens
_bus.Subscribe<PorkCookedEvent>(e => {
    _grillView.PlaySizzleBurst(e.stationId);
    _audio.Play(Sfx.PerfectDing);
    _haptics.Impact(HapticStrength.Medium);   // brief §35
});
```

Core events are **facts about what happened**, never instructions about what to
render. `PorkCookedEvent`, not `PlayPerfectAnimationEvent`. This keeps the
simulation honest and lets us re-skin or replay without touching logic.

### The tick

Core is stepped at a **fixed timestep of 20 Hz (`dt = 0.05s`)** from Unity's
`FixedUpdate`, with an accumulator so simulation rate is independent of frame
rate. Rendering interpolates between the last two states for smooth motion at
60 FPS.

Why fixed-step: cooking windows and patience drain must behave identically on a
120 Hz iPhone and a stuttering budget Android, or the perfect-tap window becomes
a device-dependent difficulty setting. 20 Hz is ample for this game and cheap.

---

## 3. Data model

All of this lives in `ComTam.Core`. Types marked `readonly record struct` are
value types — cheap, immutable, allocation-free.

### 3.1 Money — never a float

```csharp
public readonly record struct Money(long Dong) {
    public static Money Zero => new(0);
    public static Money operator +(Money a, Money b) => new(a.Dong + b.Dong);
    public static Money operator -(Money a, Money b) => new(a.Dong - b.Dong);
    public static Money operator *(Money a, double m) => new((long)Math.Round(a.Dong * m));
    public string Format() => $"{Dong:N0}đ";   // 45,000đ
}
```

Currency is an integer count of đồng. Floating-point money accumulates rounding
error across thousands of transactions and produces "profit off by 1đ" bugs
that are miserable to trace. There are no sub-đồng amounts in this game, so
`long` is exact and total.

### 3.2 Food and recipes

```csharp
public enum ComponentId { Rice, Pork, Egg, Sauce, Bi, Cha }   // Bi/Cha = post-MVP

public readonly record struct PreparedComponent(ComponentId Id, int Quality); // 0–100

public sealed class RecipeDef {
    public string   Id;              // "com_suon_trung"
    public string   DisplayNameVi;   // "Cơm sườn + trứng"
    public string   DisplayNameEn;   // "Rice with grilled pork & egg"
    public ComponentId[] Required;   // [Rice, Pork, Egg, Sauce]
    public Money    Price;
    public Dictionary<ComponentId, double> QualityWeights; // must sum to 1.0
    public int      UnlockAtReputation;
}

public sealed class Plate {
    public List<PreparedComponent> Components;
    public int Quality(RecipeDef r);   // weighted average, brief §13
}
```

`Plate.Quality` is a pure function — the single most-tested method in the
codebase.

### 3.3 Customers

```csharp
public sealed class CustomerArchetypeDef {
    public string  Id;                  // "office_worker"
    public string  DisplayNameVi;
    public double  PatienceSeconds;     // base, before difficulty scaling
    public Money   Budget;
    public double  SpendMultiplier;
    public int     QualityTolerance;    // below this quality → unhappy
    public double  TipChance;           // 0–1
    public string[] PreferredRecipeIds;
    public string  SpriteKey;
}

public enum CustomerState {
    Spawning, WalkingToQueue, Waiting, Ordering,
    WaitingForFood, ReceivingFood, Eating, Leaving, LeftAngry
}

public sealed class Customer {
    public int     Id;
    public CustomerArchetypeDef Archetype;
    public string  Name;                // "Nguyễn Minh" — from a name pool
    public CustomerState State;
    public double  Patience01;          // 1.0 → 0.0
    public Order   Order;
    public double  StateElapsed;
}
```

### 3.4 Cooking

```csharp
public enum Doneness { Raw, Cooking, Perfect, Overcooked, Burnt }

public sealed class CookStation {
    public int      Id;
    public bool     Occupied;
    public double   Elapsed;
    public CookProfile Profile;   // resolved from upgrades
    public Doneness CurrentDoneness => Profile.Evaluate(Elapsed);
}

// Resolved from upgrade stats — all times in seconds
public readonly record struct CookProfile(
    double RawUntil, double PerfectStart, double PerfectEnd, double BurntAt
) {
    public Doneness Evaluate(double t) => t switch {
        _ when t < RawUntil     => Doneness.Raw,
        _ when t < PerfectStart => Doneness.Cooking,
        _ when t <= PerfectEnd  => Doneness.Perfect,
        _ when t < BurntAt      => Doneness.Overcooked,
        _                       => Doneness.Burnt
    };
}
```

### 3.5 Upgrades and stats

```csharp
public enum UpgradeTrack { Cooking, Rice, Service, Restaurant }
public enum StatId {
    CookTimeScale, PerfectWindowBonus, BurnDelayBonus, GrillSlots,
    RiceCapacity, ServeSlots, ServeSpeedScale, QualityBonus
}

public sealed class UpgradeDef {
    public string Id;  public UpgradeTrack Track;  public int Level;
    public Money  Cost;  public string DisplayNameVi;
    public StatModifier[] Effects;
    public int    RequiredRestaurantLevel;
}

public readonly record struct StatModifier(StatId Stat, ModOp Op, double Value);
public enum ModOp { Add, Multiply }
```

`StatResolver` folds all purchased upgrades into a `StatBlock` once, at day
start — never per frame. Additive modifiers apply before multiplicative.

### 3.6 Save data — versioned from day one

```csharp
public sealed class SaveGameV1 {
    public int     SchemaVersion = 1;      // ALWAYS first field
    public long    MoneyDong;
    public int     Day;
    public int     RestaurantLevel;
    public string[] PurchasedUpgradeIds;
    public Dictionary<string,int> Inventory;
    public string[] UnlockedRecipeIds;
    public int     Reputation;             // 0–100
    public StatsBlock Stats;
    public SettingsBlock Settings;
    public long    SavedAtUnixMs;
}
```

`SaveMigrator` holds an ordered chain `V1→V2→V3…`. Loading an unknown *higher*
version refuses and preserves the file rather than overwriting it — a player
who downgrades must not lose their save. Writes are **atomic**: write to
`save.tmp`, `fsync`, then rename over `save.json`. Brief §29 requires surviving
unexpected termination, and a non-atomic write during a kill is exactly how
saves get truncated to zero bytes.

---

## 4. Systems inventory

| System | Layer | Responsibility | MVP? |
|---|---|---|---|
| `GameStateMachine` | Sim | Legal state transitions, blocks invalid actions | ✅ |
| `DaySimulation` | Sim | Owns the fixed-step tick; orchestrates subsystems | ✅ |
| `CustomerSpawner` | Sim | Seeded arrival schedule per day | ✅ |
| `CustomerAI` | Sim | Per-customer state machine + patience drain | ✅ |
| `CookingSystem` | Sim | Station timers, doneness, burn, quality output | ✅ |
| `PlateAssembly` | Sim | Holds in-progress plate, validates against order | ✅ |
| `ServingSystem` | Sim | Match plate → customer, settle transaction | ✅ |
| `SatisfactionCalculator` | Sim | Pure fn → 0–100 → stars (brief §11) | ✅ |
| `EconomySystem` | Sim | Revenue, tips, costs, day ledger | ✅ |
| `InventorySystem` | Sim | Stock levels, consumption, restock | ✅ (minimal) |
| `UpgradeSystem` + `StatResolver` | Sim | Purchase validation, stat folding | ✅ (1 upgrade) |
| `SaveSystem` + `SaveMigrator` | Sim | Serialize, atomic write, migrate | ✅ |
| `ContentDatabase` | Domain | Loads + validates `content/*.json` | ✅ |
| `EventBus` | Domain | In-process pub/sub, Core → Unity | ✅ |
| `ReputationSystem` | Sim | 0–100, unlock gating | Phase 3 |
| `ComboSystem` | Sim | Streak tracking, bonuses (brief §23) | Phase 2 |
| `EmployeeSystem` | Sim | Hiring, wages, automation | Phase 4 |
| `WeatherSystem` / `EventSystem` | Sim | Random daily modifiers | Phase 5 |
| `LocationSystem` | Sim | Map, per-district customer mixes | Phase 6 |
| `AchievementSystem` | Sim | Tracking + unlock | Phase 6 |
| `AnalyticsService` | Adapter | Event dispatch | Phase 8 |
| `AdService` / `IapService` | Adapter | Mediation, purchases | Phase 8 |

---

## 5. Game state machine

```
                    ┌──────────────┐
                    │  MAIN_MENU   │
                    └──────┬───────┘
                           │ Play
                    ┌──────▼───────┐
              ┌────►│ PREPARATION  │  buy ingredients, review goal
              │     └──────┬───────┘
              │            │ Open
              │     ┌──────▼───────────┐
              │     │ RESTAURANT_OPEN  │◄──┐  the actual game
              │     └──────┬───────────┘   │
              │            │               │ PAUSED ↔ (overlay)
              │            │ timer 0 or last customer served
              │     ┌──────▼───────────┐   │
              │     │RESTAURANT_CLOSED │   │  brief pause, tally animation
              │     └──────┬───────────┘   │
              │     ┌──────▼───────────┐   │
              │     │  DAILY_RESULTS   │   │
              │     └──────┬───────────┘   │
              │     ┌──────▼───────────┐   │
              └─────┤     UPGRADE      │───┘
                    └──────────────────┘
```

`CUSTOMER_SERVING` from brief §31 is deliberately **not** a top-level state — it
is a customer-level state inside `RESTAURANT_OPEN`. Modelling it globally would
mean the game blocks while one customer is served, which is the opposite of the
"multiple things at once" tension the genre depends on.

Every command carries the states in which it is legal. `GameStateMachine`
rejects illegal commands and logs them; it never silently ignores one.

---

## 6. Customer AI state machine

```
SPAWNING ──► WALKING_TO_QUEUE ──► WAITING ──► ORDERING ──► WAITING_FOR_FOOD
                                     │                            │
                                     │ patience → 0               │ served
                                     ▼                            ▼
                                 LEFT_ANGRY  ◄── patience → 0  RECEIVING_FOOD
                                                                  │
                                                    LEAVING ◄── EATING
```

Patience drains only in `WAITING` and `WAITING_FOR_FOOD`. Drain rate is
`1.0 / archetype.PatienceSeconds * difficultyScale` per second. Cooking mistakes
apply a one-off patience penalty (brief §10).

Determinism: `CustomerSpawner` and all tip/archetype rolls draw from an injected
`IRandom` seeded with `(saveSeed, dayNumber)`. Replaying a day reproduces it
exactly — which is what makes the AI debuggable and the balance testable.

---

## 7. Repository structure

```
ComTam-Tycoon/
├── README.md
├── ComTamTycoon.sln
├── content/                          # ⭐ balance source of truth (ADR-0003)
│   ├── balance.json
│   ├── recipes.json
│   ├── customers.json
│   ├── upgrades.json
│   ├── ingredients.json
│   └── names.vi.json
├── docs/
│   ├── 00-TECH-STACK.md
│   ├── 01-ARCHITECTURE.md
│   ├── 02-MVP-SCOPE.md
│   ├── 03-ROADMAP.md
│   ├── 04-RISKS.md
│   └── 05-ART-AND-UI.md
├── src/
│   ├── ComTam.Core/                  # netstandard2.1 — NO UnityEngine
│   │   ├── ComTam.Core.csproj
│   │   ├── Domain/                   # Money, Plate, Customer, defs
│   │   ├── Content/                  # ContentDatabase, JSON loaders, validation
│   │   ├── Simulation/               # DaySimulation, CookingSystem, CustomerAI…
│   │   ├── Economy/                  # EconomySystem, SatisfactionCalculator
│   │   ├── Progression/              # UpgradeSystem, StatResolver, Reputation
│   │   ├── Save/                     # SaveGameV1, SaveMigrator, ISaveStore
│   │   ├── Events/                   # EventBus + event records
│   │   └── Util/                     # IRandom, XorShift, ITimeSource, Vec2, MathX
│   └── ComTam.Core.Tests/            # NUnit — runs headless in CI
│       ├── Economy/  Cooking/  Customers/  Save/  Balance/
└── unity/
    └── ComTamTycoon/
        ├── Assets/
        │   ├── _Project/
        │   │   ├── Scenes/           # Boot, MainMenu, Restaurant
        │   │   ├── Scripts/
        │   │   │   ├── Bootstrap/    # GameHost, service wiring
        │   │   │   ├── Adapters/     # ⭐ only place Core meets Unity
        │   │   │   ├── Views/        # CustomerView, GrillView, PlateView
        │   │   │   ├── UI/           # HUD, panels, DailyResults
        │   │   │   ├── Audio/        # AudioDirector, SFX pools
        │   │   │   ├── Feedback/     # haptics, juice, camera shake
        │   │   │   └── ComTam.Unity.asmdef
        │   │   ├── Art/  Audio/  Prefabs/  Fonts/
        │   │   └── Content/          # symlink/copy of /content at build
        │   ├── Plugins/
        │   ├── Packages/
        │   └── ProjectSettings/
        └── .gitignore                # Library/, Temp/, Build/, Logs/
```

### Assembly definitions

| asmdef | References | Platform |
|---|---|---|
| `ComTam.Core` | *(none)* | Any |
| `ComTam.Core.Tests` | `ComTam.Core`, NUnit | Editor only |
| `ComTam.Unity` | `ComTam.Core`, TextMeshPro, DOTween | Any |
| `ComTam.Unity.Editor` | `ComTam.Unity`, `ComTam.Core` | Editor only |

Core ships into Unity as **source via asmdef**, not a prebuilt DLL — it keeps
debugging and step-through working, and avoids a build-order dependency.

---

## 8. Scene structure

Three scenes. Deliberately few — every additional scene is a load hitch and a
place for state to leak.

| Scene | Contents | Lifetime |
|---|---|---|
| **Boot** | `GameHost`, service container, `ContentDatabase` load, save load, audio director. Marked `DontDestroyOnLoad`. | Whole session |
| **MainMenu** | Menu canvas, settings, title art. | Transient |
| **Restaurant** | The game: stall art, cook stations, customer queue anchors, HUD canvas, overlay canvases for Preparation / Daily Results / Upgrade. | Transient |

`PREPARATION`, `DAILY_RESULTS`, and `UPGRADE` are **canvas overlays inside
Restaurant**, not separate scenes. They need the restaurant visible behind them,
they must transition in under 200 ms, and reloading a scene between every day
would make the core loop feel heavy.

### Restaurant scene hierarchy (MVP)

```
Restaurant
├── Camera (orthographic, fixed, size tuned to 9:19.5 safe area)
├── World
│   ├── Background        (street, buildings, parallax-ready)
│   ├── Stall             (counter, signage, charcoal grill w/ URP 2D light)
│   ├── QueueAnchors      (3 visible slots + overflow marker)
│   ├── CustomerRoot      (pooled CustomerView instances)
│   └── Stations
│       ├── RiceCooker  ├── Grill  ├── EggPan  └── AssemblyCounter
├── UI_Canvas (Screen Space - Camera, CanvasScaler 1080×2340, Match=0.5)
│   ├── TopBar            money · day · rating · day timer
│   ├── OrderRail         active customer order tickets
│   ├── ActionBar         station buttons (thumb zone)
│   ├── FeedbackLayer     money popups, combo text, star bursts
│   └── Overlays          Preparation · DailyResults · Upgrade · Pause
└── Systems               GameHost bridge, AudioDirector, HapticService
```

---

## 9. Performance strategy

Targets: **60 FPS**, ≤ 2 ms/frame of managed CPU for game logic, and zero
steady-state GC allocation during `RESTAURANT_OPEN`.

- **Object pooling** for customers, plates, money popups, particles, and audio
  sources. Nothing that appears more than once per day is instantiated at
  runtime.
- **No `Update()` on views.** A single `GameHost.FixedUpdate` ticks Core; views
  react to events and to a per-frame interpolation pass. Hundreds of
  `MonoBehaviour.Update` calls is the classic Unity mobile CPU sink.
- **Zero-alloc simulation.** Core uses `readonly record struct` for hot types
  and preallocated collections. No LINQ inside the tick — LINQ in `Update` is
  the second classic sink.
- **UI rebuild discipline.** Static and dynamic UI on separate canvases so a
  changing money counter does not dirty the whole hierarchy. `TextMeshPro`
  `SetText` with a cached `char[]` rather than string concatenation.
- **Single sprite atlas** per scene context; sprites in one atlas draw in one
  call. Target ≤ 40 draw calls in gameplay.
- **Baseline devices:** iPhone SE (2nd gen) and a Snapdragon 6-series Android.
  If it holds 60 on those, it holds everywhere.

---

## 10. Testing strategy

| Test class | Where | Runs in CI |
|---|---|---|
| Money arithmetic, rounding, formatting | `ComTam.Core.Tests` | ✅ |
| `Plate.Quality` weighting | Core tests | ✅ |
| Cooking doneness boundaries (incl. exact edges) | Core tests | ✅ |
| Patience drain and expiry | Core tests | ✅ |
| Satisfaction → stars mapping | Core tests | ✅ |
| Upgrade cost + stat folding | Core tests | ✅ |
| Save round-trip, migration, corrupt-file handling | Core tests | ✅ |
| Inventory consumption | Core tests | ✅ |
| **Balance simulation** — auto-play 60 days, assert profit curve in bounds | Core tests | ✅ |
| View/UI wiring | Unity PlayMode | Manual / GameCI |
| Feel, readability, fun | Human playtest | ❌ — irreplaceable |

The balance simulation deserves emphasis: a headless bot that plays 60 days at
defined skill levels (perfect / average / sloppy) and asserts the player is
never hard-stuck and never trivially rich. It catches economy regressions that
no unit test and no single playtest would.

CI runs `dotnet test` on every push. Unity builds run on a separate, slower
GameCI workflow triggered on merge to `main`.
