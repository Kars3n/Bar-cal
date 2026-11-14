# Bar-cal v1.0.0

First Bar-cal release, based on Itsycal with an original Slate identity and a
native screen-edge drawer.

- Choose a menu-bar calendar or a slim notch on either screen edge.
- Enable adjacent Cal and To-do text tabs in one shared drawer.
- Mirror an Apple Reminders list, including tasks without due dates, and
  complete reminders with undo support.
- Pull collapsed tabs inward to reveal the live content. Vertical dragging
  repositions tabs; dragging an open drawer docks it to the nearest edge.
- Native keyboard controls, pinning, calendar sizes, and four appearances.
- Original Slate app icon and menu-bar mark, with upstream and third-party
  license acknowledgments retained.

Requires macOS 27 or later on Apple silicon. Move Bar-cal.app to Applications
before opening it. General settings control the edge drawer and optional tabs;
choose a reminder list inside To-do. Automatic updates are disabled.

The app was archived with Xcode 27.2, signed with Developer ID Application,
notarized by Apple, and verified by Gatekeeper. The notarization ticket is
stapled to the app. `SHA256SUMS.txt` verifies the downloadable ZIP.

Validation: native drawer/list checks, focused geometry and animation checks,
and To-do completion/list-state tests pass. Reminder completion was validated
with fixtures without modifying personal reminders.
