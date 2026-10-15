# NumPatch

**Give your Mac a numpad.**

[English](README.md) · [简体中文](README.zh-CN.md)

Turn your Mac trackpad into a 3×3 numeric keypad, with customizable keys along its edges and corners. Switch it on when you need numbers or numpad shortcuts; pause it to return to your usual trackpad workflow.

Made for MacBook users and compact-keyboard setups: Blender navigation, precise modeling measurements, spreadsheet entry, and apps whose shortcuts expect a numeric keypad.

> Early development preview. macOS 13 or later is the build target; hardware and application compatibility are still being tested. A downloadable release installer is not available yet.

## Why NumPatch?

- **Actual numpad events.** Sends macOS keypad keycodes with the numeric-pad flag, rather than pasting digits. Hold Control, Shift, Option, or Command on your keyboard for modified shortcuts.
- **A simple nine-key grid.** Large 1–9 regions, with `0` on the bottom edge and `.` in the bottom-right corner by default.
- **Eight optional extra keys.** Assign each corner and edge independently. Stretch edge strips or shrink them to small semicircles; adjust corner size. Unassigned areas remain part of the 1–9 grid.
- **Keep system Tap to click enabled.** Number mode intercepts recognized one-finger taps. Two-finger secondary clicks keep the macOS right-click behavior.
- **Lives in the menu bar.** Close the window with **⌘W** or the close button; number mode keeps running. No Dock icon or ⌘Tab entry. Reopen the window from **Open NumPatch…** in its menu.
- **Your own shortcut.** Defaults to **Control + Option + Command + N**. Record a modifier combination or function key in **Settings → Recognition → General**; conflicts keep the previous binding. Starts paused and pauses on sleep.
- **Learn by tapping.** With the main window visible and number mode enabled, see the last key and its actual trackpad position. Practice inside NumPatch without typing into its controls. Closing, minimizing, or completely covering the window stops feedback delivery. No per-frame display loop runs.
- **English and Simplified Chinese.** English is the default, regardless of system language. Switch instantly in **Settings → Recognition → General → Language**.
- **No background touch sampling while paused.** Pausing stops trackpad callbacks and removes mouse event taps. Active input uses driver callbacks without a continuous UI refresh timer.

```text
┌─────────┬─────────┬─────────┐
│    7    │    8    │    9    │
├─────────┼─────────┼─────────┤
│    4    │    5    │    6    │
├─────────┼─────────┼─────────┤
│    1    │    2    │    3    │
└─────────┴──[ 0 ]──┴─────[.]─┘
       Default layout (schematic)
```

Available assignments: `0–9`, `.`, `/`, `*`, `−`, `+`, keypad Enter, Backspace, Tab, Escape, and Space. Corner zones are quarter circles; edge zones sit flush against the trackpad boundary with rounded inward ends.

## Where it can help

These examples come from the applications' own documentation. They describe useful workflows, **not a verified compatibility list**; test NumPatch with your application version and keymap.

| Application | Example workflow |
| --- | --- |
| **Blender** | Use numpad view shortcuts while modeling, or assign `.` to frame the selected object. Blender distinguishes numpad keys from the top number row. See [viewpoint shortcuts](https://docs.blender.org/manual/en/latest/editors/3dview/navigate/viewpoint.html) and [Frame Selected](https://docs.blender.org/manual/en/latest/editors/3dview/navigate/navigation.html#frame-selected). |
| **Rhino** | Enter distances and numeric measurements during precision modeling. Some coordinate and angle expressions also need punctuation from your keyboard. See [accurate modeling](https://docs.mcneel.com/rhino/mac/help/en-us/user_interface/accurate_modeling.htm). |
| **SketchUp** | Enter exact dimensions or scale values in the Measurements box. See [scaling with measurements](https://help.sketchup.com/en/sketchup/scaling-your-model-or-parts-your-model). |
| **Apple Numbers** | Enter quantities, prices, and other numerical cell values with a compact keyboard. See [entering text and numbers](https://support.apple.com/guide/numbers/tanbc336eea7/mac). |

Rhino, SketchUp, and Numbers are numeric-entry examples; these workflows do not specifically require keypad-only keycodes. Other CAD, 3D, audio, or editing apps with configurable numpad shortcuts may also be useful candidates. NumPatch has no application-specific integration or endorsement.

## Get started

For now, build from source using the instructions below.

1. Open `dist/NumPatch.app` and grant **Accessibility** access when prompted. If macOS separately requests permission to post input events, allow it as well.
2. Leave **System Settings → Trackpad → Tap to click** enabled. Enable the system's two-finger secondary-click gesture if you use it.
3. Complete calibration: keep the pointer in the blue area, wait one second, then tap three times without pressing down. Physically click three times in the second step.
4. Lift your fingers and enable number mode. Tap the corresponding trackpad region to send a key to the foreground app.
5. Pause with your shortcut (default **⌃⌥⌘N**) when you need normal trackpad tapping. **⌘W** or the close button hides the window and keeps NumPatch in the menu bar; **Quit NumPatch** exits it.

Use **Edit layout…** for key assignments and zone sizes. To change the shortcut, select **Record shortcut…**, press the combination, or press Escape to cancel. Leaving the recorder restores the previous shortcut. The menu icon shows a grid when enabled, the same grid dimmed when paused, and an ellipsis while starting. Settings save automatically. Calibration is cached for the current device and boot session; restarting macOS or changing the trackpad can require calibration again.

## Build and test

Requirements: macOS, Xcode Command Line Tools with Swift 5.9 or later, and a usable trackpad. Creating the `.app` with the build script also requires a stable local code-signing identity. No external Swift package dependencies are required.

```sh
# Compile and run the automated tests (no signing identity required).
swift test --disable-sandbox

# Build a locally signed application; this does not create a DMG.
./scripts/build.sh
open dist/NumPatch.app
```

The script selects an existing **Apple Development** identity. Set `NUMPATCH_SIGN_IDENTITY` to choose another stable identity; do not commit signing credentials. If no identity exists, compilation and tests still work, but the app-building script stops at signing.

The package, executable, and app are named **NumPatch**. The bundle identifier remains `local.touchpad-keyboard.monitor` to preserve settings and the signing identity used during development. Replacing an earlier build may still require macOS to confirm permissions again.

DMG creation is deferred until release preparation. The optional `scripts/package.sh` is reserved for that later step. Local development signing is not Developer ID distribution signing or Apple notarization.

## Current limits

- Uses the private macOS `MultitouchSupport` framework. System updates or different trackpads may change behavior. The default trackpad is used; there is no device picker.
- Each recognized tap sends a short key-down/key-up pair. Holding a virtual key and automatic key repeat are not implemented.
- Physical clicks remain mouse input. Number mode changes one-finger tapping; use the shortcut to switch between numeric input and ordinary tap-to-click.
- No blanket compatibility claim for all modeling software, remote desktops, games, input methods, or protected input fields. Application focus and keymaps affect the result.
- Routine input does not write touch/key logs or send data to a server. Layout, language, and calibration settings stay in local preferences. The optional `--diagnostics` flag enables limited developer messages in macOS unified logging.

## Development

The project uses SwiftUI/AppKit for the interface, a small C bridge for trackpad callbacks, and a tested input-state machine. See [architecture](docs/architecture.md) for input handling and performance details.

Bug reports are welcome. Include your macOS version, Mac/trackpad model, NumPatch version, target application/keymap, steps to reproduce, and whether the issue concerns tapping, physical clicking, or two-finger secondary clicking. Do not attach personal input recordings or calibration exports by default.

Third-party attribution is in [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt). A project-wide open-source license has not been selected yet.
