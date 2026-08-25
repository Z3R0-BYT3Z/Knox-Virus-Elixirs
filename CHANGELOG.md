# Changelog

## [1.5.2] - 2026-08-22

- imports the audited v1.5.2 package exactly as deployed;
- updates the custom sandbox-options schema marker for current Build 42 parsing;
- preserves protocol v3 and all existing save, cooldown, treatment, item, and `ElixirCraftB42` identifiers;
- audits server-authoritative item validation, rejection recovery, rate limiting, manifests, translations, recipes, textures, and Workshop package structure.

## [1.5.1] - 2026-08-20

- renames the displayed package to Knox Virus Elixirs without changing the canonical `ElixirCraftB42` mod ID;
- aligns `version`, `modversion`, release tooling, documentation, translations, and Workshop metadata on 1.5.1;
- preserves the namespaced sandbox translation keys required by the existing English translation table.

All notable changes to this project will be documented here.

## [Unreleased]

- In-game Build 42.20 multiplayer validation.
- Balance review for cure ingredients and cooldowns.

## [1.5.0] - 2026-08-18

### Added

- Protocol-v3 client/server handshake with retries and server-side blocking of incompatible treatment commands.
- Localized private and global treatment-use announcements with a configurable per-player cooldown.
- Detailed treatment-scope and administrator-only crafting tooltips.

### Fixed

- Enforced administrator-only crafting in both recipe eligibility callbacks using the player's server access level.
- Made rare-loot registration explicitly server-only and idempotent.
- Strengthened rejected-item restoration by confirming its ID, full type, and original container, with an error log if rollback fails.

### Security

- Treatment commands now require both a completed compatibility handshake and the current protocol value.
- The animated vanilla consumption route remains runtime-gated by exact server inventory ID/type validation; no unverified custom timed-action API was introduced.

## [1.4.4] - 2026-08-18

### Fixed

- Unified consumption around the vanilla food action so bottle-drinking animation and server validation use one pathway.
- Added the exact inventory item ID to multiplayer `OnEat` requests and removed the competing instant-use context action.
- Corrected cure scopes: Knox-only preserves wound infections; the second scope additionally clears bites; the third clears wound infections and restores body parts; the fourth restores full health.
- Confirmed rejected-item restoration by locating the same ID and full type after reinsertion.

### Preserved

- Server-authoritative exact stat synchronization and non-lethal overdose handling.
- Antibodies integration, cooldowns, per-character cure limits, and configurable rejected-item behavior.

## [1.4.3] - 2026-08-18

### Fixed

- Enforced the Adrenaline crafting toggle.
- Activated all four cure treatment scopes and the cure-effectiveness roll.
- Enforced the optional one-successful-cure-per-character limit using persistent character mod data.
- Restored the missing shared validation and settings functions used by client and server code.
- Prevented multiplayer stimulant bonuses from being added twice by applying exact server-authoritative results on clients.
- Clamped overdose damage so it cannot reduce a living character below one health.
- Localized stimulant crash, ineffective-cure, and cure-limit feedback.

### Preserved

- Antibodies medical-file integration and native fallback behavior.
- Configurable return/consumption behavior when a treatment is rejected or ineffective.

## [1.2.0] - 2026-08-17

### Added

- Experimental Knox Cure.
- Adrenaline Stimulant.
- Optional Antibodies v1.97 medical-file integration.
- Native Sandbox settings.
- Persistent per-character cooldowns.
- Configurable endurance restoration and fatigue removal.
- Treatment-use logging with username, character, and coordinates.
- English item, recipe, interface, and Sandbox translations.
- Custom poster and inventory icons.
- Build and Workshop packaging scripts.

### Changed

- Redesigned the original Instant Health Potion as a guaranteed Knox cure.
- Increased the cure recipe cost to include Plantain, Ginseng, and Antibiotics.
- Separated guaranteed cure behavior from Antibodies' condition-based recovery.

## [1.1.0] - 2026-08-17

- Initial configurable health and stamina prototype.
