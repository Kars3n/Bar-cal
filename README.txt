
Bar-cal

A quiet calendar for your Mac's menu bar or screen edge. Personal fork of Itsycal,
maintained at https://github.com/Kars3n/Bar-cal.

Workspace index: [PROJECTS.md](../../PROJECTS.md). Keep its Bar-cal entry
current when changing the project's purpose or location.

Design direction: compact, native, clean, and keyboard-first.
The default Slate theme uses graphite surfaces, silver two-bar app and
menu-bar marks, and periwinkle highlights. Change themes in Appearance.
Use the calendar on its own, or choose calendars and reminder lists
in Settings to show your agenda.

Screen-edge mode: Settings > General > Show calendar as > Screen-edge tab.
The tiny notch replaces the menu-bar item and opens the calendar as a drawer.
Its curved shoulders join the drawer's edge, and both slide together.
Click again or press Escape to close it; clicking away closes an unpinned drawer.
Drag collapsed tabs vertically to reposition them. Pull inward to reveal the
drawer continuously with the pointer. Release after pulling a quarter of its
width to finish opening, or push back to the edge to keep it closed.
When extended, dragging the notch moves the whole calendar and keeps it open;
release it to dock on the nearest side.
Its side, height, and display are remembered. Right-click the tab for Settings
or Quit. General settings can switch back to the menu-bar item at any time.

Optional shared tabs: Settings > General > Show Calendar & To-do tabs.
Slim text tabs share one drawer and keep the original 14-point notch depth.
To-do mirrors one Apple Reminders list, including tasks without due dates.
Choose the list in To-do; checking a task completes it in Reminders, with Undo.
Tasks sort by due date, priority, then title. Changes in Reminders refresh here.
Command-1 / Command-2 switch Calendar / To-do. Turning tabs off restores the
single calendar notch and keeps your chosen reminder list for next time.

Build, install, and open with ./script/build_and_run.sh after copying
Local.xcconfig.example to Local.xcconfig. Signing settings stay in
that ignored local file. The script runs /Applications/Bar-cal.app so
macOS 27 and Bartender can manage its menu-bar item reliably.
See BUILD.md for the development workflow.

Shortcuts while the calendar is open:
  Left / Right     Previous / next month
  Space            Today
  Command-N        New event
  Command-,        Settings
  Command-Shift-T  Go to date

Based on Itsycal by Sanjay Madan: https://github.com/sfsam/Itsycal
MIT licensed; retain LICENSE.txt and the notices in
Itsycal/ThirdPartyLicenses. The About panel opens the bundled notices.

Original Bar-cal artwork and the ChatGPT image-generation prompts are
saved in Design/Generated/slate-production; compiled app-icon artwork is
in Itsycal/AppIcon.icon and the template glyph is in the asset catalog.

Automatic updates are disabled. Download updates from GitHub Releases.
README.md describes the current public release; BUILD.md documents Xcode
archiving, Developer ID signing, notarization, and packaging.
The original make_zips_and_appcast.sh remains an upstream reference.
