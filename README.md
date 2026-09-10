# WeshArenaAlerts

WeshArenaAlerts is an arena-focused alert addon for **World of Warcraft: The Burning Crusade Classic Anniversary 2.5.6** (`Interface 20506`). Automatic combat logic is deliberately restricted to arena instances.

## Installation

1. Copy the `WeshArenaAlerts` folder into `World of Warcraft/_anniversary_/Interface/AddOns/` (use the TBC Anniversary client folder shown by your installation).
2. Confirm that **WeshArenaAlerts** is enabled on the character-selection AddOns screen.
3. Open the settings with `Esc -> Options -> AddOns -> WeshArenaAlerts` or `/waa`.

## Milestone 0.2

Version 0.2.0 adds the first automatic arena module: **Enemy Overpower Opportunity**. It starts a 5-second warning only when the addon owner dodges an attack from a Warrior whose GUID is mapped to a current arena opponent. The single visual alert displays the active opportunity with the greatest remaining time when more than one enemy Warrior is tracked.

The automatic detector runs only while the arena runtime is active. Drinking, Scatter Shot, Inner Fire, and Power Word: Shield absorb remain manual-preview-only modules. The reconstructed 5-second reactive opportunity window still requires validation in the live game.

Use `/waa debug` to toggle internal arena mapping and combat-log diagnostics before a test. Plain `/waa` continues to open Settings.

**Milestones 0.1 and 0.2 still require real testing in the TBC Anniversary client.**
