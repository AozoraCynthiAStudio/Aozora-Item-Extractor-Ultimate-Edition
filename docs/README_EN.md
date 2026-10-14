# Aozora Item Extractor Ultimate Edition

**Aozora-styled UI · Keyboard, mouse & controller · Practical community-inspired features**

[Downloads](https://github.com/AozoraCynthiAStudio/Aozora-Item-Extractor-Ultimate-Edition/releases/latest) · [中文](../README.md) · [Build](BUILD.md)

A Fallout 4 item extractor with a consistent two-pane interface, plugin/item discovery, extraction and return actions, HUD theme colors, and optional mascot guidance. The current release is **v1.0.6**, addressing duplicate Chinese input, lingering search messages and input text alignment.

![Extraction menu](../发布物料/Extractor.png)

## Features

- Browse loaded ESM/ESP/ESL plugins; plugins with no extractable items are hidden.
- Search plugin filenames or item names to discover the owning plugin. Entering a result places the matching item at the top and protects initial focus until the mouse moves.
- Right pane: Take, Batch Extract, Take All. Left pane: Return, Batch Return, Return All.
- Keyboard/mouse and controller support, explicit search mode, and a Pip-Boy Aid launcher.
- Follow HUD colors or select one of six palettes. MCM can hide both the mascot and speech bubbles.
- Chinese overlay patch translates functional UI, MCM and launcher names; the AOZORA / ITEM EXTRACTOR header remains English.
- Weapons with base ammo grant starter ammunition. Ammo rows show a mascot tip containing the configured group size.

## Quantity rules

Normal extraction is **one configured group**, not always one individual item.

| Type | Default quantity per action | INI key |
|---|---:|---|
| Weapons | 1 | Weapon |
| Thrown weapons | 1 | Grenade |
| Armor | 1 | Armor |
| **Ammunition** | **100** | Ammo |
| Aid | 1 | Aid |
| Junk | 1 | Junk |
| Miscellaneous, books, notes, keys | 1 | Misc |

Configure these in `Data/F4SE/Plugins/AozoraItemExtractor.ini`.

- **Take / Return:** one group of the selected item; return is capped by the remaining returnable amount.
- **Batch:** quantities are actual item counts, **not group multipliers**. x10 ammo means ten rounds. Presets include 1/10/50/100/1000, adjusted for configured and returnable quantities.
- **Take All:** one group of every extractable item in the selected plugin, regardless of the current category filter. Large transfers are processed in batches.
- **Return All:** all currently returnable session items, regardless of category, including items taken from other plugin pages during the same menu session.

### Starter ammunition

Each weapon extraction action grants **one configured stack of base ammo** if the weapon has an ammo record. The default is 1000 rounds; adjust it in MCM or set it to 0 to disable. Taking multiple guns in one batch still grants only one stack. Weapons without base ammo receive none.

**Bonus ammo is not separately tracked in the extracted list and is not automatically removed when returning the weapon.** Explicitly extracted ammo remains subject to its own session return limits.

### Session return limits

The left pane is not the entire inventory. It shows session items that remain returnable. The first extraction of each item records its inventory baseline; return is capped by both the net extracted count and the inventory amount above that baseline. Consumed or discarded quantities may not be returnable.

Returning to the plugin browser preserves the session. Closing the whole menu ends it; extracted items remain in inventory, but reopening does not restore the previous return list.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Enter / Take / Return | E | A |
| Select rows | W/S or up/down | D-pad or left stick |
| Switch panes | A/D or left/right | D-pad or left stick |
| Switch categories | Z/C | **LT/RT** |
| Search in plugin browser | F or click | Y |
| Batch in extraction page | Q | Y |
| Take All / Return All | R | X |
| Back | Tab | B |
| Batch quantity | A/D or left/right | D-pad left/right |

## Installation

Requires Fallout 4, matching F4SE and Address Library, and the VC++ x64 runtime. MCM/F4MCM is optional.

Install the English core, enable ESL-flagged `AozoraItemExtractor.esp`, and launch via F4SE. Bind a hotkey in MCM or use the inventory Aid launcher. For Chinese, install the CHS Patch with higher file priority and disable old CHS_Name/CHS_Tips patches. Chinese-capable game fonts are required.

The code declares support for multiple OG/NG/AE runtimes; this is not a claim of testing every runtime or mod list. The user confirmed the v1.0.4 save fix and new MCM controls on AE. This does not establish a new full regression on every supported runtime.

## Source and credits

AS3: `src/as3`. Native CommonLibF4: `src/native`. Papyrus and runtime files: `Data`. MCM: `mcm`. Artwork: `assets`. Translations: `translations`. Build tools: `tools`.

Community influence is credited explicitly: [In-Game-Mod-Explorer](https://github.com/Perchik71/In-Game-Mod-Explorer) for plugin enumeration/ownership, portable item filtering and cache lifecycle ideas; Aozora Favorites for the related visual/input style; Barlow Condensed for header fonts.

[Non-Commercial Open License](../LICENSE.md) · [Third-party notices](../THIRD_PARTY_NOTICES.md).


## v1.0.4: save fix and extraction settings

I accidentally included experimental 3D preview code in the v1.0.3 DLL, causing a CTD when saving after visiting the extraction page. The code is excluded from release builds, and the build/package pipeline now checks for this mistake.

- Weapon bonus ammo: 0–1000 slider, step 100, default 1000; 0 disables it.
- Ammo per group: 1 / 10 / 50 / 100 / 500 / 1000 stepper, default 100.
- Custom INI quantities: `[ItemCount] Ammo` and `WeaponAmmo`. Changing the MCM selection overrides custom values and takes effect next time the menu opens. Merely opening MCM does not overwrite them.
- Clearer search input frame, background and typing hint. Tab and Enter finish input while preserving the query.


## v1.0.5: scrolling and Chinese input

Drag scrollbars or click their tracks to page through long lists. The controller right stick scrolls the focused list, keeping the selected row fully visible. Chinese Input (RIME) and NA Input Support have been tested successfully; requests for other input mods are welcome.
