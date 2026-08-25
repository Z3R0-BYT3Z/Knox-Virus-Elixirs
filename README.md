# Knox Virus Elixirs

A lightweight Project Zomboid Build 42 mod that adds two configurable emergency treatments for single-player and multiplayer:

- **Experimental Knox Cure** — removes the Knox infection when its configurable effectiveness roll succeeds, with four selectable treatment scopes.
- **Adrenaline Stimulant** — restores endurance and optionally clears fatigue.

The cure integrates with **Antibodies v1.97** when it is installed. Antibodies remains the condition-based recovery path, while the Experimental Knox Cure provides a rare configurable alternative.

## Features

- Native Build 42 `craftRecipe` formatting
- Build 42 versioned mod structure
- Optional Antibodies v1.97 integration
- Configurable crafting availability
- Configurable cure effectiveness and treatment scope
- Optional one-successful-cure-per-character limit
- Persistent per-character cooldowns
- Configurable stamina restoration
- Optional fatigue removal
- Delayed fatigue crash and safe repeated-use overdose damage
- Server-authoritative multiplayer treatment results
- One vanilla bottle-drinking consumption path with exact item-ID validation
- Protocol-v3 compatibility handshake with automatic retry
- Server-only, idempotent rare-loot registration
- Localized treatment announcements with spam cooldown
- Server-console usage logging
- English localization
- Custom inventory icons and Workshop artwork
- No overrides of vanilla or Antibodies files

## Compatibility

| Component | Status |
|---|---|
| Project Zomboid Build 42.20 | Supported |
| Single-player | Supported |
| Multiplayer | Supported; server-authoritative validation |
| Antibodies v1.97 | Optional integration |
| Survivor League / Meeks Protocol | Separate namespace; no file overrides |

Antibodies is available at [Steam Workshop item 2392676812](https://steamcommunity.com/sharedfiles/filedetails/?id=2392676812).

The add-on calls Antibodies' own cure routine when its module is available. If Antibodies is absent, it uses the native Project Zomboid infection fields.

## Item IDs

```text
ElixirCraft.KnoxCure
ElixirCraft.StaminaElixir
```

Admin examples:

```text
additem "Username" "ElixirCraft.KnoxCure" 1
additem "Username" "ElixirCraft.StaminaElixir" 1
```

## Recipes

### Experimental Knox Cure

- 0.5 L water in a water bottle or white mug
- 5 Plantain
- 5 Ginseng
- 1 Antibiotics

### Adrenaline Stimulant

- 0.5 L water in a water bottle or white mug
- 5 Ginseng

The water is consumed while the container is retained.

## Sandbox settings

- Enable Experimental Knox Cure
- Allow players to craft the Knox Cure
- Knox Cure minimum First Aid level
- Consume cure when treatment fails
- Cure treatment scope: infection only; infection and bites; all wounds and infection; or full restoration
- Cure effectiveness percentage
- Optional one successful cure per character
- Knox Cure cooldown in in-game hours
- Enable Adrenaline Stimulant
- Allow players to craft the Adrenaline Stimulant
- Adrenaline minimum First Aid level
- Adrenaline endurance restoration percentage
- Remove fatigue after stimulant use
- Stimulant duration, delayed fatigue crash, and crash severity
- Overdose window and non-lethal health loss
- Return rejected stimulant
- Panic, stress, and thirst side effects
- Adrenaline cooldown in in-game hours
- Optional Antibodies integration
- Medical loot locations and spawn chances
- Admin-only crafting and treatment-use announcements
- Treatment-use announcement cooldown
- Usage and diagnostic logging

Disable cure crafting to reserve it for administrators, Survivor League rewards, events, or server vendors.

## Local installation

Copy `src` as an `ElixirCraftB42` directory under the local mods directory:

```text
%USERPROFILE%\Zomboid\mods\ElixirCraftB42\42\mod.info
%USERPROFILE%\Zomboid\mods\ElixirCraftB42\common\media\...
```

Alternatively, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-release.ps1
```

Then extract `dist\ElixirCraftB42-v1.5.2.zip` into `%USERPROFILE%\Zomboid\mods`.

## Steam Workshop package

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-workshop.ps1
```

This creates:

```text
dist\ElixirCraftB42-Workshop\
├── workshop.txt
├── preview.png
└── Contents\mods\ElixirCraftB42\
```

Copy `ElixirCraftB42-Workshop` into `%USERPROFILE%\Zomboid\Workshop`, launch Project Zomboid, and open **Workshop → Create and update items**.

After Steam assigns an ID, preserve the generated `id=` value in your private upload workspace. Do not commit a personal Workshop ID to a community fork unless that fork owns the corresponding Workshop item.

## Dedicated server

After publication, configure the server with both Workshop IDs and Mod IDs:

```ini
WorkshopItems=2392676812;ELIXIR_WORKSHOP_ID
Mods=lgd_antibodies;ElixirCraftB42
```

Antibodies is optional at the code level. Remove its Workshop and Mod IDs if the server does not use it.

## Repository structure

```text
src/                 Editable Project Zomboid mod
tools/               PowerShell release builders
workshop/            Workshop metadata template and preview
CHANGELOG.md          Version history
CONTRIBUTING.md       Contribution and testing guidance
LICENSE               MIT License
```

## Testing

Before publishing a stable release, verify:

1. Both items load without World Dictionary errors.
2. Both recipes appear and consume the correct ingredients.
3. Each cure scope changes only its documented infection, bite, wound, or full-health fields.
4. Antibodies no longer reports an active infection after the cure.
5. Cooldowns survive relogging and reconnecting.
6. Sandbox settings appear in hosted and dedicated-server configuration.
7. A remote multiplayer client receives the same results as the host.
8. Normal inventory consumption plays the bottle-drinking animation and submits one treatment request containing the consumed item's ID.
9. A mismatched client receives the localized version warning and cannot submit treatment commands.
10. Admin-only crafting hides/rejects both recipes for a normal player and permits a valid administrator.
11. Cure effectiveness failures obey the configured item-return rule, and the returned item is confirmed in its original container.
12. A second successful cure is rejected only when the one-cure limit is enabled for that character.
13. Repeated stimulant use cannot lower overall health below one.
14. Private/global announcements render localized treatment names and respect their cooldown.
15. Loot rolls occur once on the server and never from a client Lua context.
16. `console.txt` contains no Lua exceptions or repeated warnings.

The repository does not include Project Zomboid's timed-action implementation, so v1.5.2 deliberately keeps the verified vanilla `Food`/`EatType` animation hook. Treatment is granted only when the server can locate the submitted item ID and matching full type. Test this transaction on the target Build 42 server before public deployment; an unresolved or already-missing item is rejected without granting an effect.

Please attach relevant `console.txt` excerpts and reproduction steps to bug reports.

## Credits

- Developed for the Meeks Protocol Project Zomboid server.
- Antibodies compatibility targets the open-source work by lonegamedev.
- Project Zomboid is developed by The Indie Stone.

This project does not redistribute Antibodies or Project Zomboid assets.

## License

Released under the [MIT License](LICENSE).
