# Playtest Prototype

A browser build of Day 1, playable on any phone. **This is not the production
codebase** — `src/ComTam.Core` (C#) is. This exists to answer one question, on
real hardware, today:

> **Is the grill actually fun?**

That is risk R1 in `docs/04-RISKS.md`, the highest-scoring risk in the project,
and `docs/03-ROADMAP.md` says to prototype the mechanic standalone before
building anything around it. An APK needs the Unity Editor and an Android SDK,
neither of which exists in the dev container; a browser build needs neither and
runs on the same phones.

## Play it

```bash
npm --prefix prototype install    # only needed for the browser test
node prototype/build.mjs
open prototype/dist/comtam-tycoon.html
```

Touch the buttons, or use `1` / `Space` / `Enter` on a desktop.

## Test it

```bash
node --test prototype/test/core.test.js   # 40 logic tests
node prototype/test/browser.test.mjs      # plays a real round in Chromium
```

## Why this isn't a second codebase to maintain

`src/core.js` is a deliberate port of `ComTam.Core`, and
`test/core.test.js` **asserts the same expected values as the C# suite** — plate
quality 96, undercooked 71, tips of 2,250đ and 4,500đ, identical doneness
boundaries. A further test reads `content/balance.json` directly and fails if
the prototype's numbers drift from it.

So the two can't silently diverge: if they disagree, a test goes red. If they
ever do disagree, **the C# suite wins** and this gets regenerated.

The prototype is disposable. Delete it once the Unity client can be built and
sideloaded.

## What it deliberately does not have

Save, upgrades, inventory, day 2, audio, art, employees, ads. Same Phase 1 cut
list as the real client — see `docs/02-MVP-SCOPE.md`.

## What to watch for when you play

Notes worth writing down, in priority order:

1. Does hitting the gold zone feel **satisfying**, or merely correct?
2. After ~10 chops, is it still engaging or already a chore?
3. Is burning one **funny** or **annoying**? It should sting and be a little
   funny — never feel unfair.
4. Is the 1.4-second perfect window too generous, or too tight?
5. Do you ever feel genuinely busy — or is one customer at a time too slow?

Answers to 1 and 2 decide whether Phase 2 is a polish pass or a redesign.
