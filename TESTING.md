# Testing checklist

Things only the live client can confirm. Work down the list; anything that fails
is a bug worth reporting with the debug output from `/rmf debug` plus a `/rmf list`.

## Load

- [ ] Addon appears in the addon list, enabled, no "out of date" marker.
- [ ] No Lua error on login.
- [ ] Chat shows `RemindMeForever v0.1.0 loaded. /rmf opens the window.`

## Window

- [ ] `/rmf` opens it; `/rmf` again closes it.
- [ ] Escape closes it.
- [ ] Dragging the title bar moves it; the position survives a `/reload`.
- [ ] Close X works.
- [ ] Window is fully on screen at a small UI scale and a large one.

## Creating reminders

- [ ] Type a message, leave Condition on Everyone, Interval Daily, press Create.
      Row appears with "Everyone" and "Daily".
- [ ] Popup fires immediately with the message (a new reminder is owed at once).
- [ ] Create a reminder with `Condition = Level`, `Operation = >=`, Value `1`.
      It appears and fires.
- [ ] Switch Condition to Profession: the value control becomes a dropdown of
      professions, and the operation dropdown narrows to Equals / Not Equals.
- [ ] Switch Condition to Group: the value becomes a yes/no dropdown.
- [ ] Switch Condition to Everyone: the operation and value controls disappear.
- [ ] Set Interval to Weekly: a day dropdown appears.
- [ ] Set Interval to Weekly (time): day and time fields appear; enter `15:00`.
- [ ] Set Interval to Every N: it saves and repeats.
- [ ] Press Create with an empty message: red chat error, nothing saved.
- [ ] Create the same reminder twice: second is refused.
- [ ] Every dropdown opens, lists options, and closes when you click elsewhere.

## Row actions

- [ ] Unchecking a row's checkbox disables it; it stops firing.
- [ ] Re-checking re-enables it and it fires again.
- [ ] Clicking a row loads it into the form; Save updates it in place.
- [ ] Deleting a row asks for confirmation first.
- [ ] Cancel on a delete leaves the reminder alone.
- [ ] The X on a row is clearly visible and clickable.

## Popup

- [ ] Snooze hides the row and the reminder comes back after the snooze length.
- [ ] Dismiss hides the row and the reminder does not come back until the next
      occurrence.
- [ ] Several reminders due at once appear in one popup, not several.
- [ ] Popup does not appear while you are in combat; it appears once combat ends.

## Cross-character

- [ ] With a second character that matches the condition, enable "Also remind on
      my other characters".
- [ ] The alt's chore shows on your main as `(Altname) message`.
- [ ] Dismissing the alt's row silences it, and it stays silent across `/reload`.
- [ ] Playing the alt and dismissing there clears it properly.
- [ ] Snoozing the alt's row from your main delays it rather than clearing it.

## Reset times

- [ ] `/rmf opts` shows the detected reset hour and weekday.
- [ ] Tick "Set the reset hour myself", set an hour, and a daily reminder honours
      it (test by setting it a few minutes ahead).
- [ ] Weekly reminders land on the configured day.

## Persistence

- [ ] `/reload` keeps every reminder, its schedule, and the window position.
- [ ] Logging out and back in keeps them.
- [ ] Logging into a different character keeps them and shows that character's
      own pending state.

## Reporting

If something breaks, run `/rmf debug`, reproduce it, then `/rmf list` and copy the
chat output. Note your client build from `/run print(GetBuildInfo())`.
