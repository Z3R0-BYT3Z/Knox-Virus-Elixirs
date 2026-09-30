# In-game acceptance checklist — v1.6.3 candidate

Automated validation does not execute Project Zomboid. Complete these checks on a test copy of your exact server build before uploading the public update.

1. Load a test copy of an existing save containing both old bottled item types; confirm no World Dictionary/load errors. Verify IDs and stored player cooldowns still load.
2. Craft both items, including recipes from a carried bag. Check First Aid requirements, toggles and correct water/container handling. AdminOnlyCrafting must reject a normal player and moderator, and allow an admin.
3. Right-click each bottle and complete the action as a remote multiplayer client. Confirm one item disappears on BOTH server and client, effects occur once, and drinking animation finishes. Reconnect immediately and confirm inventory agrees.
4. Cancel each action by walking, running or aiming. Confirm no treatment or item loss. Ordinary Eat/Half/Quarter must be unavailable on these items, including in an existing save.
5. Exercise cooldown rejection and failed cure rolls with both consume/return settings. Check no phantom returned bottle after reconnect. Compare single-player behavior.
6. Put a vanilla well at the desired Community Center position using game tools. If the designation menu is absent, test an existing vanilla map well and provide its sprite/entity identity from the game log for compatibility adjustment.
7. Only an admin can designate, recharge or remove a well. Verify ordinary water filling/drinking works normally and never grants healing.
8. Drink from the well with default settings: health is 100, injuries/bites/wound infections/Knox infection are cleared, and supply is unlimited. Repeat immediately; no well cooldown or charge depletion is allowed. Check server logs and a remote client's health panel.
9. Enable wound healing and test cuts, bleeding, fractures, glass and bites. Non-bitten parts restore fully; bites remain unless the optional cure succeeds.
10. Test full recovery with Antibodies present/absent. Disable bottled cures, set cure effectiveness to 1%, enable the one-cure limit, and have active bottle/stimulant cooldowns: the well must still fully restore the player and leave bottle cooldowns unchanged.
11. Have two clients drink repeatedly from an old zero-charge well in unlimited mode. Both must receive full recovery. In optional limited mode, the final charge must serve only one client.
12. Unlimited mode hides refills/recharge and rejects a forced refill without consuming a cure. Test donations/cap/synchronization in optional limited mode.
13. Check distant, different-floor, blocked-door/window, vehicle and destroyed-object interactions. They must not grant treatment.
14. Restart the actual dedicated server. Confirm designation, unlimited/full recovery settings and bottle cooldowns persist; old well cooldowns must be ignored. Unload/reload the map chunk and reconnect.
15. Connect a protocol 3 client to the protocol 4 server: it must receive mismatch feedback and gain no treatments. Update everyone and reconnect.
16. Test stimulant fatigue crash once, relog during pending crash, and overdose non-lethal limit.
17. If using local split-screen, target a treatment at the second player and confirm the first player's health does not change.
18. Inspect console.txt for serialization/constructor errors or missing methods. These tests are particularly important because no game runtime is available in the build environment.

No Steam upload, GitHub push or live-server installation is performed by this package.

19. Test a starving, exhausted character with negative calorie reserves. A full-recovery well must set hunger/thirst/fatigue to zero, endurance to 100%, and calories to 2,500. Repeated drinks must not stack calories; higher reserves must be preserved. Confirm these values on the drinking client after server completion and reconnect. Partial mode must leave these survival stats unchanged.

20. Use a bottled cure with legacy CureTreatmentScope=1: confirm full health, infection and survival recovery on the server and drinking client. Try another bottle within 24 game hours: it must remain in inventory without applying effects. Confirm stimulant behavior is unchanged.
