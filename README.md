# WeshArenaAlerts

WeshArenaAlerts is an arena-focused alert addon for **World of Warcraft: The Burning Crusade Classic Anniversary 2.5.6** (`Interface 20506`). Automatic combat logic is deliberately restricted to arena instances.

## Installation

1. Copy the `WeshArenaAlerts` folder into `World of Warcraft/_anniversary_/Interface/AddOns/` (use the TBC Anniversary client folder shown by your installation).
2. Confirm that **WeshArenaAlerts** is enabled on the character-selection AddOns screen.
3. Open the settings with `Esc -> Options -> AddOns -> WeshArenaAlerts` or `/waa`.

## Milestone 0.3

Version 0.3.0 adds automatic **Enemy Drinking** detection. While the arena runtime is active, `UNIT_AURA` scans the helpful auras of mapped `arena1` through `arena5` units and shows the existing `DRINKING!!!` alert only on a real not-drinking-to-drinking transition. Combat-log aura events provide a secondary fallback through the same duplicate-safe state API.

Drink recognition primarily compares the aura name with the client's localized canonical Drink spell name. A small, non-exhaustive set of known TBC Drink spell IDs is used only as a fallback, so detection is not tied to one rank or type of water. Multiple enemy GUIDs can be tracked simultaneously, and arena exit, opponent removal, or disabling the module clears runtime state.

The **Enemy Overpower Opportunity** module from Milestone 0.2 remains available with its 5-second reconstructed opportunity window. Scatter Shot, Inner Fire, and Power Word: Shield absorb remain manual-preview-only modules.

Use `/waa debug` to toggle internal arena mapping and combat-log diagnostics before a test. Plain `/waa` continues to open Settings.

**Milestones 0.1-0.3 require real validation in the TBC Anniversary 2.5.6 client.**
