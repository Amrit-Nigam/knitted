# Cozy Borders

A macOS menu bar app that wraps windows in knitted borders, with yarn colours sampled from
each app's icon.

## Build and run

Needs macOS 14+ and Swift 5.9+. Command Line Tools are enough; Xcode is not required.

```sh
scripts/build-app.sh                 # -> build/Cozy Borders.app (ad-hoc signed)
open "build/Cozy Borders.app"
scripts/test.sh                      # unit tests (swift-testing)
swift run knit-preview preview/      # render swatches, a mock desktop and icon palettes to PNG
```

On first launch the app asks for **Accessibility** access once, then shows a small window
linking to System Settings. Borders appear as soon as access is granted. Screen Recording
is not needed.

> Ad-hoc signatures change on every rebuild, and macOS ties the Accessibility grant to the
> signature. After rebuilding, remove the old *Cozy Borders* entry under Privacy & Security ›
> Accessibility and add the new build. Signing with a stable identity
> (`SIGN_IDENTITY="…" scripts/build-app.sh`) avoids this.

For tracking diagnostics, choose **Log Windows to Console** from the menu, or run the binary
directly with `COZY_LOG_WINDOWS=1 .build/release/CozyBorders`. Running the bare binary from a
terminal inherits the *terminal's* Accessibility permission, not the app's.

## Layout

```
Sources/
├── KnitCore/                   pure, unit-tested pieces
│   ├── Tracking/               TrackedWindow + CoordinateSpace (the only Quartz<->AppKit maths), WindowFilter
│   ├── Knitting/               StitchGeometry, KnitPattern, SwatchRenderer, CuffRenderer, BorderPainter
│   └── Palette/                YarnColor, IconSampler, PaletteExtractor (+ PaletteCache)
├── CozyBorders/                the menu bar agent
│   ├── App/                    main, AppDelegate (permission gate), StatusMenuController, onboarding, Preferences/
│   ├── Tracking/               WindowTracker, AppObserver (AX), WindowIDResolver, WorkspaceObserver
│   └── Rendering/              BorderWindow, BorderView, WindowOrderingStrategy, StackingCoordinator
└── knit-preview/               PNG renderer for judging the knit by eye
```

## Stacking modes

| Menu item | Strategy | Notes |
|---|---|---|
| Focused Window Only | (a) | Frontmost window only, floating level. Always correct. |
| All Windows *(default)* | (b) | Every window; borders sit one level below normal windows and are ordered among themselves by window z-order. Public API only. Where windows overlap, a border can be hidden by the window in front of its own. |
| All Windows, Exact Stacking | (c) | `SLSOrderWindow` puts each border directly beneath its own window. Private API; falls back to (b) automatically if the symbols are missing or calls keep failing. |

## Status against the spec milestones

| | Milestone | State |
|---|---|---|
| M1 | Skeleton, permission flow | Done |
| M2 | Tracking | Implemented; checked live with 5 windows across 4 apps. Multi-display dragging not yet checked on hardware (coordinate conversion is unit-tested for a display above the primary). |
| M3/M4 | Borders, strategies (a)/(b) | Implemented; (b) checked live. Drag lag, space switching and five-window overlap still need hands-on checking. |
| M5 | Knitting | Stockinette, 5 patterns, ribbed mitred cuffs with flare. Judged from `knit-preview` renders and a live screenshot. |
| M6 | Palettes | Checked against 24 installed apps' icons. |
| M7 | Preferences, login item | Done. Idle CPU measured at 0%, RSS ~57–64 MB with 5 windows; the 20-window profile with Instruments is still to do. |
| M8 | Ship | Not started: needs a Developer ID certificate, notarisation and Sparkle. |

Deliberate deviations from the spec:

- **SwiftPM plus a bundling script** instead of an Xcode project, so it builds with just the Command Line Tools.
- **Default stitch 4.5 × 3.5 pt and border 14 pt** instead of 8 × 6 pt. At 8 pt only one or two stitches fit across a border, which reads as chunky blocks. All of these are adjustable in Preferences.
- **Stitch rows are drawn bottom-up** so each stitch's top ends tuck *behind* the row above, which is what the spec is after. Legs are tapered strands built from quadratic curves rather than a constant-width stroke; the constant stroke read as fish scales.
- **Palette monochrome test ignores near-black and near-white pixels**, and a vivid accent covering at least 5% of the icon keeps an icon in colour. Otherwise dark-tile icons (Cloudflare, MongoDB, NordVPN) knit up grey.
- **Global mouse drag/up/down monitors** trigger re-enumeration alongside AX notifications, because some apps send move notifications sparsely mid-drag. These are events, not polling.
