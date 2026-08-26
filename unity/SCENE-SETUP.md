# Restaurant Scene — Assembly Guide

> ⚠️ **The scripts in `unity/` have not been compiled.** This container has no
> Unity Editor (risk R2), so the C# in `Assets/_Project/Scripts/` is written but
> unverified. `ComTam.Core` — which holds all the game rules — **is** compiled and
> tested (77 tests, all passing), and the console harness plays the full loop.
>
> Expect to fix small Inspector-wiring and API issues on first open. Anything that
> looks like a *rules* bug belongs in Core and has a test; anything here is
> presentation only.

---

## 0. Prerequisites

- Unity **6000.0 LTS**, with iOS and Android build support
- URP 2D template, TextMeshPro imported
- Run `tools/sync-core-to-unity.sh` first — it mirrors `src/ComTam.Core` into
  `Assets/_Project/Core/`

## 1. Font (do this first — ADR-0005)

Vietnamese needs Latin Extended Additional. Skip this and the UI renders tofu
boxes, or silently drops tone marks.

1. Import **Be Vietnam Pro** (SIL OFL) into `Assets/_Project/Fonts/`
2. `Window → TextMeshPro → Font Asset Creator`
3. Character Set: **Custom Range**, enter:
   `20-7E,A0-FF,102-103,110-111,128-129,168-169,1A0-1A1,1AF-1B0,1EA0-1EF9,20AB`
4. Atlas 1024×1024, SDF16
5. Set it as the default in `Project Settings → TextMeshPro → Default Font Asset`
6. **Verify:** put `Cơm tấm sườn nướng — 45,000đ` in a TMP label and read it.

## 2. Project settings

| Setting | Value |
|---|---|
| Orientation | **Portrait**, auto-rotation off |
| Default resolution | 1080 × 2340 |
| Color space | Linear |
| Scripting backend | IL2CPP, ARM64 |
| Target frame rate | Set `Application.targetFrameRate = 60` in `GameHost.Awake` |

## 3. Scene hierarchy

Create `Assets/_Project/Scenes/Restaurant.unity`:

```
Restaurant
├── Main Camera            Orthographic, Size 5, background #A8DADC
├── GameHost               ← empty GO + GameHost.cs
│                             Seed 0 (random) | Start Day 1 | Auto Start ✓
├── World
│   ├── Background         sprite, sorting layer "Background"
│   ├── Stall              sprite, sorting layer "World"
│   └── GrillAnchor        empty, marks the grill's world position
└── UI_Canvas              Screen Space - Camera, ref 1080×2340, Match 0.5
    ├── TopBar
    │   ├── MoneyLabel     TMP
    │   ├── DayLabel       TMP
    │   └── TimerLabel     TMP
    ├── Queue              ← CustomerQueueView.cs
    │   ├── Slot0          ← CustomerSlotView.cs
    │   ├── Slot1          ← CustomerSlotView.cs
    │   ├── Slot2          ← CustomerSlotView.cs
    │   └── OverflowBadge  Image + TMP "+N"
    ├── GrillPanel         ← GrillView.cs
    │   ├── BarRoot        RectTransform, the full bar
    │   │   ├── PerfectZone  Image (gold, alpha .35) — positioned FROM CODE
    │   │   ├── Fill         Image, Type=Filled, Horizontal, Origin=Left
    │   │   └── Playhead     Image, 4px wide
    │   ├── StateIcon      Image
    │   └── StateLabel     TMP
    ├── PlatePanel
    │   ├── RiceTick       Image
    │   ├── PorkTick       Image
    │   └── ReadyBanner    GameObject
    ├── ActionBar          anchored to bottom, inside the thumb zone
    │   ├── RiceButton     Button, ≥132×132 px
    │   ├── GrillButton    Button, ≥132×132 px
    │   └── ServeButton    Button, wide
    ├── ToastLabel         TMP, centred
    └── ResultsPanel       inactive by default
        └── ResultsBody    TMP
```

## 4. Component wiring

**HudView** (put it on `UI_Canvas`) — drag in: MoneyLabel, DayLabel, TimerLabel,
RiceTick, PorkTick, ReadyBanner, RiceButton, GrillButton, ServeButton,
ToastLabel, ResultsPanel, ResultsBody.

> Do **not** add OnClick handlers in the Inspector — `HudView.Start()` wires the
> three buttons in code. Adding them twice fires every command twice, which
> presents as "the grill button places and immediately removes the pork."

**GrillView** (on `GrillPanel`) — drag in: BarRoot, Fill, PerfectZone, Playhead,
StateLabel, StateIcon, the five doneness sprites, and optionally the sizzle and
smoke particle systems.

`PerfectZone`'s anchors are overwritten at runtime from the simulation's
`CookProfile`. Whatever you set in the Inspector is cosmetic.

**CustomerQueueView** (on `Queue`) — drag the three slots into `_slots`, plus
OverflowBadge and its label. On each `CustomerSlotView`, wire Root, Portrait,
MoodFace, PatienceRing (Image, Type=Filled, Radial 360), NameLabel, OrderTicket,
and the five mood sprites.

## 5. Placeholder art

Nothing here needs real art to play. Per brief §44, use solid-colour sprites
named `PLACEHOLDER_*` so every swap point is one search away:

| Placeholder | Colour | Size |
|---|---|---|
| `PLACEHOLDER_customer` | `#E76F51` | 180×300 |
| `PLACEHOLDER_face_*` | greyscale | 96×96 |
| `PLACEHOLDER_stall` | `#7F4F24` | 900×400 |
| `PLACEHOLDER_doneness_*` | per §5 of `docs/05-ART-AND-UI.md` | 64×64 |

## 6. Test procedure

1. Press Play. The console logs `[GameHost] simulation seed = N`.
2. Within ~3 s a customer walks up; an order ticket and patience ring appear.
3. Tap **Grill** — the bar starts filling, sizzle plays.
4. Tap **Rice** while it cooks — RiceTick turns green.
5. Tap **Grill** again inside the gold zone → "VỪA CHÍN!", PorkTick turns green,
   ReadyBanner appears.
6. Tap **Serve** → stars + money toast, money counter rises, customer eats and
   leaves.
7. Leave a customer unserved → the ring drains, the face sours, they leave angry.
8. Let a chop sit on the grill → smoke puff, "SƯỜN CHÁY!", the grill clears.
9. After 150 s the results panel appears with the ledger.

**To reproduce a specific day**, set `GameHost.Seed` to the value from the log.
The same seed replays the exact same customers in the same order.

## 7. Known wiring pitfalls

- **Double-fire on buttons** — see the warning in §4.
- **Bar zone misaligned** — `LayOutPerfectZone` needs `BarRoot.rect.width > 0`.
  It retries every frame until the layout settles, but a `LayoutGroup` parent
  that never resolves will keep it at zero.
- **`GameHost.Instance` null** — `GameHost` must exist in the scene and wake
  before the views. It uses `DontDestroyOnLoad`, so avoid a second copy in a
  second scene.
- **No customers ever arrive** — check the sim reached `RestaurantOpen`;
  `BeginDay` refuses from the wrong state and logs a warning.
