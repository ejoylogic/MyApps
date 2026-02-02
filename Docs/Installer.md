# PickleClipper Local Build & Test Installer

This repository includes starter source code for a SwiftUI macOS app. Because macOS apps must be code-signed and built with Apple tooling, the installer executable must be generated on a Mac (Xcode or the command-line tools are required). This document explains how to produce a local `.app` and an optional `.dmg` you can run on your Mac for testing.

## Prerequisites
- macOS 13+ recommended.
- Xcode installed from the App Store (or `xcode-select` configured).

## Create a minimal Xcode project
1. Open Xcode and create a new **macOS App** project named `PickleClipper`.
2. Set the interface to **SwiftUI** and language to **Swift**.
3. Replace the generated `ContentView.swift` and `PickleClipperApp.swift` with the files from `StarterCode/Sources/PickleClipper`.
4. Add the remaining files from `StarterCode/Sources/PickleClipper` to the Xcode project:
   - `Models.swift`
   - `VideoImporter.swift`
   - `Validation.swift`
   - `ExportService.swift`

## Build the app (.app)
1. Select **My Mac** as the run destination.
2. Product → **Build** (⌘B).
3. The built app can be found in:
   `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/PickleClipper.app`

## Export an installable .dmg (optional)
1. Open a Terminal and `cd` to the folder that contains `PickleClipper.app`.
2. Run:
   ```bash
   hdiutil create -volname PickleClipper -srcfolder PickleClipper.app -ov -format UDZO PickleClipper.dmg
   ```
3. Double-click `PickleClipper.dmg` to install (drag to Applications).

## Notes on distribution
- For wider distribution, the app must be code-signed and notarized.
- Apple Silicon Macs will run the native build automatically when compiled on that machine.

If you want, I can add an Xcode project file to this repo to make building even easier (it was intentionally omitted in the starter skeleton).
