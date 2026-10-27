# PC tactical foundation — stage one

The current user direction supersedes the mobile-only, fixed-army specification for the new tactical mode. This stage provides a navigable terrain and movement sandbox. The existing classic match remains usable while its replacement command loop is built.

## Entry and configuration

Open **TAKTIKFELD** in the main menu, or launch:

```sh
"$GODOT_BIN" --path godot res://scenes/tactical_battlefield.tscn
```

The scene exports a [BattlefieldConfig](../data/battlefield_config.gd). Its default [river_crossing.tres](../data/battlefields/river_crossing.tres) is 12 rows × 16 columns. A separate config can use 14×18 (tested), or dimensions from 8 to 40. Terrain positions are explicit `(row, column)` arrays; edit these when designing a differently sized layout. There is no procedural promise to relocate obstacles when dimensions change. Layout validation rejects out-of-bounds cells and overlaps, including castles. Castles occupy the top and bottom rows at `columns / 2` (right central column on even-width boards).

## Architecture

| Responsibility | File | Contract |
| --- | --- | --- |
| Unit definition | [unit_data.gd](../data/unit_data.gd), [units/](../data/units/) | Immutable/shared Resource, enum PAWN/KNIGHT/BISHOP/ROOK/QUEEN, ID, name, cost, figurine PackedScene, ability Script, optional ranged range |
| Variant lookup | [tactical_catalog.gd](../data/tactical_catalog.gd) | Validates trusted `.tres` resources; no king/spell cards. Five-role default reserve IDs are available for the next HUD stage |
| Layout | [battlefield_config.gd](../data/battlefield_config.gd) | Validated configuration creates an independent BoardState every time |
| Tile state | [battlefield_tile_data.gd](../data/battlefield_tile_data.gd) | Terrain enum, owner (−1 neutral), income and garrison shields. Named to avoid Godot's native `TileData` class |
| Grid/occupancy | [board_state.gd](../domain/board_state.gd) | Per-instance rows/columns, tiles separate from units, `contains()` and `is_walkable()`, independent copies |
| Unit instance | [unit_state.gd](../domain/unit_state.gd) | UID, team, cell, reference to definition, committed position history and per-unit ability instance |
| Geometry | [movement_rules.gd](../domain/movement_rules.gd) | Existing chess movement reused; sliding distances and pawn start ranks use board size. Terrain stops ground rays. Separate ranged geometry crosses terrain but stops at a unit |
| Committed sandbox actions | [tactical_field.gd](../domain/tactical_field.gd) | Place/move/capture; validates geometric legality; creates four-unit vanguards and invokes ability hooks. It does not spend CP/currency or alternate turns |
| Ability contract | [unit_ability.gd](../domain/unit_ability.gd) | `on_deploy(board, unit)`, `on_move(board, unit, from)`, `on_capture(board, unit, captured)`, `on_turn_end(board, unit)` |
| Shared board/unit presentation | [board_view.gd](../presentation/board_view.gd), [unit_view.gd](../presentation/unit_view.gd) | Uses configured dimensions for transforms, picking, highlights and model placement. Existing common pedestal/team treatment is reused |
| Terrain presentation | [battlefield_terrain_view.gd](../presentation/battlefield_terrain_view.gd) | Extends existing slate mesh to the configured rectangle, distinct water/rocks/nodes/castles |
| PC camera | [tactical_camera_controller.gd](../presentation/tactical_camera_controller.gd) | WASD, edge pan, wheel zoom, middle-button yaw/tilt; clamped focus/distance/tilt, release and focus-loss handling |
| Sandbox scene | [tactical_battlefield.gd](../presentation/tactical_battlefield.gd) | Selection, preview, scene navigation and music. Both teams are controllable; no win condition yet |

## Important boundaries

- `BoardState.inside()` and `BoardView.world_position(cell)` retain their 8×8 defaults for old callers. New rules use `board.contains()`; new renderers pass rows/columns or call `view.cell_position()`.
- Classical `MovementRules.targets()` simulates king safety and intentionally rejects kingless positions. The tactical sandbox uses `pseudo_targets()` because its castles are tile objectives, not KING pieces. A future siege controller must not silently inherit classical “must get out of check immediately” restrictions: the proposed shield system permits an unresolved siege at turn end.
- Ground captures remain immediate. Knights jump blockers but cannot land in water/on rocks. All slider movement currently stays on land. `ranged_targets()` is a geometric hook, not a playable ranged command; it does not authorize moving across rivers.
- Standard pawn first-step geometry is retained; tactical promotion, en passant, and castling are not implemented as tactical commands. Classical mode still supports all three. These tactical exceptions require explicit design decisions later.
- Resource node capture/income and castle shield loss are **data only** for now. No UI silently awards resources or claims a siege win. Node income defaults to 1, castle shields to 3.
- Definitions may be shared, but live ability instances and position histories may not. Copies isolate tile state/history and deliberately omit live ability instances. Preview queries do not call hooks. Actual tactical captures dispatch `on_capture` after removal, followed by `on_move` after the attacker reaches its destination.
- `notify_turn_end(side)` is the explicit future controller integration point. No turn-end is inferred from a sandbox move.
- New ability scripts must extend `UnitAbility` and live in the trusted project. Do not deserialize arbitrary scripts from player deck data. Fire, shields, time rewind and other actual abilities are not supplied yet.
- Existing source changes to team materials, music and settings were preserved. An unrelated duplicate insertion of the settings description label was removed while integrating the menu entry.

## Next stage

1. Build a tactical command manager with turn-start/action/end phases, resources and CP. It wraps committed field operations and owns their authorization.
2. Add the five-slot reserve UI, role-validated deck selection, 1–5 shortcuts and deployment adjacent to the owned castle, with atomic CP/currency spending.
3. At turn end capture occupied nodes; at turn start award configured income. Define when new deployments may act and whether one unit may spend multiple CP.
4. Combine ground and ranged threat maps for castles, decrement garrison shields at unresolved siege turn end, and define/implement defensive-response search for tactical checkmate. Clarify “no legal responses” under CP, reserve cards and future abilities.
5. Add formation selection/commands and actual ability effects with targeted tests. Do not treat the sandbox as a completed tactical match.

## Evidence

Godot 4.7.2: 43 tactical domain checks, 25 native tactical UI checks (including 12×16 and 14×18), 427 existing classical rule checks and 380 existing classical UI checks pass. Native UI checks cover camera input and return/menu entry; they temporarily control the mouse. The reference screenshot is generated at `/tmp/schachschlachtfeld-tactical-field.png`, not a tracked asset. No multiplayer or physical-device validation was performed for this stage.
