# RemindMeForever

Reminders for **World of Warcraft: Forever** — the Classic+ client (1.60.1,
interface `16001`). Set a message, say which characters it applies to, choose how
often it repeats, and it pops up when it is due.

A spiritual port of [Reminders](https://github.com/pcg79/Reminders-Addon) by
pcg79, rebuilt for Forever's client. Forever shares Mainline's UI architecture,
so this is written against the modern API rather than Classic Era's.

## What it does

You define a reminder with three things:

- **a message** — what to nag you about ("Craft Living Steel", "Do the Molten Core
  attunement")
- **a condition** — which characters it applies to (`profession = Alchemy`,
  `level >= 60`, `name = Bob`, or `*` for everyone)
- **a schedule** — daily at reset, weekly on a chosen day, weekly at a specific
  day and time, or every N hours

When you log in or reload, anything due pops up. Each row has **Snooze** and
**Dismiss**.

## Conditions

Conditions are a small language, not free-form code. Keywords are
case-insensitive.

| Field | Kind | Operators | Example |
|---|---|---|---|
| `name` | text | `=`, `~=` | `name = Tester` |
| `class` | text | `=`, `~=` | `class = Druid` |
| `race` | text | `=`, `~=` | `race = Gnome` |
| `guild` | text | `=`, `~=` | `guild = "Iron Forge Regulars"` |
| `faction` | text | `=`, `~=` | `faction = Alliance` |
| `zone` | text | `=`, `~=` | `zone = "Elwynn Forest"` |
| `profession` | list | `=`, `~=` | `profession = Alchemy` |
| `level` | number | `=`, `~=`, `<`, `<=`, `>`, `>=` | `level >= 60` |
| `ilevel` | number | `=`, `~=`, `<`, `<=`, `>`, `>=` | `ilevel > 60` |
| `gold` | number | `=`, `~=`, `<`, `<=`, `>`, `>=` | `gold < 100` |
| `group` | yes/no | `=`, `~=` | `group = yes` |
| `instance` | yes/no | `=`, `~=` | `instance = no` |

Combine them with `and` / `or`. `and` binds tighter than `or`, so

```
class = Priest and level >= 60 or name = Altpriest
```

means `(class = Priest and level >= 60) or name = Altpriest`.

`*` on its own means everyone.

**Values containing spaces must be quoted** — `zone = "Stormwind City"`, not
`zone = Stormwind City`. An unquoted multi-word value is reported as an error
rather than silently truncated to its first word.

There are no parentheses. If you need grouping, write it without them or use two
reminders.

## Schedules

| Interval | Runs |
|---|---|
| Daily | once per day at the reset hour |
| Weekly | once a week on the reset day, at the reset hour |
| Weekly (time) | once a week on a day and time you pick |
| Every N | every N minutes or hours, counted from when it last fired |

### Reset times

Out of the box the addon asks the client for the reset boundary
(`C_DateAndTime.GetSecondsUntilDailyReset`) and uses the hour and weekday it
reports.

If your realm's reset does not match, open `/rmf opts` and tick **Set the reset
hour myself**, then enter the hour (server time, 0–23) and the weekly reset day.
Manual values are used for every daily/weekly reminder from then on.

All schedule math runs in UTC epoch seconds, so your local timezone never shifts a
reset.

## Cross-character reminders

Tick **Also remind on my other characters** and the reminder also surfaces for any
other character on the account that matches its condition, shown as
`(Altname) message`. That way you can see which alts still owe a chore without
logging into each one.

Dismissing an alt's row only silences it until the reminder comes due again — it
does not clear the alt's schedule. Actually playing that character is what clears
it. Snoozing pushes out that character's own timer.

This needs the addon to have seen each character at least once, since the
attributes it checks (level, class, professions) are cached when you log in.

## Commands

```
/rmf                  open or close the window
/rmf opts             options (reset times, snooze length, debug)
/rmf list             print every reminder with its id
/rmf eval             check everything now
/rmf test <id>        fire one reminder immediately
/rmf on|off <id>      enable or disable without deleting
/rmf reset <id>       make this character owe it again
/rmf delete <id>      delete one reminder
/rmf debug            toggle debug output
/rmf wipe             delete everything (asks first)
```

`/remindmeforever` works too.

## Install

1. Find your Forever install folder — Battle.net → WoW Forever → **Show in
   Explorer**. It is `_forever_` inside the WoW directory.
2. Copy the `RemindMeForever` folder into `_forever_\Interface\AddOns\`.
3. Restart the client (a `/reload` is not enough the first time, since a new
   folder has to be scanned).

The final layout is:

```
_forever_\Interface\AddOns\RemindMeForever\RemindMeForever.toc
_forever_\Interface\AddOns\RemindMeForever\Core.lua
...
```

## Design notes

- **No embedded libraries.** The UI is built on stock frames. Nothing to keep
  up to date, no third-party code, no Ace3 churn.
- **No `loadstring`.** The original built a Lua string from the condition text
  and executed it. This parses into a tree instead, so a bad condition is an
  error message rather than arbitrary execution or a silent no-op.
- **Secret values.** Forever inherits Midnight's secret-value system: in some
  contexts unit APIs return values you may store but not compare. Every client
  read goes through `ns.SafeValue`, so a restricted value degrades to "unknown"
  instead of throwing.
- **One ticker, not one timer per reminder.** Fewer moving parts, and schedules
  survive `/reload` without repair.
- **Account-wide definitions, per-character schedules.** Kept from the original
  because it is what makes cross-character nagging work.

## Development

The logic layer is plain Lua 5.1 and runs under a stock interpreter with the WoW
API stubbed out:

```sh
lua5.1 tests/run.lua        # conditions, schedules, reminder model
lua5.1 tests/ui_smoke.lua   # every window constructed, editor driven end to end
```

The smoke test proves the UI code does not throw; it cannot prove the window
looks right. Only the client can do that.

Build a distributable zip:

```sh
./build.sh
```

## License

GPL-3.0, matching the original addon. See `LICENSE`.

## Credits

Original **Reminders** addon by pcg79 (GPL-3.0). Condition language, scheduling
model and cross-character behaviour are inspired by it; the implementation,
parser and UI are new.
