# Changelog

All notable changes to RemindMeForever. This project follows
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-23

First version. Feature parity with the original Reminders addon's core, rebuilt
for the WoW Forever client, plus the additions below.

### Added

- Reminders with a message, a condition, and a schedule.
- Condition language over `name`, `class`, `race`, `guild`, `faction`, `zone`,
  `profession`, `level`, `ilevel`, `gold`, `group`, `instance`, joined with
  `and` / `or`, plus `*` for everyone.
- Schedules: daily at reset, weekly on the reset day, weekly on a chosen day and
  time, and every N minutes or hours.
- Manual reset-hour and reset-day override in the options, for realms whose reset
  does not match what the client reports.
- Cross-character reminders: an alt that still owes a chore shows up as
  `(Altname) message` on the character you are playing.
- Snooze and Dismiss per row; snooze length configurable per character.
- Enable/disable a reminder without deleting it.
- Popup groups everything due at login into one window.
- `/rmf` commands for list, eval, test, on/off, reset, delete, debug, wipe.
- Options window: reset times, snooze length, cross-character visibility, debug.
- Forever-themed UI: stone and gold, draggable, position remembered.

### Changed from the original addon

- Condition parsing is a real parser; no `loadstring`, and bad input reports an
  error instead of silently evaluating to nothing.
- Commas in messages and values are preserved (the original stripped them).
- `self`-style matching binds to the creating character rather than to whatever
  character happens to be logging in.
- Values containing spaces are supported when quoted.
- One shared ticker instead of a timer per reminder.
- No embedded libraries; the UI is built on stock frames.
- Re-enabling a disabled reminder re-arms it cleanly instead of leaving a stale
  schedule behind.

### Known limitations

- Text is English only.
- No parentheses in conditions; `and` binds tighter than `or`.
- Cross-character reminders only know attributes the addon has seen, so a
  character must have logged in at least once with the addon installed.
- Not tested against the live client yet; see the testing notes in the README.
