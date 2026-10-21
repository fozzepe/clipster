# Clipster

A tiny clipboard history manager for macOS. Everything you copy — text, images, files from Finder — stays one keystroke away.

Press **⌘E**, type to search, hit **Return**, and it's pasted into the app you were in.

- ~1,100 lines of native Swift (AppKit + SwiftUI), no dependencies
- Builds without Xcode: Command Line Tools are enough
- Universal binary (Apple Silicon + Intel), macOS 14+
- Vibe-coded in one evening with [Claude Code](https://claude.com/claude-code)

> The UI is in Russian for now.

## Install

1. Download `Clipster.zip` from [Releases](../../releases/latest), unzip, move `Clipster.app` to Applications.
2. The app isn't notarized, so macOS will block the first launch. Either go to **System Settings → Privacy & Security → Open Anyway**, or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Clipster.app
   ```
3. Allow Clipster in **Privacy & Security → Accessibility**. Without it Clipster can only copy, not auto-paste.

Or build it yourself:

```bash
xcode-select --install   # if you don't have Command Line Tools yet
./build.sh --install
```

## Keys

| Key | Action |
|---|---|
| ⌘E | Open / close history (change it in Settings) |
| typing | Search by words, any order, case-insensitive |
| ↑ ↓ | Move selection |
| Return | Paste into the active app |
| ⌥ Return | Copy only |
| ⌘1 … ⌘9 | Paste item by number |
| ⌘P | Pin / unpin |
| ⌘⌫ | Delete item |
| Tab | History ↔ Pinned |
| Esc | Close |

## Defaults

- Keeps the last 100 items, nothing older than 3 days, nothing larger than 20 MB. Pinned items are kept forever.
- Passwords copied from password managers (1Password, Bitwarden, Apple Passwords) are **not** recorded. You can turn that on in Settings.
- History is stored unencrypted in `~/Library/Application Support/Clipster/`.
- Launches at login. The global ⌘E shortcut overrides "Use Selection for Find" in other apps.

## По-русски

Менеджер истории буфера обмена для мака. Жмёшь ⌘E, ищешь, жмёшь Enter, и нужное вставляется туда, где ты был. Скачай `Clipster.zip` из Releases и при первом запуске разреши его в «Конфиденциальность и безопасность». Сделано вайбкодингом за вечер.

## License

[MIT](LICENSE)
