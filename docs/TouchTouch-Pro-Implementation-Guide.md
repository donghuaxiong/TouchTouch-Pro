# TouchTouch Pro Development Guide

This document turns the product direction into an implementation plan that another coding agent can execute. It is written for the current SwiftPM macOS app in this repository.

Current baseline:

- App target: `TouchTouch`, macOS 13+, menu bar app.
- Core state: `Sources/TouchTouch/Stores/AppState.swift`.
- Gesture routing: `Sources/TouchTouch/Services/TrackpadEventMonitor.swift`.
- Raw touch sampling: `Sources/TouchTouch/Services/MultiTouchSupportManager.swift`.
- Existing actions: screen brightness, output volume, keyboard backlight, microphone input volume, previous/next track.
- Current gesture model: modifier key plus left/right trackpad edge vertical scroll.

The paid product direction should be: **a trackpad edge control console for Mac work, meetings, windows, browser, and system controls**. Avoid becoming a generic clone of BetterTouchTool. Ship opinionated modes first, then add custom mappings.

## 1. Architecture Refactor First

Do this before adding more features. The current `ControlTarget` enum is already growing beyond brightness and volume. Keep the implementation modular so paid features can be added without turning `AppState.perform(...)` into a large switch.

### 1.1 Add Gesture Vocabulary

Create a new file:

`Sources/TouchTouch/Models/GestureModels.swift`

Suggested types:

```swift
enum TrackpadEdge: String, Codable, CaseIterable {
    case left
    case right
    case top
    case bottom
}

enum TrackpadCorner: String, Codable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum GestureKind: Equatable, Codable {
    case edgeScroll(edge: TrackpadEdge, axis: ScrollAxis)
    case cornerTap(corner: TrackpadCorner)
    case edgeHold(edge: TrackpadEdge)
}

enum ScrollAxis: String, Codable {
    case vertical
    case horizontal
}

enum GestureLayer: String, Codable, CaseIterable {
    case option
    case control
    case command
    case optionCommand
    case none
}

struct GestureTrigger: Equatable, Codable {
    var layer: GestureLayer
    var kind: GestureKind
}
```

Initial implementation can support only `edgeScroll(..., .vertical)`. Add the other cases so settings and routing will not need another shape change later.

### 1.2 Replace ControlTarget With ActionTarget

Create:

`Sources/TouchTouch/Models/ActionModels.swift`

Suggested model:

```swift
enum ActionTarget: String, Codable, CaseIterable, Identifiable {
    case screenBrightness
    case outputVolume
    case keyboardBacklight
    case microphoneInputVolume
    case microphoneMuteToggle
    case cameraPrivacyToggle
    case previousTrack
    case nextTrack
    case playPause
    case windowLeftHalf
    case windowRightHalf
    case windowMaximize
    case windowCenter
    case browserBack
    case browserForward
    case browserNextTab
    case browserPreviousTab
    case runShortcut
    case sendKeyboardShortcut

    var id: String { rawValue }
}

enum ActionValue {
    case continuous(delta: Double)
    case discrete
}
```

Migration note:

- Keep `ControlTarget` temporarily if needed for HUD compatibility.
- Prefer converting HUD to use `ActionTarget`.
- Continuous actions should return a normalized `Double?` for HUD.
- Discrete actions should return an `ActionResult` with label/icon/status.

Suggested protocol:

```swift
protocol TouchAction {
    var target: ActionTarget { get }
    func perform(_ value: ActionValue) async -> ActionResult
}

struct ActionResult {
    var didPerform: Bool
    var hudValue: Double?
    var title: String
    var systemImage: String
}
```

### 1.3 Add Action Dispatcher

Create:

`Sources/TouchTouch/Services/ActionDispatcher.swift`

Responsibilities:

- Own individual managers, not `AppState`.
- Convert `ActionTarget` to manager calls.
- Rate limit discrete actions like next track, mute toggle, window snapping.
- Return `ActionResult` for HUD and haptics.

`AppState` should keep settings and call:

```swift
let result = await actionDispatcher.perform(action, value: value)
```

### 1.4 Make Gesture Mapping Configurable

Add:

```swift
struct GestureMapping: Identifiable, Codable, Equatable {
    var id: UUID
    var trigger: GestureTrigger
    var action: ActionTarget
    var isEnabled: Bool
    var appBundleIdentifier: String?
    var parameter: String?
}
```

Store mappings in `UserDefaults` as JSON under a new key:

`gestureMappings.v1`

Default mappings:

- `Option + left edge vertical scroll` -> `screenBrightness`
- `Option + right edge vertical scroll` -> `outputVolume`
- `Control + left edge vertical scroll` -> `keyboardBacklight`
- `Control + right edge vertical scroll` -> `microphoneInputVolume`
- `Command + left edge vertical scroll` -> `previousTrack`
- `Command + right edge vertical scroll` -> `nextTrack`

App-specific mappings should be loaded after global mappings and win when `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` matches.

## 2. Gesture Engine Upgrade

The most important technical unlock is expanding `MultiTouchSupportManager` beyond `averageX`.

### 2.1 Capture Touch Snapshot

Update `MultiTouchSupportManager` to keep:

```swift
struct TouchSnapshot {
    var averageX: Double
    var averageY: Double
    var averageVelocityX: Double
    var averageVelocityY: Double
    var fingerCount: Int
    var timestamp: Date
}
```

Use fields already present in `MTFinger`:

- `normalized.position.x`
- `normalized.position.y`
- `normalized.velocity.x`
- `normalized.velocity.y`
- `fingerCount`

Implementation details:

1. Replace `latestAverageX` with `latestSnapshot`.
2. In the callback, collect valid `x/y` values in `0...1`.
3. Compute average position and velocity.
4. Expose `recentSnapshot(maxAge:) -> TouchSnapshot?`.

### 2.2 Edge and Corner Classification

Add:

```swift
struct TrackpadRegionResolver {
    var edgeWidth: Double
    var cornerSize: Double

    func edge(for snapshot: TouchSnapshot) -> TrackpadEdge?
    func corner(for snapshot: TouchSnapshot) -> TrackpadCorner?
}
```

Rules:

- `x <= edgeWidth` -> left.
- `x >= 1 - edgeWidth` -> right.
- `y <= edgeWidth` -> bottom.
- `y >= 1 - edgeWidth` -> top.
- Corners require both x and y thresholds.

Priority:

1. Corner tap/hold recognition.
2. Edge scroll recognition.
3. Fallback modifier-only behavior.

### 2.3 Horizontal Scroll

Current code uses only `scrollingDeltaY` and `scrollWheelEventPointDeltaAxis1`. Add X-axis support:

- NSEvent: `event.scrollingDeltaX`
- CGEvent: `.scrollWheelEventPointDeltaAxis2` and `.scrollWheelEventDeltaAxis2`

Use horizontal scroll for:

- Browser back/forward.
- Timeline scrub.
- Previous/next tab.
- Media seek.

### 2.4 Tap and Hold Recognition

This is optional for v1 Pro, but design for it.

Possible APIs:

- Raw touch frames from `MultiTouchSupport.framework` for contact down/up and duration.
- `NSEvent` local/global monitors for `.gesture`, `.magnify`, `.swipe`, and `.pressure` where available.

Implementation plan:

1. Track active touch IDs from `MTFinger.fingerID`.
2. Record first-seen timestamp and region.
3. If contact ends within 180 ms and movement is below a small threshold, classify as tap.
4. If contact stays in region for 450 ms, classify as hold.
5. Do not consume system events until confidence is high.

Risk:

- `MultiTouchSupport.framework` is private and can break across macOS versions.
- Tap/hold recognition can conflict with normal trackpad usage. Keep it behind a feature flag.

## 3. Meeting Mode

Meeting Mode is the strongest paid feature candidate because the problem is frequent and painful: mute, camera, audio device, and meeting app controls need to be quick and reliable.

### 3.1 Microphone Mute Toggle

Goal:

- Toggle the system default input device mute state when possible.
- Fall back to setting input volume to zero and restoring the previous value.

APIs:

- CoreAudio:
  - `AudioObjectGetPropertyData`
  - `AudioObjectSetPropertyData`
  - `kAudioHardwarePropertyDefaultInputDevice`
  - `kAudioDevicePropertyMute`
  - `kAudioDevicePropertyVolumeScalar`
  - scope: `kAudioDevicePropertyScopeInput`
- Existing manager:
  - `MicrophoneVolumeManager`

Implementation:

1. Create `MicrophoneControlManager`.
2. Add `defaultInputDeviceID()`.
3. Check if `kAudioDevicePropertyMute` exists and is settable.
4. If settable, read current mute and write the opposite.
5. If unavailable, store previous input volume in `UserDefaults` under `lastNonZeroInputVolume`.
6. If current input volume > `0.02`, set volume to `0`.
7. If current input volume <= `0.02`, restore `lastNonZeroInputVolume` or `0.5`.
8. Return HUD result with `mic.slash.fill` or `mic.fill`.

Permissions:

- Usually no special permission for CoreAudio device volume/mute.
- If using AppleScript fallback, app may need Automation permission for `osascript` in some flows.

Acceptance:

- Works with built-in microphone.
- Works with at least one external USB/Bluetooth input device if it exposes settable input volume or mute.
- HUD reflects muted/unmuted state.
- Does not spam writes while user scrolls.

Risk:

- Some devices do not expose settable mute or input volume.
- On unsupported devices, show “This input device does not support mute control.”

### 3.2 Meeting App Shortcuts

Goal:

- Provide app-specific actions for Zoom, Microsoft Teams, Google Meet in browser, FaceTime, and Slack huddles.

API:

- `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`
- `CGEvent` keyboard event posting:
  - `CGEvent(keyboardEventSource:virtualKey:keyDown:)`
  - `CGEvent.post(tap: .cghidEventTap)`
- Accessibility permission:
  - `AXIsProcessTrusted`

Initial mappings:

- Zoom:
  - Toggle mute: `Command + Shift + A`
  - Toggle video: `Command + Shift + V`
  - Share screen: `Command + Shift + S`
- Google Meet in browser:
  - Toggle mute: `Command + D`
  - Toggle camera: `Command + E`
- Microsoft Teams:
  - Toggle mute: `Command + Shift + M`
  - Toggle camera: `Command + Shift + O`

Implementation:

1. Create `KeyboardShortcutSender`.
2. Define:

```swift
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: CGKeyCode
    var modifiers: CGEventFlags
}
```

3. Add `MeetingActionManager`.
4. Detect frontmost app bundle identifier.
5. For browser-based meeting controls, start with global browser shortcuts. Do not inspect page content in v1.
6. Add settings UI for users to override shortcuts per app.
7. Show HUD with the action name.

Permissions:

- Accessibility is required to post keyboard events reliably.
- Input Monitoring is already requested by TouchTouch for gestures.

Acceptance:

- Shortcut only fires when the target app/profile is active.
- User can disable per-app meeting shortcuts.
- If Accessibility is missing, show permission warning instead of failing silently.

Risk:

- Shortcuts differ by app version, keyboard layout, and localization.
- Web apps can intercept or change shortcuts.

### 3.3 Audio Output Device Switcher

Goal:

- Cycle output devices from trackpad gesture, useful when switching AirPods, monitor speakers, and MacBook speakers.

APIs:

- CoreAudio:
  - `kAudioHardwarePropertyDevices`
  - `kAudioDevicePropertyDeviceNameCFString`
  - `kAudioDevicePropertyStreams`
  - `kAudioHardwarePropertyDefaultOutputDevice`
  - `AudioObjectSetPropertyData`

Implementation:

1. Create `AudioDeviceManager`.
2. Enumerate all audio devices.
3. Filter devices with output streams.
4. Read current default output device.
5. Cycle to next enabled output device.
6. Persist preferred order if the user edits it.
7. Show HUD with device name.

Permissions:

- Usually none.

Acceptance:

- Built-in speaker and connected Bluetooth device appear.
- Cycling skips unavailable devices.
- HUD shows the selected output device.

Risk:

- Some aggregate or virtual devices may behave badly. Allow users to hide devices.

### 3.4 Meeting Mode Toggle

Goal:

- One gesture enters a temporary mode where edges map to meeting controls.

Default:

- `Option + Command + right edge hold` -> Meeting Mode on/off.

Implementation:

1. Add `ActiveMode` enum: `.normal`, `.meeting`, `.window`, `.browser`, `.developer`.
2. Store active mode in `AppState`.
3. Show a small menu bar indicator or HUD when mode changes.
4. Optional: auto-enable Meeting Mode when frontmost app is Zoom/Teams/FaceTime or browser tab title contains Meet.

Risk:

- Browser tab title detection needs Accessibility or scripting. Keep auto-detection optional.

## 4. Window Mode

Window control is the second strongest paid feature. It solves an everyday Mac pain: arranging windows without dragging.

### 4.1 Basic Window Snapping

Goal:

- Snap the frontmost window to left half, right half, top half, bottom half, maximize, center, or quarters.

APIs:

- Accessibility:
  - `AXUIElementCreateApplication(pid)`
  - `AXUIElementCopyAttributeValue`
  - `AXUIElementSetAttributeValue`
  - `kAXFocusedWindowAttribute`
  - `kAXPositionAttribute`
  - `kAXSizeAttribute`
- AppKit:
  - `NSScreen.screens`
  - `NSScreen.visibleFrame`

Implementation:

1. Create `WindowManager`.
2. Use frontmost app PID from `NSWorkspace.shared.frontmostApplication`.
3. Get focused window via Accessibility.
4. Compute target frame from current screen `visibleFrame`.
5. Set AX position and size.
6. Add a short debounce around window actions.

Default mappings:

- `Command + left edge vertical scroll up` -> left half.
- `Command + right edge vertical scroll up` -> right half.
- `Command + top edge scroll` -> maximize.
- `Command + bottom edge scroll` -> center or minimize.

Permissions:

- Accessibility required.

Acceptance:

- Works in Finder, Safari, Chrome, VS Code, Terminal.
- Does not crash on apps with no focused window.
- Respects menu bar and Dock using `visibleFrame`.
- Handles multiple displays by detecting the screen containing the window center.

Risk:

- Some apps do not expose AX window attributes or refuse resizing.
- Full-screen windows cannot be resized this way.

### 4.2 Multi-Display Window Move

Goal:

- Move focused window to next display while preserving relative size.

APIs:

- Same Accessibility APIs as snapping.
- `NSScreen.screens`.

Implementation:

1. Get current window frame.
2. Find source screen by intersection area.
3. Find next screen in user order.
4. Convert window frame into normalized coordinates inside source visible frame.
5. Apply normalized frame to destination visible frame.

Acceptance:

- Works with two or more displays.
- Keeps window fully visible on destination screen.

### 4.3 App Window Cycling

Goal:

- Cycle windows of the current app from trackpad.

APIs:

- Keyboard shortcut fallback:
  - `Command + backtick`
- Accessibility alternative:
  - `AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, ...)`
  - `AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute, window)`

Recommendation:

- Use keyboard shortcut fallback first for reliability.
- Add AX implementation later if needed.

## 5. Browser and Reading Mode

Browser workflows are high-frequency and easy to understand. Implement using app-specific keyboard shortcuts first.

### 5.1 Browser Navigation

Apps:

- Safari: `com.apple.Safari`
- Chrome: `com.google.Chrome`
- Arc: `company.thebrowser.Browser`
- Edge: `com.microsoft.edgemac`
- Firefox: `org.mozilla.firefox`

Actions:

- Back
- Forward
- Next tab
- Previous tab
- New tab
- Close tab
- Reopen closed tab
- Copy current URL

APIs:

- `NSWorkspace.shared.frontmostApplication`
- `KeyboardShortcutSender`
- Optional AppleScript for Safari/Chrome URL read:
  - Safari: `tell application "Safari" to get URL of front document`
  - Chrome: `tell application "Google Chrome" to get URL of active tab of front window`

Default shortcuts:

- Back: `Command + [`
- Forward: `Command + ]`
- Next tab: `Control + Tab` or `Command + Shift + ]`
- Previous tab: `Control + Shift + Tab` or `Command + Shift + [`
- New tab: `Command + T`
- Close tab: `Command + W`
- Reopen closed tab: `Command + Shift + T`
- Copy URL: `Command + L`, then `Command + C`

Implementation:

1. Add Browser profile with bundle IDs.
2. Map horizontal edge scroll to back/forward.
3. Map top/bottom edge to tab changes.
4. Add user-editable shortcuts.
5. Keep URL extraction optional because it triggers Automation permission prompts.

Acceptance:

- Works in Safari, Chrome, Arc, and Edge via shortcuts.
- Browser profile does nothing outside browser apps unless user enables global fallback.

Risk:

- Keyboard layout differences can affect bracket keys.
- `Command + L` plus `Command + C` changes focus to address bar. That is acceptable only for explicit “copy URL” action.

### 5.2 Save to Shortcuts

Goal:

- Let users run a macOS Shortcut from a gesture, such as “Save URL to Notion”, “Append to Obsidian”, or “Create task”.

APIs:

- `shortcuts` CLI:
  - `/usr/bin/shortcuts run "Shortcut Name"`
- URL scheme:
  - `shortcuts://run-shortcut?name=...`
- `NSWorkspace.shared.open(URL)`

Implementation:

1. Create `ShortcutRunner`.
2. Prefer `/usr/bin/shortcuts run` because it is scriptable and easy to capture errors.
3. Add `runShortcut(name:)`.
4. Add settings field for shortcut name.
5. Optional: pass input later using clipboard or temporary file.

Permissions:

- Shortcuts may prompt for permissions depending on shortcut contents.

Acceptance:

- Running a valid shortcut shows HUD success.
- Missing shortcut returns a useful error.

## 6. Developer Mode

Developer Mode should ship as app-specific shortcut presets. Do not integrate with every editor API in v1.

### 6.1 Supported Apps

Initial bundle IDs:

- Cursor: `com.todesktop.230313mzl4w4u92`
- VS Code: `com.microsoft.VSCode`
- Terminal: `com.apple.Terminal`
- iTerm2: `com.googlecode.iterm2`
- Xcode: `com.apple.dt.Xcode`

Actions:

- Command palette
- Run/build/test
- Format document
- Toggle terminal
- Next/previous editor tab
- Open source control
- Clear terminal

APIs:

- `KeyboardShortcutSender`
- `NSWorkspace` frontmost app detection

Implementation:

1. Add `AppProfile` model:

```swift
struct AppProfile: Codable, Identifiable {
    var id: String
    var displayName: String
    var bundleIdentifiers: [String]
    var defaultMappings: [GestureMapping]
}
```

2. Create default profiles in code.
3. Store user overrides separately from defaults.
4. Show only relevant profile when active app is supported.

Acceptance:

- Cursor/VS Code default mappings work without extra setup.
- User can disable Developer Mode.
- No action fires in unsupported apps unless global mapping exists.

## 7. Creator Mode

Creator Mode should focus on continuous controls because TouchTouch has an advantage there.

Initial target apps:

- Figma desktop
- Adobe apps if installed
- Final Cut Pro
- Logic Pro

V1 implementation:

- Use shortcuts only.
- Avoid private app automation unless users explicitly opt in.

Potential mappings:

- Horizontal edge scroll: timeline or canvas zoom.
- Vertical edge scroll: brush size, opacity, timeline zoom.
- Top/bottom edges: tool switch, play/pause, marker.

APIs:

- `KeyboardShortcutSender`
- Optional AppleScript only where officially scriptable.

Risk:

- Creative apps have highly customized shortcut sets. Make presets editable.

## 8. System Control Layer

This layer should contain high-frequency Mac toggles and device controls.

### 8.1 Dark Mode Toggle

API:

- AppleScript:

```applescript
tell application "System Events"
  tell appearance preferences to set dark mode to not dark mode
end tell
```

Implementation:

- Use `ProcessRunner` with `/usr/bin/osascript`.
- Show HUD success/failure.

Permissions:

- Automation/Accessibility may be required for System Events.

Risk:

- AppleScript permissions can be noisy. Keep this as optional Pro action.

### 8.2 Focus / Do Not Disturb

Recommended v1:

- Do not rely on private Focus APIs.
- Let users create a Shortcut and run it from TouchTouch.

Implementation:

- Provide a built-in action template: `runShortcut("Toggle Focus")`.
- In UI, explain that Focus control uses Apple Shortcuts.

### 8.3 Lock Screen and Sleep

APIs:

- Lock screen:
  - `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`
- Display sleep:
  - `/usr/bin/pmset displaysleepnow`
- System sleep:
  - `/usr/bin/pmset sleepnow`

Implementation:

- Add `SystemPowerManager`.
- Use `ProcessRunner`.
- Require confirmation toggle for system sleep.

Risk:

- Avoid accidental triggering. Only allow corner hold or explicit layer gesture.

### 8.4 Screenshot Actions

APIs:

- Keyboard shortcuts:
  - `Command + Shift + 3`
  - `Command + Shift + 4`
  - `Command + Shift + 5`

Implementation:

- Use `KeyboardShortcutSender`.

Acceptance:

- HUD appears after shortcut is posted.

## 9. Settings UI Plan

The current settings window already has tabs. Keep that structure, but rename around user problems instead of technical controls.

Recommended tabs:

- Control
- Meeting
- Window
- Browser
- Apps
- Feedback
- Advanced

### 9.1 Control Tab

Show default layers:

- Option: brightness and output volume.
- Control: keyboard backlight and microphone volume.
- Command: media previous/next.

### 9.2 Meeting Tab

Controls:

- Enable Meeting Mode.
- Mute gesture.
- Camera gesture.
- Audio device switch gesture.
- App-specific shortcut table.
- Test buttons for each action.

### 9.3 Window Tab

Controls:

- Enable Window Mode.
- Left/right/maximize/center mappings.
- Multi-display move mapping.
- Excluded apps list.

### 9.4 Browser Tab

Controls:

- Enable Browser Profile.
- Browser app list.
- Back/forward/tab actions.
- Optional Shortcuts integration.

### 9.5 Apps Tab

Controls:

- Profiles for Cursor, VS Code, Xcode, Terminal, Figma.
- Per-app mappings.
- Add custom app from currently frontmost app.

### 9.6 Advanced Tab

Controls:

- Edge width.
- Corner size.
- Scroll threshold.
- Debounce.
- Enable private framework features.
- Export/import mappings JSON.

## 10. Permissions

Existing:

- Accessibility: `AXIsProcessTrusted`.
- Input Monitoring: `CGPreflightListenEventAccess`.

Add permission status rows:

- Accessibility: required for event posting and window management.
- Input Monitoring: required for global gesture detection.
- Automation: optional; needed for AppleScript actions.
- Shortcuts: handled by system prompts per shortcut.

Implementation:

1. Expand `PermissionManager`.
2. Add a status enum:

```swift
enum PermissionStatus {
    case granted
    case missing
    case unknown
}
```

3. Show missing permissions in settings and HUD when an action fails.

Important:

- macOS does not expose a clean preflight API for every Automation permission. Detect by attempting a harmless AppleScript and handling failure.

## 11. Implementation Order

Build in this order:

1. Add `GestureModels.swift` and `ActionModels.swift`.
2. Add `ActionDispatcher.swift` and move current action switch out of `AppState`.
3. Upgrade `MultiTouchSupportManager` to return `TouchSnapshot`.
4. Upgrade `TrackpadEventMonitor` to resolve left/right/top/bottom edges.
5. Migrate current defaults into `GestureMapping`.
6. Add `KeyboardShortcutSender`.
7. Add Meeting Mode:
   - microphone mute toggle
   - app-specific shortcut sending
   - audio output cycling
8. Add Window Mode:
   - focused window lookup
   - left/right/maximize/center
   - multi-display move
9. Add Browser Profile:
   - back/forward
   - tab switching
   - run Shortcut
10. Add settings tabs for Meeting, Window, Browser, Apps.
11. Add tests for mapping resolution and action dispatch.
12. Update README and packaging notes.

## 12. Tests

Add unit tests for pure logic:

- Region classification:
  - left/right/top/bottom/corners.
- Gesture mapping priority:
  - app-specific mapping overrides global mapping.
  - disabled mapping is ignored.
- Scroll accumulation:
  - threshold triggers once.
  - debounce suppresses repeated discrete actions.
- Direction reversal:
  - continuous deltas invert correctly.

Suggested test files:

- `Tests/TouchTouchTests/TrackpadRegionResolverTests.swift`
- `Tests/TouchTouchTests/GestureMappingResolverTests.swift`
- `Tests/TouchTouchTests/ActionDispatcherTests.swift`

Manual QA:

- Permission missing states.
- Menu bar app launch.
- Settings window open/close.
- Built-in display brightness.
- Built-in speaker volume.
- Keyboard backlight on supported MacBook.
- Microphone input volume/mute.
- Media next/previous.
- Window snapping in Finder/Safari/VS Code.
- Browser navigation in Safari/Chrome/Arc.
- External display window movement.

## 13. Distribution and Risk Notes

Private frameworks currently used or planned:

- `MultiTouchSupport.framework`: already used for raw trackpad position.
- `MediaRemote.framework`: already used for previous/next track.
- Keyboard backlight helper likely relies on private IOKit selectors.

Implications:

- Suitable for direct distribution, personal use, or non-App-Store distribution.
- Not suitable for Mac App Store without replacing private APIs.
- macOS updates may break private calls.

Mitigation:

- Add feature availability checks.
- Keep private-framework actions optional.
- Show clear unsupported-device messages.
- Add logging for failed symbol lookup and unsupported hardware.

## 14. Paid Feature Packaging

Recommended free version:

- Brightness.
- Output volume.
- Media previous/next.
- Basic HUD and haptics.

Recommended Pro version:

- Meeting Mode.
- Window Mode.
- Browser Profile.
- App Profiles.
- Custom gesture mappings.
- Shortcuts integration.
- Export/import profiles.
- Multi-display window movement.

License boundary in code:

- Add `FeatureGate` service later:

```swift
enum ProFeature {
    case meetingMode
    case windowMode
    case appProfiles
    case customMappings
    case shortcutsIntegration
}

protocol FeatureGate {
    func isEnabled(_ feature: ProFeature) -> Bool
}
```

Keep feature checks in UI and dispatcher, not deep inside every manager.

## 15. Definition of Done for First Paid MVP

The first paid MVP is complete when:

- Current brightness/volume/keyboard/microphone/media controls still work.
- User can enable Meeting Mode and toggle mute from a trackpad gesture.
- User can snap the focused window left/right/maximize from gestures.
- Browser back/forward works in at least Safari and Chrome.
- Settings clearly show mappings by mode.
- Missing permissions are surfaced clearly.
- Unsupported devices fail gracefully.
- Mapping resolution has unit tests.
- README describes private API distribution risk.

