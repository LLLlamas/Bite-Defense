# Bite Defense — iOS

Native Swift / SpriteKit / SwiftUI port of the web game in `../src/`.

## Project layout

The Xcode project is **not committed** — it's generated from `project.yml` by [XcodeGen](https://github.com/yonki/XcodeGen). This keeps merge conflicts out of the binary `.pbxproj` and lets us edit the project structure as plain YAML on Windows.

```
ios/
├── project.yml                     # XcodeGen spec — edit this to add files/targets
├── BiteDefense/                    # app source
│   ├── App/                        # @main, ContentView, Info.plist
│   ├── Core/                       # Constants, GameState, EventBus, persistence
│   ├── Scenes/                     # SKScene subclasses
│   ├── Entities/                   # Building, Troop, Enemy SKNodes
│   ├── Systems/                    # game logic (BuildingSystem, etc.)
│   ├── UI/                         # SwiftUI views (HUD, panels, modals)
│   └── Resources/                  # Assets.xcassets, LaunchScreen
└── BiteDefenseTests/               # XCTest unit tests
```

## Building

### On macOS (local)

```bash
brew install xcodegen
cd ios
xcodegen generate
open BiteDefense.xcodeproj
```

### On Windows / via CI

You can't run Xcode on Windows. Push to `main` (or open a PR touching `ios/`) and the GitHub Actions workflow at `.github/workflows/ios-build.yml` will:
1. Generate the Xcode project with XcodeGen
2. Build for the iPhone 15 Simulator
3. Run unit tests
4. Boot the Simulator, install the app, take a screenshot, and upload it as a workflow artifact

The screenshot artifact lets you visually verify the build from Windows. Download it from the Actions tab on GitHub.

## Bundle identifier

`com.bitedefense.game` — registered in the Apple Developer portal. Don't change without updating App Store Connect.

## iOS deployment target

iOS 17.0 — enables SwiftData, `@Observable`, and modern SwiftUI APIs.

## TestFlight (CI-driven, no Mac required)

Triggered two ways:
1. **Manual** — go to GitHub → Actions → **iOS TestFlight** → **Run workflow**. First-ever run: leave `readonly_match` as `false` so Fastlane `match` can populate the certs repo. Subsequent runs: set it to `true` for safety (no accidental cert regeneration).
2. **Tag push** — `git tag v0.1.1 && git push origin v0.1.1` triggers a build automatically.

After the workflow finishes (~7–15 min), Apple takes another 5–15 min to "process" the build before it appears in the [TestFlight app](https://apps.apple.com/us/app/testflight/id899247664) on your iPhone. Sign into TestFlight with the same Apple ID as your developer account; the build appears in the list under "Bite Defense".

### First TestFlight run gotchas
- The very first `match` invocation has to *create* the App Store distribution cert + provisioning profile. It will:
  1. Authenticate to Apple via the App Store Connect API key
  2. Generate a Distribution certificate (encrypted with `MATCH_PASSWORD`)
  3. Generate a `match AppStore com.bitedefense.game` provisioning profile
  4. Push both, encrypted, into the `bite-defense-certificates` repo as the first commit
- After that succeeds once, every future run only *fetches* from that repo — much faster.
- If the first run fails partway through cert generation, check the `bite-defense-certificates` repo: any half-written files there can confuse subsequent runs. If unsure, delete the repo's contents (keep the repo itself) and re-run.

### Why TestFlight processing takes a while
Apple needs to scan the IPA, extract symbols, validate against current iOS version requirements, and (for the very first build) check encryption export compliance. The `ITSAppUsesNonExemptEncryption: false` we set in `Info.plist` skips the export-compliance prompt; processing still runs.

## Current milestone

**M1 — Xcode project skeleton.** Blank green scene with a tappable "Hello Bite Defense" label that confirms touch + render are wired up.

See `../iOS_PORT_PLAN.md` for the full milestone roadmap.
