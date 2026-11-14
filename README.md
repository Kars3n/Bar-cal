# Bar-cal

A quiet native calendar and to-do drawer for your Mac.

**[Download Bar-cal v1.0.0 (.dmg)](https://github.com/Kars3n/Bar-cal/releases/download/v1.0.0/Bar-cal-1.0.0-macOS-arm64.dmg)**

Requires **macOS 27 or later on Apple silicon**. The app is Developer ID signed
and notarized by Apple.

## Features

- Compact calendar with your selected calendars and agenda.
- Menu-bar mode or a small notch attached to either screen edge.
- Optional slim **Cal** and **To-do** tabs in one shared drawer.
- A To-do view that mirrors one Apple Reminders list, including undated tasks.
  Checkboxes complete reminders in Reminders, with undo support.
- Pull a collapsed tab inward to reveal its content; drag vertically to move
  the tabs. Drag an open drawer to dock it on either side.
- Slate, Light, Dark, and System appearances, with native size options.
- Keyboard navigation and an optional global shortcut.

## Download

The [v1.0.0 DMG](https://github.com/Kars3n/Bar-cal/releases/download/v1.0.0/Bar-cal-1.0.0-macOS-arm64.dmg)
contains **Bar-cal.app** and an **Applications** shortcut. A ZIP and SHA-256
checksums are also available on [GitHub Releases](https://github.com/Kars3n/Bar-cal/releases/latest).

Calendar and Reminders permissions are controlled by macOS. Reminders access is
requested when you choose to connect it; choose your own list inside To-do.

General settings select the presentation mode, screen edge, and optional shared
tabs. Turning tabs off restores the single calendar notch. Click the active tab
or press Escape to close the drawer. Pin keeps it open when you switch apps.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Left / Right | Previous / next month |
| Space | Today |
| Command-1 / Command-2 | Calendar / To-do (shared tabs enabled) |
| Command-N | New calendar event |
| Command-comma | Settings |
| Command-Shift-T | Go to date |
| P | Toggle pin |
| Escape | Close drawer |

## Build

Use Xcode 27.2 or later to build **Bar-cal.app**.

```sh
cp Local.xcconfig.example Local.xcconfig
./script/build_and_run.sh --verify
```

Signing configuration stays in the ignored `Local.xcconfig`. See
[BUILD.md](BUILD.md) for validation and release packaging.

## License and credits

MIT licensed. Copyright notices are retained in [LICENSE.txt](LICENSE.txt).
Bundled third-party notices are available in the app's acknowledgments.

Bar-cal's Slate icon and template mark are original ChatGPT-generated artwork;
source assets and prompts are in `Design/Generated/slate-production`.
Automatic updates are disabled; install new releases from this repository.
