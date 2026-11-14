### Local Development

After configuring `Local.xcconfig`, run `./script/build_and_run.sh` to
build the Itsycal scheme and open `Bar-cal.app`. The Codex Run action uses
the same script. It installs the development build at
`/Applications/Bar-cal.app` and launches that copy so macOS 27 and Bartender
can manage its menu-bar item. `--verify` checks that the built app stays running;
`--debug`, `--logs`, and `--telemetry` provide debugging entry points.

The script uses `/Applications/Xcode.app` by default and accepts an
existing `DEVELOPER_DIR` override. Build products go in the user's
temporary directory; the runnable copy lives in Applications. The app uses
Slate by default, with other themes available in Appearance settings.

General settings offer a menu-bar item or a screen-edge tab. Edge mode uses
a separate nonactivating handle panel and the existing calendar window as a
drawer; it preserves calendar selections, shortcuts, and pin behavior.
Placement is saved per chosen display, with a fallback when it is disconnected.
Expanded dragging moves the live calendar window and preserves its notch anchor
on drop. Input uses each mouse event's recorded global position, so queued events
cannot turn a drag into a click. The geometry checks include drag/drop anchoring.
An inward drag from a collapsed tab switches to an interactive reveal. The
shared content layer follows pointer displacement, clipped to its display.
The original tab window stays aligned over the live tabs until mouse-up to
preserve AppKit input capture. Release settles open beyond one-quarter reveal,
or closed below it. Vertical-only drags retain collapsed repositioning.

Run the focused screen-edge placement checks with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun clang -fobjc-arc -framework Cocoa -I Itsycal script/test_edge_geometry.m -o /tmp/barcal-test-edge-geometry
/tmp/barcal-test-edge-geometry
```

The expanded calendar and notch share one clipped content layer. A Core
Animation translation reveals it inside a stationary window, avoiding per-frame
window movement and layout. The hidden-window motion regression checks cover
fresh opens, immediate reversal, cancellation, and reduced motion:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun clang -fobjc-arc -framework Cocoa -framework QuartzCore -I Itsycal script/test_edge_motion.m Itsycal/ItsycalWindow.m -o /tmp/barcal-test-edge-motion
/tmp/barcal-test-edge-motion
```

The optional Calendar/To-do strip uses two 14 × 50 point text tabs in the same
drawer. General settings controls the strip; the To-do page stores one reminder
list identifier independently of the calendar agenda's selected calendars.
EventCenter fetches incomplete reminders, including undated current occurrences,
and reuses the existing completion/recurrence/undo path. A generation check
rejects old responses after changing lists. The selected page, list, and tab
setting persist. Reminder titles and identifiers are not written to app logs.

Run the To-do panel regression checks (test doubles, no real reminder access or
writes, and no visible window) with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun clang -fobjc-arc -framework Cocoa -framework EventKit -I Itsycal -I Itsycal/MoCode script/test_todo_panel.m Itsycal/TodoViewController.m Itsycal/EventCenter.m Itsycal/ReminderRecurrence.m Itsycal/MoCode/MoDate.m Itsycal/Itsycal.m Itsycal/Sizer.m -o /tmp/barcal-test-todo
/tmp/barcal-test-todo
```

### Code Signing

This project uses a Local.xcconfig file to handle code signing so that signing info stays out of the repo (`project.pbxproj`). Copy `Local.xcconfig.example` to `Local.xcconfig`. You can leave the defaults for local development. See the comments in the file for more info.

```
cp Local.xcconfig.example Local.xcconfig
```

### Release archive and notarization

Set the marketing version and build number in the Xcode project before making
a release. Configure your developer team in the ignored `Local.xcconfig` and
sign in to Xcode with an account eligible for Developer ID distribution.

```sh
./script/package_release.sh 1.0.0
```

The script creates a Release `.xcarchive` with hardened runtime, signs the nested
Sparkle helper from the inside out, then uses Xcode's Developer ID upload flow.
Xcode can use managed cloud signing through the signed-in developer account;
a local Developer ID private key is not required for that flow. Signing
credentials, archive metadata, and build output stay in ignored local files.

Apple processing may continue after the upload finishes. If exporting reports
that notarization is not finished, keep the archive and rerun only the export:

```sh
./script/package_release.sh 1.0.0 --export-notarized
```

The export is checked for a Developer ID Application signature, a valid stapled
notarization ticket, and Gatekeeper acceptance before packaging. Outputs are
`dist/Bar-cal-1.0.0-macOS-arm64.dmg`, `dist/Bar-cal-1.0.0-macOS-arm64.zip`, and
`dist/SHA256SUMS.txt`. The archive remains at `dist/Bar-cal-1.0.0.xcarchive` and
can be opened in Xcode Organizer.

To create only the DMG from an existing signed, notarized export:

```sh
./script/package_dmg.sh 1.0.0
```

The disk image includes the app and an Applications shortcut. Packaging verifies
the image's integrity, mounts it read-only, and checks the contained app's code
signature, stapled notarization ticket, and Gatekeeper acceptance.

Release requirements: Xcode 27.2+, macOS 27+, Apple silicon. Automatic updates
remain disabled. `make_zips_and_appcast.sh` is an upstream reference and is not
the Bar-cal release workflow.

### Resources

[Notarizing Your App Before Distribution](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution?language=objc)

[Customizing the Notarization Workflow](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/customizing_the_notarization_workflow?language=objc)

[Resolving Common Notarization Issues](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/resolving_common_notarization_issues?language=objc)

