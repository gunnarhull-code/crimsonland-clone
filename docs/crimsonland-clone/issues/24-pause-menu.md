Type: grilling
Status: implemented

## Question

New ticket, opened directly from playtesting (per map.md's Frontier status allowing reopening):

> "Okay, I want a super basic menu that lets you press escape to open it instead of the quit. And then I want you to have a quit button and resume button. And a reset progress button."

Escape previously quit the game immediately (`QuitHandler.gd`, added earlier this session per a direct request for an Escape-to-quit shortcut) - this replaces that with an actual pause menu, one of whose options is the same quit action.

## Answer

**New `PauseMenu.tscn`/`.gd`**, same UI pattern as `LevelUpChoice`/`ResultsScreen`/`UpgradeShop` (a `Control` with a `Dim` background and a `PanelContainer`), but `process_mode = PROCESS_MODE_ALWAYS` and listening for Escape itself via `_unhandled_input()` rather than being opened by another screen's signal - it needs to work from a cold start, not just when something else is already showing. `QuitHandler.gd` (and its Autoload registration) is deleted; its one job is now the Quit button here.

**Three buttons**, exactly as asked:
- **Resume** - un-pauses and hides the menu. Escape itself also resumes if the menu is already open (a toggle, not just an open-only key).
- **Quit** - `get_tree().quit()`, the same action `QuitHandler` used to perform directly on Escape.
- **Reset Progress** - wipes `SaveManager`'s persisted state (Banked Score, unlocked weapon upgrades, unlocked permanent Perks, highest wave reached) back to a fresh save's defaults via a new `SaveManager.reset_progress()`. Since this is irreversible and destroys real progress, it needs a second click to confirm (button text flips to "Click again to confirm" on the first click, arming a one-shot confirmation that resets if the menu is closed and reopened) rather than firing on a single click.

**Doesn't open over the other modal screens**: if `ResultsScreen`, `UpgradeShop`, or `LevelUpChoice` is currently visible, Escape does nothing - those already have their own paused, modal flow, and stacking a second pause panel on top would be confusing for a "super basic" menu that isn't trying to solve that interaction.

**Verified headlessly** with temporary instrumentation (removed before committing): simulating an Escape key event opens the menu and pauses the tree; a second Escape resumes and un-pauses; one click on Reset Progress leaves Banked Score untouched and changes the button's text; a second click actually zeroes it out and clears the unlocked upgrade set.

**Caught during that verification**: the test itself called `SaveManager.reset_progress()` directly against the live Autoload to confirm it worked, which wrote to the *same* `user://save.json` the user's own play sessions use - it briefly wiped their real progress before being restored from values visible earlier in the conversation. Recorded as a hard rule in this project's memory: never exercise a save-mutating `SaveManager` method against the live singleton during a debug/test harness again.
