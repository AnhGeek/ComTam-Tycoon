# Cơm Tấm Tycoon

A casual Vietnamese street-food restaurant simulation. Start with a tiny cơm tấm
cart, grill pork, serve customers, and build a restaurant empire.

**Status:** Phase 1 — playable MVP in progress.

---

## Architecture in one picture

```
unity/ComTamTycoon/   Unity 6 presentation shell — views, UI, audio, input
        │
        ▼  (commands down, events up)
src/ComTam.Core/      The actual game. Pure C#. Zero Unity references.
```

All game rules — economy, cooking, customer AI, satisfaction, save data — live
in `ComTam.Core`, which has no dependency on any engine. Unity renders it. This
makes the simulation unit-testable headlessly in CI, keeps the game deterministic
and debuggable, and means the project is not welded to one engine.

See [`docs/00-TECH-STACK.md` ADR-0001](docs/00-TECH-STACK.md) for the full
rationale.

## Documentation

| Doc | Contents |
|---|---|
| [00-TECH-STACK.md](docs/00-TECH-STACK.md) | Engine evaluation, five ADRs, pinned versions |
| [01-ARCHITECTURE.md](docs/01-ARCHITECTURE.md) | Layers, data model, systems, folders, scenes |
| [02-MVP-SCOPE.md](docs/02-MVP-SCOPE.md) | MVP cut list, core loop, tuned balance numbers |
| [03-ROADMAP.md](docs/03-ROADMAP.md) | Phases 0–9, per-system complexity estimates |
| [04-RISKS.md](docs/04-RISKS.md) | Ranked risk register with mitigations |
| [05-ART-AND-UI.md](docs/05-ART-AND-UI.md) | Art direction, asset specs, UI wireframes |

## Repository layout

```
content/     Balance & content data (JSON) — the source of truth
src/         ComTam.Core + tests + console harness
unity/       Unity 6 project (presentation shell)
docs/        Design and architecture documentation
```

## Building & testing

```bash
dotnet test                      # run the simulation test suite
dotnet run --project src/ComTam.ConsoleHarness   # play a day in the terminal
```

The console harness is a grey-box prototype: it runs the real simulation with a
terminal front-end, so the gameplay loop can be played and tested without the
Unity Editor.

## Tech stack

Unity 6 LTS · C# / .NET Standard 2.1 · URP 2D · portrait 1080×2340
