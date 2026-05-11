# SwiftTranslate

SwiftTranslate is a macOS menu bar translation app for selected text.

It uses a global hotkey to copy the current selection from the frontmost app, restores the user's clipboard, sends the text through Apple's system `Translation` framework, and shows the result in a floating overlay near the cursor.

## Features

- Global translation hotkey: `Command + Shift + T`
- Works across common macOS apps that support standard Copy
- Floating overlay near the cursor instead of forcing a full window workflow
- Target language switching from the menu bar or console window
- Chinese and English interface localization
- Optional automatic copy of the translated result
- Built-in speech playback for translated text
- Copy action directly from the overlay
- Overlay auto-dismiss, hover pause, outside-click dismiss, and close-on-stop behavior

## Current Interaction Model

1. Select text in any app.
2. Press `Command + Shift + T`.
3. SwiftTranslate sends a simulated `Command + C` to the frontmost app.
4. It reads plain text from the clipboard.
5. It restores the original clipboard contents.
6. It requests a translation using the macOS `Translation` framework.
7. It shows the result in the floating overlay.

## Requirements

- macOS 15+
- Xcode 16.4+
- Accessibility permission enabled for SwiftTranslate

The app depends on Apple's `Translation` framework, so translation availability also depends on the language pair supported by the local system.

## Permissions

SwiftTranslate needs **Accessibility** permission to trigger Copy in the frontmost app.

Enable it in:

`System Settings > Privacy & Security > Accessibility`

Without that permission, the app cannot reliably capture selected text outside itself.

## Supported Languages

Current target language options:

- Simplified Chinese
- English
- Japanese
- Korean
- French
- German
- Spanish

The source language is detected automatically before translation.

## Project Structure

`x-translator/AppState.swift`

- Main app state
- Translation flow orchestration
- Language detection
- Clipboard-related actions
- Speech playback state

`x-translator/SelectionMonitor.swift`

- Frontmost app selection capture
- Simulated `Command + C`
- Clipboard snapshot and restore

`x-translator/GlobalHotKeyManager.swift`

- Native Carbon global hotkey registration

`x-translator/OverlayPanelController.swift`

- Floating overlay window lifecycle
- Auto-dismiss
- Hover pause
- Outside-click dismissal

`x-translator/OverlayView.swift`

- Main overlay UI
- Loading, error, result, copy, play/stop controls

`x-translator/InteractiveTranslationTextView.swift`

- Native text rendering for long translation content
- Text selection
- Scroll-to-current-spoken-range behavior

`x-translator/TranslationWorkerView.swift`

- Hidden SwiftUI host view that performs the actual `Translation` task

`x-translator/MenuBarContentView.swift`

- Menu bar UI
- Quick actions
- Target language picker

`x-translator/SettingsView.swift`

- Console window
- Permissions, interface language, activity, and app preferences

## Development

Open the project in Xcode:

```bash
open /Users/xinsi/Documents/code/x-translator/x-translator.xcodeproj
```

Or build from Terminal:

```bash
xcodebuild \
  -scheme x-translator \
  -project /Users/xinsi/Documents/code/x-translator/x-translator.xcodeproj \
  -configuration Debug \
  -derivedDataPath /Users/xinsi/Documents/code/x-translator/.derived-data \
  build
```

The built app is generated at:

`/Users/xinsi/Documents/code/x-translator/.derived-data/Build/Products/Debug/SwiftTranslate.app`

## Assets

- App icon source: [x-translator/logo-source.png](x-translator/logo-source.png)
- App icon set: [x-translator/Assets.xcassets/AppIcon.appiconset](x-translator/Assets.xcassets/AppIcon.appiconset)
- Menu bar icon set: [x-translator/Assets.xcassets/MenuBarIcon.imageset](x-translator/Assets.xcassets/MenuBarIcon.imageset)

## Known Limitations

- The app relies on standard Copy behavior. If the frontmost app does not respond to `Command + C`, capture may fail.
- The system `Translation` framework may reject unsupported language pairs or unavailable on-device resources.
- Source and target being the same language is treated as an error.
- Very short or ambiguous text may fail language detection.
- Some apps expose selections inconsistently, so behavior can vary across macOS apps.
- The current global hotkey is fixed and not yet user-configurable.

## Roadmap Ideas

- Custom global hotkey recording
- More target languages
- Replace selected text with translated text
- One-click write-back to replace the currently selected text
- Better progress, retry, and fallback states for system translation failures
- Translation history for recently translated content
- Favorite / pinned language pairs
- Batch translation for multiple clipboard items or paragraphs
- Better source-language override when auto detection is wrong
- Per-app behavior rules, such as ignore lists or preferred language pairs
- Optional shortcut customization from the settings window
- More robust speech playback controls, including pause / resume and speed selection

## License

No license file is included yet.
