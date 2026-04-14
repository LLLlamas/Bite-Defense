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

## Current milestone

**M1 — Xcode project skeleton.** Blank green scene with a tappable "Hello Bite Defense" label that confirms touch + render are wired up.

See `../iOS_PORT_PLAN.md` for the full milestone roadmap.
