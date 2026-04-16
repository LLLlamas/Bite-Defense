# Bite Defense — Architecture & Product Overview

A condensed reference covering what the app is, how it is built, where it is headed, and the open design questions that will shape the next few milestones.

---

## 1. What the app is

**Bite Defense** is an isometric tower-defense / base-builder with a **Dogs vs Cats** theme.

- You run a Dog HQ, train dog troops, and defend your base from waves of feral cats who steal 💧 Water and 🥛 Milk when they break through.
- The loop is the classic TD build → fight → reward → upgrade cycle, tuned for short mobile sessions (1–3 min per wave).
- Tone is cozy-cartoon, not grimdark. Emoji-forward art style while we iterate; proper sprites later (see §8).

**Current playable state:** a functional MVP with placement, construction, resources, training, waves, enemies, combat, rewards, and a full HUD.

---

## 2. Repository layout

```
Bite Defense/
├── README.md
├── ARCHITECTURE.md          ← you are here
├── iOS_PORT_PLAN.md         ← milestone-by-milestone port tracker
├── index.html / src / style.css / assets/   ← original JS reference build (authoritative design source)
└── ios/                     ← Swift / SpriteKit / SwiftUI native port
    ├── project.yml          ← XcodeGen config (Windows-friendly)
    └── BiteDefense/
        ├── App/             ← ContentView, Info.plist
        ├── Core/            ← GameCoordinator, GameState, EventBus, Grid, IsoMath, Constants
        ├── Data/            ← Static config: buildings, troops, enemies, waves
        ├── Entities/        ← Model + SpriteKit node pairs (Building / Troop / Enemy)
        ├── Input/           ← InputHandler (pan / pinch / tap gestures on SKView)
        ├── Rendering/       ← Sprite/texture factories
        ├── Resources/       ← Assets.xcassets
        ├── Scenes/          ← GameScene (the live SpriteKit world)
        ├── Systems/         ← Gameplay simulation (building, construction, combat, …)
        └── UI/              ← SwiftUI overlays (HUD, store, panels, cards, effects)
```

Two codebases live side-by-side deliberately: the JS reference is the spec; the iOS port is the shipping product.

---

## 3. Tech stack

| Layer          | Tech                                  | Why                                                                 |
| -------------- | ------------------------------------- | ------------------------------------------------------------------- |
| Language       | Swift 5.9                             | First-class iOS 17+ features                                        |
| World / render | SpriteKit + SKCameraNode              | Free zoom / pan / tile rendering without pulling in a game engine   |
| UI chrome      | SwiftUI (`@Observable`, `@Bindable`)  | Fast iteration for HUD, cards, popovers                             |
| Events         | Combine `PassthroughSubject`          | Typed `GameEvent` enum decouples systems from renderers / views     |
| Build          | XcodeGen (`project.yml`)              | Windows-authored configs, deterministic project regen               |
| CI / signing   | Apple Developer Team `GYFN949Q5E`, API key `Q57R8NYWFS` | Handled via the certs repo; matches iOS port decisions memory |
| Tests          | XCTest                                | `BuildingSystemTests`, etc.                                         |
| Min iOS        | 17.0                                  | Pinned decision                                                     |
| Bundle ID      | `com.bitedefense.game`                | Pinned decision                                                     |

Deferred for later: cloud save (CloudKit, M13), analytics, remote config, IAP.

---

## 4. Architecture at a glance

### 4.1 The big three

```
GameCoordinator   ← single source of truth for UI state + orchestration
    │
    ├── GameState      ← authoritative model (resources, buildings, troops, waves, XP)
    ├── Grid           ← tile occupancy (30×30)
    ├── BuildingSystem · ConstructionSystem · ResourceSystem
    ├── TrainingSystem · PathfindingSystem
    ├── WaveSystem     · CombatSystem
    │
    └── GameScene (SpriteKit)  ← reads GameState + subscribes to EventBus; draws sprites
```

### 4.2 Data flow

1. **Input** (SwiftUI button or SpriteKit tap) calls a method on `GameCoordinator`.
2. **Coordinator** mutates `GameState` through a System (`BuildingSystem.place`, `TrainingSystem.queue`, …).
3. **System** emits a typed `GameEvent` via `EventBus.shared.send(...)`.
4. **GameScene** and **SwiftUI views** react — the scene spawns/updates sprites, SwiftUI views re-render via `@Observable`.
5. **`tick(dt:)`** runs each frame from `GameScene.update(_:)`, draining timers (construction, training, resource generation, waves, combat).

### 4.3 Invariants

- **Model first, sprite second.** `GameState.buildings` / `.troops` / `.enemies` are the only truth; `Building` / `TroopNode` / `EnemyNode` just mirror them.
- **Systems don't know about views.** They emit events; views subscribe.
- **No physics engine.** Combat / movement uses continuous (col, row) doubles + manual separation passes.
- **Pathfinding is grid-based.** GKGridGraph, re-used per frame; A* path cache keyed by (start, goal).

---

## 5. Feature inventory (MVP scope)

| Area              | Status | Notes                                                                           |
| ----------------- | :----: | ------------------------------------------------------------------------------- |
| Isometric map     |   ✅   | 30×30, pan + pinch clamped to map bounds                                        |
| Dog HQ placement  |   ✅   | Free, gated intro flow                                                          |
| Buildings         |   ✅   | HQ, Training Camp, Fort, Wall, Water Well, Milk Farm, Archer Tower              |
| Build costs       |   ✅   | **Placement pays in Dog Coins**; some upgrades in coins, some in water/milk     |
| Per-HQ caps       |   ✅   | 1 TC (unique), Fort/Wells/Farms capped at HQ level                              |
| Construction      |   ✅   | Timer + progress bar + bones speed-up                                           |
| Resources         |   ✅   | Water / Milk / Dog Coins + Premium Bones (soft 🦴 economy)                       |
| Training          |   ✅   | Soldier (milk) + Archer (water, unlocks at Lv 3); queue, cancel, speed-up       |
| Fort housing      |   ✅   | Slot cost = troop level                                                         |
| Waves             |   ✅   | 5-tier difficulty, streak bonus, rewards card, failure card                     |
| Combat            |   ✅   | Melee + ranged, cats target nearest troop/building, HQ HP, wave-fail conditions |
| HUD               |   ✅   | Full-width top bar, chips with popovers, number pop + glow effects              |
| Guidance cards    |   ✅   | "Need HQ / troops / HQ still building" with building highlight                  |
| Level-up overlay  |   ✅   | Celebratory card lists new unlocks at that level                                |
| Persistence       |   ⏳   | Local only; CloudKit deferred to M13                                            |
| Monetization      |   ⏳   | Bones shop hooks exist; IAP not wired                                           |
| Sound / haptics   |   ⏳   | None yet                                                                        |
| Sprites           |   ⏳   | Emoji placeholders; custom art pipeline TBD                                     |
| Mascot / intro    |   ⏳   | See §9                                                                           |

---

## 6. Milestone tracker

See `iOS_PORT_PLAN.md` for the authoritative list. **M1–M6 done, M7 pathfinding polish is the active milestone.** Beyond that:

- **M8** Audio pass + haptics.
- **M9** Sprite pipeline v1 (see §8).
- **M10** Dog Commanding Officer intro + mascot (see §9).
- **M11** Monetization / IAP wiring (see §7).
- **M12** Meta-progression (prestige, cosmetics).
- **M13** CloudKit save + cross-device continuity.

---

## 7. Monetization plan

**Principle:** the game must be finishable and satisfying entirely free. Monetization accelerates, never gates.

### 7.1 Premium Bones 🦴 (soft currency → hard currency bridge)

Already plumbed into the build. Bones:

- Speed up any construction or training timer.
- Top off water / milk / coin shortfalls at the moment of action.
- Eventually: buy cosmetic reskins, expand storage caps, roll daily rewards.

### 7.2 Planned SKUs

| Product                         | Type         | Price band        | Notes                                  |
| ------------------------------- | ------------ | ----------------- | -------------------------------------- |
| Bone pouches (5 tiers)          | Consumable   | $0.99 – $49.99    | Standard F2P ladder                    |
| "Bone Club" monthly pass        | Subscription | $4.99 / mo        | Daily bones + small XP bonus           |
| Starter Pack                    | One-time     | $2.99             | First-week offer, shown after wave 3   |
| Cosmetic skins (dog breeds)     | Consumable   | $1.99 – $4.99     | Cosmetic only, no stat changes         |
| Remove-ads / premium upgrade    | One-time     | $4.99             | If we ever introduce interstitials     |

### 7.3 Ad strategy (optional, reversible)

- Rewarded video only: "watch for +25 🦴" once per hour, and "double wave reward" after a win.
- No interstitials. No forced ads. Players who never opt in should not feel pressured.

### 7.4 Compliance

- Age rating 4+ — need to avoid gambling loops, loot boxes with real-money pulls.
- Apple server-side receipt validation in M11.
- StoreKit 2 (iOS 17 baseline makes this trivial).

---

## 8. Sprites & art pipeline

**Current reality:** everything renders from emoji on `AppleColorEmoji`, forced into color presentation with VS16. That is genuinely fine for prototyping and keeps a consistent look without an artist on staff. But we want a signature look eventually.

### 8.1 Options, ranked by effort

1. **Curated emoji set (now).** Keep shipping with it. Lock the set (e.g. 🐕 Soldier, 🐶 Archer, 😾 Cat) and never deviate.
2. **Emoji + hand-painted shields / badges (next).** Compose a sprite in code: emoji on top, a painted frame underneath. Low-effort way to feel more premium without an artist.
3. **AI-generated pixel sprites (experimental).** Pipelines that work well for TD units:
   - **Stable Diffusion + PixelLab / Sprite Fusion LoRA** for isometric 64×64 or 96×96 units.
   - **DALL·E / Midjourney** for concept sheets → a human animator rigs frames in Aseprite.
   - **Retro Diffusion**, **Scenario.gg**, **Layer.ai** are tuned for game sprite sheets and handle view-angle consistency better than raw SD.
   - Lock a **style card** (palette, outline weight, shading direction) and reuse it for every prompt so the roster feels like one universe.
4. **Hire a pixel artist on Fiverr / commission on Cara.app for 4–6 hero units.** Around $150–$400 total gets Soldier Dog, Archer Dog, HQ, Cat, Boss Cat with 3–4 animation frames each. Best value per dollar.
5. **Full original art.** Deferred until revenue justifies it.

### 8.2 Technical setup for custom sprites

- Drop `.png` frames into `Assets.xcassets` with `@2x` / `@3x` variants.
- Add an `SKTextureAtlas` per animal (e.g. `SoldierDog.atlas/walk_0.png` … `walk_7.png`).
- `TroopNode` already hosts the sprite — swap its texture source from the emoji label to `SKAction.animate(with: frames, timePerFrame: ...)`.
- Keep all source files (Aseprite `.ase`, SD prompts) under `assets/source/` — never commit only the export.

### 8.3 Animation polish to aim for

- Walk cycle (8 frames), attack cycle (6 frames), idle bob (4 frames).
- Death: scale-out + fade, no gore.
- Hit-react: 1-frame white flash + 2-pixel knockback.
- Troop "bark" emote every ~15 s of idle, as personality seasoning.

---

## 9. The Dog Commanding Officer (mascot)

Working title: **Major Biscuit** (placeholder — yours to name).

### 9.1 Role

- **Opens the game** with a short animated greeting the first time the player launches.
- **Teaches** via the intro flow (replaces the current plain-text IntroCard as the voice / face).
- **Reacts** to milestones: returns for level-ups, first wave cleared, first base-wipe, daily login.
- **Personality:** warm, slightly over-the-top drill-sergeant energy; proud of the player; never snarky.

### 9.2 Implementation plan

1. **Content layer.**
   - Add `DogCOScript.swift` in `Data/` — a list of `(trigger, line)` pairs keyed by `enum MascotTrigger { case firstLaunch, hqPlaced, level3, firstWaveClear, firstDefeat, … }`.
   - Lines live in a localizable strings file so we can ship other languages later.

2. **Presentation layer.**
   - New `MascotOverlay.swift` SwiftUI view: portrait on the left, speech bubble on the right, bouncy entry, tappable "Continue" to advance or dismiss.
   - Uses the existing `pulsingGlow` / `popOnChange` helpers so it feels native to the rest of the HUD.

3. **Triggering.**
   - `GameCoordinator` already subscribes to `EventBus` for level-up — same plumbing lights up the mascot.
   - A single `MascotDirector` decides whether to speak (debounces, avoids stacking on top of level-up card, respects a "please be quiet" toggle in settings).

4. **Audio.**
   - Optional short bark / "woof woof!" sting on entry, mutable in settings.
   - Don't do full voice-over in v1 — it's expensive and locks in tone prematurely.

5. **Art.**
   - Start with one static emoji-styled portrait (🐕 with a painted general's cap overlay in code).
   - Upgrade to a 3-pose sprite sheet (talking / saluting / winking) once §8 pipeline is live.
   - Eventually: blink + mouth-flap frames on a loop while the bubble is open.

### 9.3 Example first-launch script

> **Major Biscuit:** Welcome to Bite Defense, soldier! The cats are coming for our supplies, and I need a commander. That's you. First order: drop your Dog HQ somewhere on the grid. The rest we'll figure out together. *(salutes)*

Keep it three beats max per appearance. Never block a tap for more than one tap-to-continue.

---

## 10. Immediate next steps

1. **Sound pass (M8).** Even placeholder SFX lifts perceived polish more than any other single change. Bark, coin, build-complete, wave-start, wave-clear, wave-fail.
2. **Haptics.** `.impactOccurred` on placement, level-up, wave-clear.
3. **Sprite pipeline proof-of-concept.** Commission or AI-generate **one** hero unit (Soldier Dog) end-to-end — `.ase` source → atlas → in-game animation. Prove the path before doing more.
4. **Mascot v0.** Static portrait + first-launch line, wired to the existing `hasShownInfoOnce` flag.
5. **Save/load locally.** `Codable` on `GameState`, write to app support on every phase change. Sets up for CloudKit.
6. **StoreKit 2 scaffolding.** Just the product IDs + entitlement wiring — no real purchases yet.

---

## 11. Open questions

- **Wave count cap?** Infinite with scaling, or finite chapters with a prestige reset?
- **PvP / async raids?** Tempting, but doubles the backend surface area. Default: no, for v1.
- **Biomes?** Different maps (snow, desert) as run modifiers? Good cosmetic anchor if we commission art.
- **Companion Apple Watch app?** Wave timers + resource pings. Nice-to-have post-launch.
- **Mascot canon.** Does Major Biscuit have a squad (rival / sidekick dogs) we meet later, or is he a solo narrator? Affects how much writing we commit to.

---

## 12. Glossary

- **HQ / Dog HQ** — the unique home base building; its level caps Fort / Well / Farm counts.
- **Streak** — consecutive wave wins without going home; multiplies rewards.
- **Garrison** — trained troops idle inside Forts until deployed during pre-battle.
- **Pre-battle** — positioning phase between hitting "Start Wave" and the first cat spawning.
- **Flex resource** — water OR milk; still used for a few legacy upgrade costs.
- **Bones (🦴)** — premium currency. Given out for milestones, eventually purchasable.
