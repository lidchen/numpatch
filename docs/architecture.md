# NumPatch architecture

[English](architecture.md) · [简体中文](architecture.zh-CN.md)

## Input path

1. Enabling number mode or entering calibration starts the default trackpad and mouse event taps. The private MultitouchSupport driver pushes frames; the C bridge retains no presentation history. Swift keeps at most two active contacts, enough to distinguish one finger from multiple fingers.
2. A locked `TakeoverEngine` shares state between touch and mouse callbacks. Input decisions do not run on the UI thread. Tap recognition runs only in number mode; calibration tracks contacts and mouse signatures.
3. An active session-head event tap subscribes only to left down/up/drag. A separate passive tap observes right/other mouse-down events to cancel pending numeric candidates. Right-click events are not intercepted or replayed.
4. A tap must be short, move little, remain single-finger, and contain no physical press. Candidates track the foreground PID. Focus changes, new contacts, layout changes, and mouse presses invalidate stale candidates.
5. A matching native tap-to-click pair is suppressed and converted to one key. If a valid raw tap has no native click, a roughly 30 ms delayed fallback can emit it. Late matching clicks and their releases are consumed without duplicate keys.
6. A keyboard event source is created before event taps are installed, with local event suppression disabled. Actual outputs copy event templates and post down/up to the target PID on a serial queue, preserving supported modifier flags and setting the numeric-pad flag for keypad keys.
7. Pausing disables recognition, stops trackpad callbacks, and removes event taps. If a suppressed down still has a pending up, a temporary 25 ms stop timer keeps the pair balanced before teardown. Sleep pauses input. Enabling validates access, calibration, and the current device again.

## UI, preferences, and overhead

Normal input has no per-frame UI updates, pressure display, counters, touch/key files, or permanent UI refresh timer. When the main window is visible and number mode is enabled, an optional handler publishes one key/position update per accepted output. Own-window practice publishes recognized taps without injecting keys into the UI. Closing, minimizing, occluding, or displaying a settings/calibration sheet removes the handler; a generation check rejects already queued UI deliveries. Only the preview observes this state. Preferences and engine configuration update only when settings change. Optional `--diagnostics` enables limited unified-log messages.

The paused calibration badge is a cached hint for the current boot. It does not authorize output: enabling checks device identity, boot session, sample validity, and filtering capability.

English and Simplified Chinese strings are packaged as SwiftPM resources. The explicit language preference defaults to English. Status messages retain their translation key and interpolation values, so an existing status changes language immediately. Display labels are separate from persisted key bindings; legacy IDs remain stable. Language changes do not reconfigure the input engine.

## Layout geometry

Unassigned regions fall through to the full 3×3 grid. Assigned quarter-circle corners take precedence over edge strips. Edge strips are inward half capsules, flush against their trackpad edge, with straight outer corners. Each edge stores its length (4–80% of that edge) and inward depth (1–24% of the short side, capped at half the physical strip length). The preview and hit testing share a 1.5:1 coordinate model.

## Calibration and limits

The wizard collects three taps and three physical presses only inside its target area and ignores duplicate event numbers. Signatures combine mouse subtype, quantized pressure, and whether the contact has ended when the event arrives. The two sets must be disjoint; subtype or pressure alone is not assumed to identify a tap on every device.

The private touch ABI is system- and device-dependent. Unit tests cannot establish compatibility with every trackpad, tap-drag setting, external mouse, or target application. Real hardware testing remains necessary. Local development signing is not Developer ID distribution signing or notarization.

API references: [event tap options](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions), [session event tap](https://developer.apple.com/documentation/coregraphics/cgeventtaplocation/cgsessioneventtap). Private ABI attribution is in [THIRD_PARTY_LICENSES.txt](../THIRD_PARTY_LICENSES.txt).

## Menu bar lifecycle and shortcuts

`LSUIElement` and the accessory activation policy keep NumPatch out of the Dock and app switcher. A single retained AppKit window hosts SwiftUI; closing it never disables background number mode. Window delegate visibility/occlusion notifications control feedback delivery. Command-W routes to the same close action, and the menu bar reuses the window when opened again.

A Codable shortcut stores a virtual keycode, Carbon modifier mask, and display label. Recording is limited to a local first responder, with the existing hotkey suspended until completion or cancellation. Normal replacement registers the new combination before releasing the old one; failed recording restores the previous binding. Escape, focus loss, window closing, and view teardown end recording. Only the registered combination is observed globally, without a global keyboard-event monitor.
