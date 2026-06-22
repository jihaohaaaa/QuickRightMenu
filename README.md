# QuickRightMeniu

QuickRightMeniu is a lightweight macOS Finder right-click menu extension. It provides quick file creation, copy/move actions, file utilities, image tools, text tools, terminal launch, and an in-app settings window.

The app is implemented with Objective-C and FinderSync, with a small resident menu bar app that executes commands requested by the Finder extension.

## Features

- Create files: TXT, Markdown, JSON, CSV, HTML, YAML, XML, Shell, Python, JavaScript, TypeScript, CSS, Word, Excel, and PowerPoint
- Copy: path, file name, parent directory, file URL, Markdown link
- Copy to / Move to: common system folders, custom favorite folders, or a selected folder
- File tools: batch rename
- Image tools: copy image size, compress images, convert PNG/JPEG/WebP
- Text tools: word count, convert to UTF-8, quick plain-text preview
- Settings: menu switches, file templates, favorite folders, terminal preference, login item
- Flat colored Finder menu icons

## Build

Requirements:

- macOS 13 or later
- Xcode Command Line Tools
- Python 3 with Pillow, used only to regenerate the app icon

Build:

```bash
./scripts/build.sh
```

The built app is generated at:

```text
build/QuickRightMenu.app
```

## Install Locally

Copy the built app somewhere stable, then register and enable the FinderSync extension:

```bash
cp -R build/QuickRightMenu.app /Applications/QuickRightMeniu.app
pluginkit -a "/Applications/QuickRightMeniu.app/Contents/PlugIns/QuickRightMenu Extension.appex"
pluginkit -e use -i com.liaowenbin.QuickRightMenu.Extension
open /Applications/QuickRightMeniu.app
killall Finder
```

If macOS still does not show the menu, check:

```bash
pluginkit -m -p com.apple.FinderSync -v
```

## Architecture

FinderSync extensions are sandboxed and are unreliable for directly launching arbitrary workflows from menu actions. QuickRightMeniu uses a command-file bridge:

1. The FinderSync extension writes a `.cmd` file into the shared app container.
2. The menu bar app polls that folder.
3. The menu bar app performs the requested file operation.

This keeps Finder menu handling small and avoids depending on blocked `openURL` or distributed notification behavior inside FinderSync.

## Notes

- Bundle identifiers intentionally retain `QuickRightMenu` for compatibility with existing local settings and FinderSync registration.
- The user-facing product name is `QuickRightMeniu`.
- Office files are generated as minimal valid OpenXML packages.

## License

MIT
