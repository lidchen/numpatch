# NumPatch

**Give your Mac a numpad.**

[English](README.md) · [简体中文](README.zh-CN.md)

NumPatch turns your Mac trackpad into a customizable numeric keypad. Tap a region to send a true numpad key, so MacBook users without a physical keypad can use shortcuts that depend on numpad keycodes.

Use it with software such as Blender that supports numpad shortcuts to change views, frame selected objects, and trigger custom keypad actions.

## Features

- **3×3 number layout.** Large regions map to 1–9, with `0` and `.` along the bottom edge by default.
- **Custom keys.** Add keys to the four corners and four edges, then adjust their size. Available keys include `0–9`, `.`, `/`, `*`, `−`, `+`, keypad Enter, Backspace, Tab, Escape, and Space.
- **Numpad keycodes.** Applications receive distinct numeric-keypad events. Combine them with Control, Shift, Option, or Command on a physical keyboard.
- **On-demand input.** Toggle number mode with a global shortcut. Pause it to return to trackpad tapping. Two-finger secondary clicks continue to use the macOS right-click behavior.
- **Menu bar app.** Closing the main window keeps NumPatch running in the menu bar. Reopen the window or quit from its menu.
- **Configurable shortcut.** The default is **⌃⌥⌘N**. Record a new modifier combination or function key in **Settings → Recognition → General**.
- **Layout feedback.** The main window shows the keypad layout, the last key pressed, and its trackpad position.
- **English and Simplified Chinese.** Switch languages in **Settings → Recognition → General → Language**.

Default layout:

```text
┌─────────┬─────────┬─────────┐
│    7    │    8    │    9    │
├─────────┼─────────┼─────────┤
│    4    │    5    │    6    │
├─────────┼─────────┼─────────┤
│    1    │    2    │    3    │
└─────────┴──[ 0 ]──┴─────[.]─┘
```

## Use NumPatch

1. Open NumPatch and grant Accessibility access when macOS prompts you.
2. Enable **System Settings → Trackpad → Tap to click**.
3. Follow the calibration guide for your trackpad.
4. Enable number mode and tap a region to send its key to the active app.
5. Use the global shortcut to pause number mode and return to normal trackpad operation.

Choose **Edit layout…** to assign corner and edge keys and adjust their size. Choose **Record shortcut…** to change the global shortcut. Settings save automatically.

## Build

NumPatch requires macOS 13 or later and Swift 5.9 or later.

```sh
swift test --disable-sandbox
./scripts/build.sh
open dist/NumPatch.app
```

Building the app requires an available local code-signing identity.

## Development

The interface uses SwiftUI and AppKit, with a C bridge for trackpad events. See the [architecture notes](docs/architecture.md) for implementation details.
