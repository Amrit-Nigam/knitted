# Cozy Folders

Knitted sweaters for your Mac's folders. Drop a folder on the app and it gets a custom icon
knitted out of yarn: a macOS-style folder with a patterned pocket, a ribbed cuff, and a sheet
of paper peeking out.

## Using it

- **Drop folders** onto the window, onto the Dock icon, or pick them with **Choose Folders…** (⌘O).
- **Pattern:** Stripes, Fair Isle, Seed Stitch, Argyle, Cable or Stockinette. **Surprise** gives every folder its own pattern, picked from its name.
- **Yarn:** ten palettes (Finder Blue, Oatmeal, Forest, Berry, Ocean, Pumpkin, Heather, Mint, Charcoal, Candy Cane), colours sampled from your **wallpaper**, **Custom** colours, or **Surprise**.
- **Wearing sweaters** lists knitted folders. Hover a folder and click × to take its sweater off (restoring the normal icon), right-click to re-knit it, or double-click to reveal it in Finder. **Re-knit All** applies the current look to every folder; **Unknit All** restores them all.

Heads up: macOS stores a custom folder icon as a hidden `Icon\r` file inside the folder. In a
git repository that file shows up as untracked, so add `Icon?` to your `.gitignore`.

## Build

Needs macOS 14+ and Swift 5.9+. The Command Line Tools are enough; Xcode is not required.

```sh
scripts/build-app.sh                 # -> build/Cozy Folders.app (ad-hoc signed, knitted app icon)
open "build/Cozy Folders.app"
scripts/test.sh                      # unit tests (swift-testing)
swift run knit-preview preview/      # render folder icons to PNG
```

## Layout

```
Sources/
├── KnitCore/                 the knitting, unit-tested
│   ├── Knitting/             StitchGeometry (V and purl stitches), KnitPattern, SwatchRenderer
│   ├── Palette/              YarnColor, YarnPresets, IconSampler, PaletteExtractor (image → yarn colours)
│   └── Folder/               FolderIconRenderer: the knitted folder, drawn on a 1024-unit canvas
├── CozyFolders/              SwiftUI app: KnitStudio (state), FolderKnitter (NSWorkspace.setIcon), ContentView
└── knit-preview/             PNG previews and the app's iconset
```
