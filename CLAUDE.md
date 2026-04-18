# Claude working notes — Bite Defense

Context for any Claude session working on this repo. **Read this before
editing iOS code.** Rules here exist because we hit the same CI failure
more than once and it's worth not doing again.

## Environment

- The human developer works on **Windows**. There is **no Swift toolchain
  locally** — every Swift change has to be validated via GitHub Actions
  (`.github/workflows/ios-build.yml` on macos-15 + Xcode 16.4).
- That means **every push is effectively a remote compile.** Don't push
  speculative changes. Grep and think twice instead.

## Pre-push checklist for iOS code

Before committing any Swift change, grep-verify the following (they're
the failure modes we've actually hit):

### 1. Enum case changes

If you add or remove a case in `TroopType`, `BuildingType`, `EnemyType`,
`ResourceKind`, `GamePhase`, `TroopState`, or `EnemyState`:

```text
Grep for: switch <enumTypeName>     across ios/BiteDefense/**/*.swift
       and: switch .+\.type          (variables named `type`)
```

Every matching switch must either list the new case or keep the case you
removed handled. Swift's `switch must be exhaustive` error surfaces deep
in compile output and is easy to miss.

**Back-compat pattern we use:** when a case is "retired" but still
persists in old saves (`TroopType.collector` is the current example),
keep the case in the enum and provide a safe fallback in every switch
that matches on it. Filter the value out at the save-load boundary so it
never reaches live game code. See
`Core/Persistence/SaveManager.swift` / `apply(snapshot:)`.

### 2. `@ViewBuilder` functions

SwiftUI's `@ViewBuilder` transform treats every top-level statement as a
View expression. These don't compile directly inside `@ViewBuilder`:

- Multi-statement `switch` with `case … let x = …` assignments
- `do { … }` blocks
- Anything that isn't a `View`-typed expression

**Fix pattern:** wrap the non-view work in an immediately-invoked
closure and bind the result to `let`:

```swift
let have: Int = {
    switch resource {
    case .water:    return state.water
    case .milk:     return state.milk
    case .dogCoins: return state.dogCoins
    }
}()
```

### 3. Swift 6 concurrency captures

`Task.detached { … MainActor.run { self?.foo() } }` warns on Swift 6
about capturing `self` across actors. Prefer:

```swift
Task { @MainActor [weak self] in
    // self? accesses are main-actor-bound, no warning
}
```

### 4. `UIScreen.main` is deprecated on iOS 17+

It compiles with a warning but the warning is noisy. When adding new
scale-aware code, prefer `UITraitCollection.current.displayScale` or a
view-provided `@Environment(\.displayScale)`. Existing `UIScreen.main`
sites are fine to leave alone — they just keep emitting the warning.

### 5. Tests track enum / config changes

`BiteDefenseTests/*Tests.swift` spot-checks config values (e.g.
`BuildingConfigTests.testFootprintsMatchReference`). When you change a
building footprint, cost, or troop state machine, update the matching
test rather than waiting for CI to flag it.

## CI mapping

| Symptom in CI log                    | Root cause                  |
| ------------------------------------ | --------------------------- |
| `switch must be exhaustive`          | Missed an enum case         |
| `'buildExpression' is unavailable`   | Non-view inside @ViewBuilder|
| `capture of 'self'… Swift 6 mode`    | Task.detached self capture  |
| Archive succeeds, tests fail         | Config value drift vs test  |

## Architecture reminders

- **Idle/auto-battler model.** Waves auto-fire on a timer (difficulty-
  driven, 5 min → 1 min). Troops always live on the battlefield;
  `.garrisoned` is a legacy state preserved only for save back-compat.
- **Collector is a Building** (`BuildingType.collectorHouse`), not a
  Troop. Enemy AI prefers it as a target; losing with it standing
  costs extra resources.
- **Persistence** is JSON at `Documents/bitedefense_save.json`. Schema
  version is in `SaveSnapshot.currentSchemaVersion`. Bump on any
  non-additive change.
- **Event flow:** `EventBus.shared` publishes, `GameScene` and systems
  subscribe. If you add a case to `GameEvent`, grep `switch event` to
  find every handler and extend them.

## When in doubt

- Ask the Explore subagent to map the surface before a big change —
  cheaper than guessing and losing a CI cycle.
- Write small PRs: smaller diff, shorter log, faster fail.
- After a CI failure, trace the error to one code change, fix it, push,
  repeat. Don't batch-guess fixes.
