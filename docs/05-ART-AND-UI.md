# 05 — Art Direction, Orientation & UI Wireframes

**Status:** Proposed, awaiting approval

---

## 1. Orientation — portrait, locked

Decided in ADR-0002. Design canvas **1080 × 2340 (9:19.5)**, safe-area aware,
no rotation. Rationale in `00-TECH-STACK.md` §6; the short version is that brief
§27's one-handed thumb-reach requirement is incompatible with landscape.

### Supported aspect range

| Aspect | Device | Handling |
|---|---|---|
| 9:19.5 | iPhone 14/15/16 | Design target |
| 9:19.5 + Dynamic Island | iPhone 15/16 Pro | Safe-area inset on top bar |
| 9:16 | Older Android, iPhone SE | **Shortest** — world area compresses, UI holds |
| 9:21 | Tall Android | Extra space goes to the world, not the UI |
| 3:4 | iPad (portrait) | Letterboxed with decorative side art; not a target |

**Rule:** the UI bars are anchored to screen edges with fixed heights; all
flex goes to the world view in the middle. `CanvasScaler` set to *Scale With
Screen Size*, 1080×2340, **Match = 0.5**.

---

## 2. Art direction

### One-line brief

> A warm, sun-bleached Saigon side street at lunchtime — plastic stools, charcoal
> smoke, chrome trays — drawn cute and slightly exaggerated, and readable at a
> glance on a phone held at arm's length.

### Style

- **Stylised 2D**, vector-clean shapes with hand-painted texture accents.
  Not pixel art, not photoreal.
- **Thick, confident outlines** on gameplay-critical objects (food, stations,
  customers). Background elements are outline-free and desaturated so the
  playfield always reads first.
- **Exaggerated proportions** on characters: large heads, simple bodies,
  oversized expressions. Emotion must be legible at ~80 px tall.
- **Warm, high-key palette.** Afternoon sun, not neon.

### Palette

| Role | Colour | Use |
|---|---|---|
| Warm base | `#F4A261` | Street, wood, ambient warmth |
| Deep accent | `#E76F51` | Grill fire, urgency, alerts |
| Rice / neutral | `#FDF6EC` | Rice, plates, UI panels |
| Herb green | `#6A994E` | Cucumber, spring onion, success |
| Sauce brown | `#7F4F24` | Nước mắm, grilled crust |
| Sky | `#A8DADC` | Background, calm states |
| Ink | `#2B2118` | Outlines, text |
| Gold | `#FFC93C` | Money, stars, perfect state |

Contrast checked to **WCAG AA (4.5:1)** for all text on its background — brief
§34.

### Vietnamese identity — specific, not generic

Use, from brief §25: red/blue plastic stools · stainless steel trays · charcoal
grill with visible embers · glass sauce bottles with dried chilli · handwritten
banner signage · tiled shopfronts · overhead tangles of power cable · parked
motorbikes · plastic-wrapped napkin holders · condensation-beaded iced tea
glasses.

**Discipline:** these live in the **background and the frame**, never in the
playfield. The centre of the screen stays clean enough to read food state
instantly. Atmosphere is the border; gameplay is the middle.

Two things to get right, because Vietnamese players notice immediately:
- Cơm tấm is **broken rice** — visibly shorter and more irregular grains than
  regular steamed rice.
- Sườn is a **bone-in pork chop**, marinated dark and flame-grilled, with char
  marks. Not a boneless slab.

Have a Vietnamese reviewer check every food asset before it goes final.

---

## 3. Asset specifications

### Sprites

| Property | Value |
|---|---|
| Format | PNG-24 + alpha (source) → ASTC 6×6 (iOS) / ASTC 6×6 (Android) |
| Colour space | sRGB, **Linear** rendering |
| PPU | 100 |
| Pivot | Characters: bottom-centre · Food: centre · UI: per-anchor |
| Max atlas | 2048 × 2048 |
| Atlases | `atlas_ui`, `atlas_food`, `atlas_customers`, `atlas_environment` |
| Mipmaps | Off for UI and food, on for background |

### Reference sizes (at 1080 px design width)

| Asset | Size (px) |
|---|---|
| Customer (full body) | 180 × 300 |
| Customer face (emotion swap) | 96 × 96 |
| Food component (rice/pork/egg) | 128 × 128 |
| Assembled plate | 220 × 160 |
| Cooking station | 260 × 220 |
| Order ticket icon | 64 × 64 |
| Currency / star icon | 48 × 48 |

### Naming convention

```
{category}_{subject}_{variant}_{state}

char_office_worker_a_idle
char_office_worker_a_angry
food_pork_raw      food_pork_perfect      food_pork_burnt
ui_btn_serve_normal    ui_btn_serve_pressed
env_stall_lv1_base
fx_smoke_puff_01
```

Placeholders are prefixed `PLACEHOLDER_` so every temporary asset is findable
with one search — brief §44's "clear replacement point."

### Animation

Frame-by-frame for short food effects; **Spine skeletal** for characters (see
`00-TECH-STACK.md` §3). Keep every gameplay animation ≤ 0.4 s — animation must
communicate state, never delay input.

| Animation | Length | Purpose |
|---|---|---|
| Customer walk-in | 0.8 s | Arrival |
| Customer mood change | 0.3 s | State readability |
| Pork sizzle loop | 0.6 s loop | Cooking is happening |
| Perfect-tap burst | 0.35 s | Reward |
| Burn puff | 0.4 s | Failure, unmistakable |
| Plate assemble | 0.25 s | Progress |
| Money fly-to-counter | 0.5 s | Payoff |
| Star stamp | 0.3 s × N | Rating reveal |

### Modular customers

One shared body rig; swap head, hair, clothing, and a prop. 6 heads × 5 outfits
× 4 props ≈ 120 visual variants from ~15 assets. This is the single largest art
cost saving available and it must be designed in from the first character —
retrofitting modularity is a redraw.

---

## 4. Main gameplay screen wireframe

```
╔═══════════════════════════════════════════╗ ← safe area top
║ 💰 340,000đ    NGÀY 3     ⭐ 4.2   ⏱ 1:47 ║   TOP BAR  (fixed 140px)
╠═══════════════════════════════════════════╣
║                                           ║
║   ░░░ background: street, motorbikes ░░░  ║
║                                           ║
║    😊         😐         😠      ┌─────┐  ║   CUSTOMER QUEUE
║   ┌───┐      ┌───┐      ┌───┐   │ +2  │  ║   (3 visible + badge)
║   │███│      │███│      │███│   └─────┘  ║
║   └───┘      └───┘      └───┘            ║
║   ▰▰▰▰▱      ▰▰▱▱▱      ▰▱▱▱▱            ║   patience bars
║                                           ║
║  ┌────────┐ ┌────────┐ ┌────────┐        ║   ORDER RAIL
║  │🍚🥩🥚  │ │🍚🥩    │ │🍚🥩🥚  │        ║   (icons, <1s read)
║  └────────┘ └────────┘ └────────┘        ║
║                                           ║
║ ══════════ STALL COUNTER ═══════════════  ║
║                                           ║
║   ┌──────┐   ┌──────────────┐  ┌──────┐  ║   COOKING STATIONS
║   │ 🍚   │   │  🔥  GRILL   │  │ 🥚   │  ║
║   │ RICE │   │ ▰▰▰▰█▰▰░░░░  │  │ EGG  │  ║   ← doneness bar
║   │      │   │      ▲PERFECT│  │ 2.1s │  ║
║   └──────┘   └──────────────┘  └──────┘  ║
║                                           ║
║   ┌─────────────────────────────────┐    ║   PLATE / ASSEMBLY
║   │  🍚 ✓   🥩 ✓   🥚 ⏳            │    ║
║   └─────────────────────────────────┘    ║
╠═══════════════════════════════════════════╣
║  ┌───────┐  ┌───────┐  ┌─────────────┐   ║   ACTION BAR
║  │ 🍚    │  │ 🥚    │  │   PHỤC VỤ   │   ║   (thumb zone, 320px)
║  │ Cơm   │  │ Trứng │  │    SERVE    │   ║
║  └───────┘  └───────┘  └─────────────┘   ║
╚═══════════════════════════════════════════╝ ← safe area bottom
```

### Layout rules

- Everything below **y = 1900** (the bottom ~20%) is reachable by a right or
  left thumb on a 6.1″ phone. All primary actions live there.
- Minimum touch target **44 × 44 pt** (132 × 132 px at 3×); primary buttons are
  larger.
- The **grill is centred** because it is the only timing-critical target.
- The **active customer** is highlighted with a warm rim glow, not colour alone.
- Order tickets sit directly beneath their customer — spatial association beats
  a legend.
- Nothing overlaps the doneness bar. Ever.

### Always visible (brief §27)

Money · day · rating · time remaining · every order · every cooking state ·
every patience bar. No menu opens during `RESTAURANT_OPEN` except Pause.

---

## 5. Doneness indicator — four redundant channels

Brief §34 forbids relying on colour alone. Every doneness state carries **colour
+ icon + text + motion**:

| State | Colour | Icon | Text (vi) | Motion |
|---|---|---|---|---|
| Raw | Pale pink | ○ | Sống | still |
| Cooking | Amber | ◔ | Đang nướng | slow pulse |
| **Perfect** | Gold | ★ | **Vừa chín!** | fast pulse + glow |
| Overcooked | Dark orange | ◕ | Hơi quá | slow flash |
| Burnt | Charcoal | ✕ | Cháy! | smoke + shake |

This also makes the state readable in a screen recording at low bitrate, which
matters for the viral-moment goal in brief §52.

---

## 6. Daily results screen

```
╔═══════════════════════════════════════════╗
║                                           ║
║           NGÀY 12 HOÀN THÀNH              ║
║           ─────────────────               ║
║                                           ║
║   Doanh thu          +  620,000đ          ║  ← counts up, staggered
║   Nguyên liệu        −  180,000đ          ║
║   Chi phí            −   50,000đ          ║
║   Tiền tip           +   45,000đ          ║
║   ═══════════════════════════════         ║
║   LỢI NHUẬN          +  435,000đ          ║  ← gold, punches in
║                                           ║
║   Khách phục vụ            24             ║
║   Đánh giá TB           ⭐ 4.7            ║  ← stars stamp one by one
║   Khách tốt nhất    Nguyễn Minh           ║
║                                           ║
║   Mục tiêu       ✅ HOÀN THÀNH +50,000đ   ║
║                                           ║
║        ✨  KỶ LỤC MỚI!  ✨                ║  ← only if true
║                                           ║
║   ┌─────────────────────────────────┐    ║
║   │ Bếp nướng Lv3    ▰▰▰▰▰▰▱▱ 78%   │    ║  ← ⭐ the hook
║   │ còn 120,000đ nữa                │    ║
║   └─────────────────────────────────┘    ║
║                                           ║
║   ┌─────────────────────────────────┐    ║
║   │        NÂNG CẤP  →              │    ║
║   └─────────────────────────────────┘    ║
╚═══════════════════════════════════════════╝
```

**The upgrade progress bar is the most important element on this screen.** It
turns "the day ended" into "I am 78% of the way to a better grill." It must
visibly *move* from its day-start position — the animation is the hook, not the
number.

Tap anywhere skips all count-up animation straight to final values. Never make a
returning player wait through celebration they have seen 40 times.

---

## 7. Main menu

```
        CƠM TẤM TYCOON
      ────────────────────

        ┌──────────────┐
        │     CHƠI     │        always
        └──────────────┘
        ┌──────────────┐
        │  NÂNG CẤP    │        after day 1
        └──────────────┘
        ┌──────────────┐
        │  CÔNG THỨC   │        after day 3
        └──────────────┘
        ┌──────────────┐
        │  THÀNH TÍCH  │        Phase 6
        └──────────────┘
        ┌──────────────┐
        │   CÀI ĐẶT    │        always
        └──────────────┘
```

Per brief §48, locked systems are **not shown greyed out — they are absent**,
and appear with a small flourish when unlocked. A menu of locked buttons tells a
new player how much they cannot do yet; an empty menu that grows tells them they
are making progress.

---

## 8. Accessibility checklist (brief §34)

- [ ] All text ≥ 4.5:1 contrast on its background
- [ ] Doneness readable without colour (four channels, §5 above)
- [ ] Text scale option: 100% / 125% / 150%
- [ ] Independent Music / SFX / Haptics sliders
- [ ] "Reduce effects" toggle — halves particles, removes screen shake
- [ ] No pure red-on-green pairings anywhere
- [ ] Every timed interaction has a non-colour cue (icon, text, motion)
- [ ] No critical information conveyed by audio alone
- [ ] Tested with iOS Increase Contrast and Reduce Motion enabled

---

## 9. Audio direction (specified now, built in Phase 7)

**Music:** light, cheerful instrumental with Vietnamese character — đàn tranh or
đàn bầu motifs over a modern casual-game bed. Original composition or properly
licensed only (brief §26). Layered stems that intensify as the day gets busier.

**SFX — the satisfying core:** rice scoop, grill sizzle, egg crackle, plate set
down, sauce pour, coin/register, upgrade chime, perfect-tap ding, burn hiss.
These carry the game's feel more than the music does; budget real effort here.

**Ambience:** distant traffic, motorbike horns, indistinct conversation, charcoal
crackle. Low in the mix, ducked when SFX fire.

**Mix rule:** the perfect-tap ding must cut through everything. It is the sound
the player is playing for.
