---
name: studio-playtest
description: Drive the Roblox Studio MCP through Wild World's README Step-3 playtest checklist (login→arrival placement, on-foot crossing time, sightlines, Old Cypress legibility, movement/camera feel) — the manual verification the headless harness cannot do. Use when verifying the Bayou shell or the character controller in Studio.
disable-model-invocation: true
---

# Studio playtest — the Bayou shell

The headless suite (`./run-tests.sh`) proves the data/logic seams. It **cannot** judge the world or the
feel. This skill runs the README's **"Studio playtest checklist"** (Step 3) against a live Studio session
via the `roblox-studio` MCP, and reports an honest pass / fail / needs-real-device per item.

> Be honest about the split: **frame rate on a mid phone** and **touch movement feel** require a real
> device — Studio can only approximate them. Report those as `needs-device`, not `pass`.

## Preconditions

1. The place is open in Studio with the project synced (Rojo): `src/` → `ServerScriptService.WildWorld`,
   `client/` → `StarterPlayerScripts` (see `default.project.json`). If it isn't, stop and tell the user to
   open the place and `rojo serve` / sync first.
2. Confirm the bridge sees Studio: `list_roblox_studios`; if more than one, `set_active_studio`.

## Procedure

For each step, prefer observing real state (console output, instance positions, screenshots) over assuming.

1. **Sync check.** `get_studio_state` and `search_game_tree` for `ServerScriptService.WildWorld` and the
   `BayouShell_Placeholder` build. If the shell isn't present, the world script hasn't run — note it.
2. **Start play.** `start_stop_play` to enter Play mode. Then `get_console_output` and confirm there are
   **no errors** and that `require`-by-string (`@src/...`) resolved at runtime.
3. **login → arrival placement (§ arrival routing).** Confirm the character spawned at the Bayou **arrival
   clearing** (the gate-less root). Use `inspect_instance` on the player's character / `HumanoidRootPart`
   for position, or `execute_luau` to read it, and compare against the arrival anchor from `Shells` config.
   The returning→Lodge branch is intentionally absent (`TODO(step-8)`) — do not expect it.
4. **Crossable on foot < ~1 min (§2.4).** From the arrival clearing, `character_navigation` to the far edge
   of the map; time the traversal. The headless test proves the *distance* is < 60 s of walk; here confirm
   it *feels* under a minute and the path isn't blocked.
5. **The Landing in line of sight (§2.6.2).** `screen_capture` from the arrival clearing facing the Landing
   — the *distance* is headless-proven; you are judging the **sightline** (is the Landing visible from
   arrival, with the levee and a channel bank in view?).
6. **Clearing faces the Sunny Levee, bank a few steps off (§2.6.1).** `screen_capture` from arrival; confirm
   it faces the levee and a channel bank is adjacent.
7. **Navigate by the Old Cypress (§2.2 legibility).** `screen_capture` from several points across the map;
   confirm the Old Cypress beacon is visible from most of them (it's the wayfinding landmark).
8. **Movement & camera.** Drive with `user_keyboard_input` / `user_mouse_input`; confirm third-person camera
   behaves. Flag touch feel and sustained frame rate as `needs-device`.
9. **Stop play.** `start_stop_play` to exit Play mode.

## Output

Render the README checklist as a table — one row per item — with **pass / fail / needs-device**, the
evidence (screenshot reference, console line, measured time, or position), and a one-line note. End with
the honest bottom line: which items are genuinely verified vs which still require a phone. Do not claim the
step is done if any `needs-device` items are unconfirmed.
