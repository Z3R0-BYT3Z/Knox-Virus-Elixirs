# Knox Virus Elixirs v1.6.2 — healing well test candidate

Adds Experimental Knox Cure, Adrenaline Stimulant and administrator-designated healing elixir wells to Project Zomboid Build 42.20. This candidate is based on GitHub commit `05350a3471bf18a9866e04b733b94f5e9df76c2e` of Z3R0-BYT3Z/Knox-Virus-Elixirs.

This package has passed static checks and mocked Lua 5.1 gameplay tests. It has NOT been run inside Project Zomboid. Test native timed-action serialization, animations, inventory synchronization and persistence on your target build before publishing.

## Healing well setup

1. Enable the mod and `Enable healing wells`. Restart after installing this candidate.
2. Log in with the actual `admin` access level (single-player permits the local player).
3. Stand next to an existing vanilla well, or place one with the game's admin/debug tools. Compatible static water sources may also be designated.
4. Right-click and choose **Admin: Create Healing Elixir Well**; wait for completion.
5. Players select **Healing Elixir Well → Drink Healing Elixir**.

Default behavior is **unlimited supply, guaranteed full health recovery, and no cooldown**. Each completed drink clears injuries, bites, wound infections and Knox infection, following the existing elixir's full-restoration path. The well does not inherit a bottle's effectiveness roll, cooldown, enabled flag, or one-cure limit, and it never changes bottle/stimulant cooldown timestamps. Existing saved well cooldown values are ignored.

No refill is needed. Refill and recharge controls are hidden in unlimited mode. Existing wells, even ones with zero saved charges, work after updating. The original charge pool is retained in case you explicitly select limited mode later.

The existing well sprite remains unchanged. There is no automatic well spawn or construction recipe. Ordinary water drinking/filling remains independent of healing. Administrator removal only removes the healing effect, not the physical water source.

## Well settings

| Setting | Default | Meaning |
|---|---:|---|
| EnableHealingWell | true | Enable the feature |
| WellUnlimitedSupply | true | Never deplete or require refills |
| WellFullRecovery | true | Guaranteed full elixir-scope health, wound, bite and infection recovery |
| WellActionTime | 120 | Base drinking time in game action ticks |

The former WellCooldownHours option was removed and old saved values are ignored. Players can start another drink immediately after the previous action finishes.

Optional limited/partial modes are retained: disable WellUnlimitedSupply to use the saved 20-capacity/5-initial-charge pool and donate cures for 5 charges each. Disable WellFullRecovery to use WellHealAmount (25), WellHealWounds (false), and WellCuresKnox (false). WellCuresKnox=true grants guaranteed full restoration independently of bottle eligibility. These optional modes also have no well cooldown.

Full recovery also clears hunger, thirst and fatigue, restores endurance to 100%, and replenishes calorie reserves to at least 2,500. Higher calorie reserves are retained and repeated drinks do not stack calories. It does not change weight or traits, trigger stimulant overdose/crash, or reset bottled treatment cooldowns. Antibodies integration still follows EnableAntibodiesIntegration.

## Bottled treatments

Right-click a bottle in your own inventory and select **Use Experimental Knox Cure** or **Use Adrenaline Stimulant**. Items in your carried bags are supported. The full dose is used only when the native timed action completes. Cancelling an action consumes nothing.

The original `ElixirCraft.KnoxCure` and `ElixirCraft.StaminaElixir` item IDs and Food save classes remain unchanged. `CantEat=TRUE` hides ordinary food consumption; there are no OnEat treatment callbacks. No vanilla timed-action file is overridden.

Default rejections keep the bottle. `ConsumeCureOnFailedUse=true` consumes a rejected/ineffective cure. `ReturnRejectedStimulant=false` consumes a rejected stimulant. A treatment exception does not refund an item or charge because effects may already have partially changed; the error is logged for an administrator to investigate.

The original craftRecipe ingredients, optional Antibodies integration, cure scopes, stamina effects, one-cure policy, loot settings and existing state keys remain in use. Administrator-only crafting now means the exact `admin` access level; moderators do not qualify.

## Multiplayer and persistence

Protocol 4 replaces protocol 3. Every client and the server must update together and reconnect. Old instant UseTreatment commands are rejected without applying effects.

Actions use the B42 shared ISBaseTimedAction pattern: client perform() only advances its queue, server/single-player complete() validates and changes gameplay state. Object proximity, Z level, blocked/window access, limited-mode charge counts, item ownership and admin privileges are checked before a well transaction. Durations are calculated from server settings, not constructor-supplied timing.

Authoritative well records live in global ModData under `ElixirCraftB42WellRegistry`; object modData contains only a display copy. Changing that display copy cannot replenish the server's charges. Wells have no character cooldown; old `ElixirCraftB42.lastWellUse` values are ignored. Native saved-world behavior must be checked in-game; mocked module reload is not a real server restart test.

A designated well is tied to its saved object marker, coordinates and sprite. If you move a well, remove the healing effect before moving it, then designate it at its new location. Capacities are set when designated, so changing WellCapacity does not resize existing wells.

## Installation and packaging

Local mods folder:

```text
%USERPROFILE%\Zomboid\mods\ElixirCraftB42\42\mod.info
%USERPROFILE%\Zomboid\mods\ElixirCraftB42\common\media\...
```

Dedicated server retains:

```ini
WorkshopItems=3785221351
Mods=ElixirCraftB42
```

Append these to your existing lists; do not replace your other mods. Optional Antibodies retains Workshop ID 2392676812 and mod ID lgd_antibodies.

`tools/build-release.ps1` builds the local-install archive. `tools/build-workshop.ps1` builds a Workshop workspace whose template intentionally retains id=0 for generic source use. For YOUR existing item, set id=3785221351 in the private upload workspace or replace only its Contents/mods/ElixirCraftB42 files. The provided prepared bundle has the existing ID set. Do not use a create-new-item flow to update your existing item.

## Validation

```sh
python3 -m pip install lupa
python3 tools/test_logic.py
python3 tools/audit_mod.py
```

The mocked suite covers final-charge contention, cooldowns, marker forgery, ownership, caps, disabled features, admin permissions, optional cure policy, cancellation, duplicate completion, failed-use refund policy, single-player handling, split-screen routing and menu callbacks. See TEST_PLAN.md for required in-game checks.

MIT license; authored for Meeks Protocol. No game Lua, Antibodies code or vanilla art is redistributed.
