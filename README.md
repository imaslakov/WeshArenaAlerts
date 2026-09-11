# WeshArenaAlerts

WeshArenaAlerts is an arena-focused alert addon for **World of Warcraft: The Burning Crusade Classic Anniversary 2.5.6** (`Interface 20506`). Automatic combat logic is deliberately restricted to arena instances.

## Installation

1. Copy the `WeshArenaAlerts` folder into `World of Warcraft/_anniversary_/Interface/AddOns/` (use the TBC Anniversary client folder shown by your installation).
2. Confirm that **WeshArenaAlerts** is enabled on the character-selection AddOns screen.
3. Open the settings with `Esc -> Options -> AddOns -> WeshArenaAlerts` or `/waa`.

## Milestone 0.7

Version 0.7.0 adds **Self Power Word: Shield Remaining Absorb**. The automatic module runs only in arenas and only for the addon owner when `UnitClass("player")` reports `PRIEST`. It recognizes every normal TBC player rank (`17`, `592`, `600`, `3747`, `6065`, `6066`, `10898`, `10899`, `10900`, `10901`, `25217`, and `25218`) and never activates for a teammate, enemy, unrelated buff, or noncanonical shield spell.

The state machine is `ABSENT` (no self PW:S, frame hidden), `KNOWN` (PW:S present with an available remaining amount), and `UNKNOWN` (PW:S present but no safely usable amount, displayed as `?`). `UNIT_AURA("player")` handles apply, recast, dispel, and removal; `UNIT_ABSORB_AMOUNT_CHANGED("player")` rereads the source after damage. Arena start, `/reload` in an arena, and enabling the addon or module perform one initial scan. Arena exit and disabling either switch immediately clear state and hide the existing Shield Absorb frame. There is no polling, `OnUpdate`, tooltip parsing, combat-log reconstruction, or calculated maximum-shield formula.

The preferred source is `AuraData.points[1]` from a canonical PW:S aura returned by `C_UnitAuras.GetAuraDataByIndex`; legacy `UnitAura` remains the aura-detection fallback. `UnitGetTotalAbsorbs("player")` is consulted only after PW:S itself has been confirmed and only when the aura-specific amount is unavailable. This total fallback is explicitly lower confidence and can include other simultaneous absorb effects; the addon does not attempt to subtract unknown absorbs. If PW:S is absent, a positive total absorb from another effect never shows the frame.

Three live display styles are available: **Icon + Number**, **Bar + Number**, and **Icon + Bar**. All styles reuse the same movable Shield frame and saved position. The bar shows the current number and scales against the highest accessible API amount observed during the current aura instance; it does not calculate shield strength from spell rank, talents, healing power, or combat-log damage. After a `/reload` in the middle of an existing shield, the first observed remainder therefore starts at 100% until a higher value is observed. When legacy `UnitAura` provides no aura-instance ID, the observed peak resets only after PW:S disappears. The lower-confidence total-absorb fallback also means its bar can include other simultaneous absorbs.

Restricted PvP values are feature-detected through Blizzard's secret-value helpers. A secret amount bypasses comparisons, arithmetic, `math.floor`, short-number formatting, debug string conversion, and bar-ratio calculation. The addon first attempts to pass it directly to the Shield FontString; if the client rejects that operation, it safely changes to `UNKNOWN` and displays `?`. The bar uses a neutral empty fill while its ratio cannot be calculated safely. For accessible numbers, Exact and Short (`1847` → `1.8k`) formats, display style, icon size, and text size update live. Manual Preview remains available outside arenas and for non-Priests, and its timer cannot overwrite or hide a newer runtime state.

## Milestone 0.6

Version 0.6.0 adds **Class / Pet Icons over Nameplates**. While the arena runtime is active, a large class icon is anchored above each currently visible Blizzard nameplate whose unit GUID matches one of the mapped `arena1` through `arena5` opponent GUIDs and whose unit is not explicitly reported as non-player. Pet identity always takes priority over class identity: enemy pets matched through `arenapet1` through `arenapet5`, and friendly pets matched through `pet` or `partypet1` through `partypet4`, show that unit's own Blizzard portrait instead of an owner class icon. A player-controlled `Pet-*` GUID can safely use the visible `nameplateN` as a portrait fallback while a dedicated pet token is unavailable. A compact event-driven health bar appears immediately above every matched pet portrait. Totems, unrelated NPCs and players, and units without a supported player/pet identity do not receive icons.

The module supports all nine TBC player classes and uses the standard Blizzard class-icon sheet (`Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes`). It prefers the client's `CLASS_ICON_TCOORDS` and has local coordinates for the nine TBC classes as a compatibility fallback. Icon size, horizontal offset, vertical offset, and border visibility apply live and persist through the existing recursive SavedVariables merge.

Runtime visuals are non-interactive child frames anchored to the base nameplate (or its `UnitFrame` when available). They never enable mouse input, change Blizzard nameplate dimensions or regions, or create protected actions. `NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED` are the normal event-driven path; there is no periodic scan or `OnUpdate`. A small frame pool safely handles reused unit tokens, base nameplates, and anchor frames by replacing GUID, class/pet metadata, and texture state on every addition.

Arena mapping changes trigger a one-shot visible-nameplate refresh, covering nameplates that appeared before `ARENA_OPPONENT_UPDATE`; `UNIT_PET` similarly resolves an enemy or friendly pet token that becomes available after its nameplate. `UNIT_HEALTH` and `UNIT_MAXHEALTH` update pet bars without polling. Arena activation also refreshes plates already visible after `/reload`; arena exit and master/module disable immediately hide all icons and clear runtime associations. Settings includes a static Priest fake-nameplate preview that works outside arenas without creating runtime mappings.

Third-party nameplate compatibility (Plater, Threat Plates, Kui, ElvUI, and similar addons) awaits real in-game testing. The implementation only obtains the Blizzard base frame through `C_NamePlate` and anchors a child visual without modifying nameplate internals.

## Milestone 0.5

Version 0.5.0 adds the automatic **Self Inner Fire Maintenance Alert** for the addon owner when playing a Priest. It is active only inside arena instances and uses the player's actual helpful aura as its source of truth.

The module has three visual runtime states:

* `OK`: Inner Fire is present with more charges than the configured threshold; the warning is hidden.
* `LOW`: Inner Fire is present with charges at or below the threshold; the existing Inner Fire frame remains visible with a red overlay and, when enabled, the current remaining charge count.
* `MISSING`: Inner Fire is absent; the same frame remains visible with a red overlay and `MISSING` label, while the numeric count is always hidden.

The default low-charge threshold is `5`. Recasting Inner Fire with a normal charge count hides a `LOW` or `MISSING` warning immediately. Threshold, stack-count visibility, and icon-size changes apply live. Arena exit, master disable, and module disable clear the tracked state and hide the runtime warning; the Settings preview remains available outside arenas and for non-Priest characters.

All normal TBC player ranks (`588`, `7128`, `602`, `1006`, `10951`, `10952`, and `25431`) are recognized by spell ID. The primary detector is `C_UnitAuras.GetAuraDataByIndex`; `UnitAura` is the legacy fallback. Remaining charges come directly from AuraData `applications` or the legacy aura `count`. If a present Inner Fire aura has no valid count, the module records a present-count-unknown state and suppresses both false `LOW` and false `MISSING` warnings. It does not reconstruct charges from the combat log, timers, incoming hits, or spell cooldowns.

## Milestone 0.4

Version 0.4.0 adds the automatic **Enemy Scatter Shot Reaction Alert**. When a mapped enemy Hunter successfully uses Scatter Shot (`spellID 19503`), the existing red fullscreen overlay flashes immediately. `UNIT_SPELLCAST_SUCCEEDED` for `arena1` through `arena5` is the preferred low-latency source; `SPELL_CAST_SUCCESS` from the shared combat-log dispatcher is the fallback.

This is deliberately a reaction stimulus for abilities such as Shadowmeld or Shadow Word: Death. It does **not** wait for a Scatter Shot debuff or aura, and it does **not** require the Hunter to target the addon owner. A cast aimed at a teammate or pet still flashes, and a later miss or immune result does not retract the alert. Notifications from the UNIT and combat-log paths are merged per Hunter GUID within a 0.5-second deduplication window; this is not a Scatter Shot cooldown tracker.

The automatic detector is arena-only and accepts only a mapped arena opponent whose class is `HUNTER`. Disabling the addon or Scatter module clears detector state and the runtime flash. `Flash enabled` controls the visual without disabling cast detection. The Settings test alert remains available outside arenas and does not affect runtime deduplication.

## Earlier automatic alerts

The **Enemy Drinking** detector from Milestone 0.3 remains available. While the arena runtime is active, `UNIT_AURA` scans the helpful auras of mapped `arena1` through `arena5` units and shows the existing `DRINKING!!!` alert only on a real not-drinking-to-drinking transition. Combat-log aura events provide a secondary fallback through the same duplicate-safe state API.

Drink recognition primarily compares the aura name with the client's localized canonical Drink spell name. A small, non-exhaustive set of known TBC Drink spell IDs is used only as a fallback, so detection is not tied to one rank or type of water. Multiple enemy GUIDs can be tracked simultaneously, and arena exit, opponent removal, or disabling the module clears runtime state.

The **Enemy Overpower Opportunity** module from Milestone 0.2 remains available with its 5-second reconstructed opportunity window.

Use `/waa debug` to toggle internal arena mapping and combat-log diagnostics before a test. Plain `/waa` continues to open Settings.

**Milestones 0.1-0.7 require real validation in the TBC Anniversary 2.5.6 client.** In particular, an arena test must confirm which `AuraData.points` index contains the live Power Word: Shield remaining absorb, whether that value updates on every hit, whether `UNIT_ABSORB_AMOUNT_CHANGED("player")` fires during an active match, whether the amount becomes secret in restricted PvP, whether a FontString accepts that secret value directly, and how the total fallback behaves with multiple simultaneous absorbs. Existing validation also remains for the live Inner Fire aura payload (`applications`/legacy `count`), enemy `UNIT_SPELLCAST_SUCCEEDED`, Anniversary nameplate tokens and `C_NamePlate`, stock-nameplate anchor height, and third-party nameplate compatibility.
