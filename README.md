# WeshArenaAlerts

WeshArenaAlerts is an arena-focused alert addon for **World of Warcraft: The Burning Crusade Classic Anniversary 2.5.6** (`Interface 20506`). Automatic combat logic is deliberately restricted to arena instances.

## Installation

1. Copy the `WeshArenaAlerts` folder into `World of Warcraft/_anniversary_/Interface/AddOns/` (use the TBC Anniversary client folder shown by your installation).
2. Confirm that **WeshArenaAlerts** is enabled on the character-selection AddOns screen.
3. Open the settings with `Esc -> Options -> AddOns -> WeshArenaAlerts` or `/waa`.

## Milestone 0.4

Version 0.4.0 adds the automatic **Enemy Scatter Shot Reaction Alert**. When a mapped enemy Hunter successfully uses Scatter Shot (`spellID 19503`), the existing red fullscreen overlay flashes immediately. `UNIT_SPELLCAST_SUCCEEDED` for `arena1` through `arena5` is the preferred low-latency source; `SPELL_CAST_SUCCESS` from the shared combat-log dispatcher is the fallback.

This is deliberately a reaction stimulus for abilities such as Shadowmeld or Shadow Word: Death. It does **not** wait for a Scatter Shot debuff or aura, and it does **not** require the Hunter to target the addon owner. A cast aimed at a teammate or pet still flashes, and a later miss or immune result does not retract the alert. Notifications from the UNIT and combat-log paths are merged per Hunter GUID within a 0.5-second deduplication window; this is not a Scatter Shot cooldown tracker.

The automatic detector is arena-only and accepts only a mapped arena opponent whose class is `HUNTER`. Disabling the addon or Scatter module clears detector state and the runtime flash. `Flash enabled` controls the visual without disabling cast detection. The Settings test alert remains available outside arenas and does not affect runtime deduplication.

## Earlier automatic alerts

The **Enemy Drinking** detector from Milestone 0.3 remains available. While the arena runtime is active, `UNIT_AURA` scans the helpful auras of mapped `arena1` through `arena5` units and shows the existing `DRINKING!!!` alert only on a real not-drinking-to-drinking transition. Combat-log aura events provide a secondary fallback through the same duplicate-safe state API.

Drink recognition primarily compares the aura name with the client's localized canonical Drink spell name. A small, non-exhaustive set of known TBC Drink spell IDs is used only as a fallback, so detection is not tied to one rank or type of water. Multiple enemy GUIDs can be tracked simultaneously, and arena exit, opponent removal, or disabling the module clears runtime state.

The **Enemy Overpower Opportunity** module from Milestone 0.2 remains available with its 5-second reconstructed opportunity window. Inner Fire and Power Word: Shield absorb remain manual-preview-only modules.

Use `/waa debug` to toggle internal arena mapping and combat-log diagnostics before a test. Plain `/waa` continues to open Settings.

**Milestones 0.1-0.4 still require real validation in the TBC Anniversary 2.5.6 client.** In particular, an arena test must confirm whether `UNIT_SPELLCAST_SUCCEEDED` is exposed for enemy arena units and whether it arrives before `SPELL_CAST_SUCCESS` on this client build.
