# GuideGuide

GuideGuide is a native macOS app for browsing local HTML guide folders from one place. Pick a folder, or its `Resources` folder, and GuideGuide scans for subfolders that contain HTML entry files, serves them from a local loopback server, and opens them inside the app.

## Features

- Native SwiftUI macOS interface with a searchable site sidebar.
- Security-scoped folder bookmarks so selected libraries can be restored.
- Local HTTP server bound to `127.0.0.1` for loading HTML, CSS, JavaScript, images, and linked assets.
- Automatic rescanning when watched resource folders change.
- Support for multiple configured search paths.

## Requirements

- macOS with Xcode 26 or newer.
- Swift and Xcode command line tools installed.

## Build and Run

From the repository root:

```bash
./script/build_and_run.sh
```

To build, launch, and verify that the app process starts:

```bash
./script/build_and_run.sh --verify
```

You can also open `GuideGuide.xcodeproj` in Xcode and run the `GuideGuide` scheme.

## Project Layout

```text
GuideGuide/                 App source
GuideGuideTests/            Unit tests
GuideGuideUITests/          UI tests
GuideGuide.xcodeproj/       Xcode project
script/build_and_run.sh     Local build/run helper
```
