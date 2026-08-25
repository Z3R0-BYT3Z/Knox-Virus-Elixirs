KNOX VIRUS ELIXIRS B42 v1.5.2
========================================

MOD ID
ElixirCraftB42

ITEM IDS
ElixirCraft.KnoxCure
ElixirCraft.StaminaElixir

INSTALLATION
Copy ElixirCraftB42 into C:\Users\<you>\Zomboid\mods\ and enable it.
For multiplayer, install the same version on the server and every client.
Append ElixirCraftB42 to the server Mods= line. After Workshop publication,
append its Workshop ID to WorkshopItems= as well.

DEFAULT BALANCE
- Experimental Knox Cure: 100% effectiveness by default; infection-and-bite scope by default.
- Cure effectiveness, four treatment scopes, and a one-cure character limit are configurable.
- Cure crafting: enabled; admins can disable it for reward/event-only use.
- Cure cooldown: 24 in-game hours.
- Adrenaline Stimulant: 70% endurance recovery, fatigue preserved, 6-hour cooldown.
- Overdose window: 12 in-game hours, allowing a risky second dose after cooldown.
- Usage logging: enabled.
- Antibodies integration: enabled when the compatible module is detected.
- Rare medical-container loot: disabled by default.
- First Aid requirements: Cure 6, Adrenaline 3.
- Optional admin-only crafting is enforced by both recipe tests.
- Stimulant post-crash: enabled; overdose penalties are configurable.
- Rejected pre-validation requests leave the exact item untouched.
- Failed post-consumption treatments return the same item object when configured.

ANTIBODIES COMPATIBILITY
- Compatible with Antibodies v1.97 (Workshop ID 2392676812).
- Antibodies continues to provide condition-based, chance-driven recovery.
- The Experimental Knox Cure is a separate recovery path with configurable effectiveness.
- Cure use invokes Antibodies' own cure method and resets its cached levels.
- Antibodies is supported but not required; this add-on remains standalone.

MULTIPLAYER
- Consume an elixir through the normal inventory food action to play its bottle-drinking animation.
- The OnEat callback submits the exact item ID; the server locates and removes that item before applying treatment.
- There is no separate instant-use context action or second treatment pathway.
- A protocol-v3 handshake blocks treatment commands from incompatible clients.
- Rejected requests cannot create replacement items.
- Returned items are confirmed by ID and full type after reinsertion.
- Dedicated-server logging records validated use.
- Private/global usage announcements have a per-player cooldown.

ADMIN COMMANDS
additem "Username" "ElixirCraft.KnoxCure" 1
additem "Username" "ElixirCraft.StaminaElixir" 1

NOTES
- Water is consumed from the selected bottle or mug; the container is retained.
- Sandbox changes should be made while the server is stopped, then restarted.
- Test on a staging save before enabling infection curing on a public server.

V1.5.2 AUDIT UPDATE
- Updated the custom sandbox-options schema marker for current Build 42 parsing.
- Retained protocol v3 and all existing save, cooldown, treatment, and item identifiers.
- Audited server-authoritative item validation, rejection recovery, rate limiting,
  manifests, translations, recipes, textures, and Workshop package structure.
