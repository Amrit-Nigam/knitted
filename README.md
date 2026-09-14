# Knitted

Knitted sweaters for your Mac's folders. Drop a folder on the app and it gets a custom icon
knitted out of yarn: a macOS-style folder with a patterned pocket, a ribbed cuff, and a sheet
of paper peeking out.

## Using it

1. **Add folders**: drop them onto the window or the Dock icon, or click **Choose Folders…** (⌘O). They wait in the basket; nothing changes yet.
2. **Pick a sweater**: every folder in the basket previews live as you choose.
   - **Pattern**: 15 designs in three families. *Colourwork*: Fair Isle, Nordic Star, Hearts, Pine Trees, Argyle. *Stripes & Checks*: Stripes, Gingham, Houndstooth, Chevron, Polka Dots. *Texture*: Stockinette, Seed Stitch, Rib, Basketweave, Cable. **Surprise** gives each folder its own pattern, picked from its name.
   - **Yarn**: ten palettes, colours sampled from your wallpaper, custom colours, or Surprise.
   - **Details**: turn the ribbed cuff on or off.
3. **Knit** (⌘↩): every folder in the basket gets its sweater.

**Wearing sweaters** lists knitted folders. Double-click one, or use **Change All**, to put it back in the basket for a new sweater; hover and click × to take its sweater off.

The window itself is wrapped in a knitted frame, in whatever pattern and yarn you've picked.

Heads up: macOS stores a custom folder icon as a hidden `Icon\r` file inside the folder. In a
git repository that file shows up as untracked, so add `Icon?` to your `.gitignore`.

## Build

Needs macOS 14+ and Swift 5.9+. The Command Line Tools are enough; Xcode is not required.

```sh
scripts/build-app.sh                 # -> build/Knitted.app (ad-hoc signed, knitted app icon)
open "build/Knitted.app"
scripts/test.sh                      # unit tests (swift-testing)
swift run knit-preview preview/      # render folder icons to PNG
```

## Layout

```
Sources/
├── KnitCore/                     the knitting — no UI, unit-tested
│   ├── Knitting/                 StitchGeometry, KnitPattern, PatternLibrary (all charts), SwatchRenderer
│   ├── Palette/                  YarnColor, YarnPresets, IconSampler, PaletteExtractor
│   ├── Folder/                   FolderIconRenderer (the knitted folder), RenderCache
│   └── Frame/                    BorderPainter, CuffRenderer (knitted frames with ribbed corners)
├── Knitted/                      the SwiftUI app
│   ├── App/                      KnittedApp (scene, commands), AppDelegate (Dock drops)
│   ├── Model/                    Studio (@Observable state + actions), KnitDesign, Folders
│   ├── Services/                 FolderKnitter (NSWorkspace.setIcon), WallpaperYarn, StudioStore
│   └── Views/
│       ├── RootView.swift        knitted frame + layout
│       ├── Selection/            drop zone, basket, focused preview
│       ├── Design/               DesignPanel, PatternPicker, YarnPicker
│       ├── Wardrobe/             WardrobeShelf
│       └── Components/           Theme, KnittedFrame, WindowChrome, tiles
└── knit-preview/                 PNG previews and the app's iconset
```

To add a pattern: add a case to `PatternID` (with its family and name) and chart it in `PatternLibrary`. The picker, Surprise and tests pick it up automatically.
