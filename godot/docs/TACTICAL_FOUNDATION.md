# PC tactical vertical slice — current architecture

Updated 28 October 2026. The playable tactical mode is **TAKTISCHE SCHLACHT** in the main menu. The separate classic mode retains its ordinary 8×8 rules.

## Gameplay and map

[ashen_cliffs.tres](../data/battlefields/ashen_cliffs.tres) defines the 24×32 battlefield: asymmetric high-ground bases, two-tile ramps, two natural mines (+2), three contested expansions (+3), forests, rivers and ruins. Heights 0/1/2 are converted to world heights using `BoardState.LEVEL_HEIGHT`. The default camera starts near the player's base; F opens the overview.

Each turn has three command points. A move, shot, deployment or contiguous horizontal pawn formation uses one CP. Deployments additionally spend the equipped card's gold cost. The initial budget is 10 gold; subsequent own turns add 2 base income and owned-mine income. New units may act immediately and a unit may use multiple CP. Space ends the turn; `BattlefieldConfig.turn_time_limit` enables an optional clock (zero by default). Pausing freezes it and pending AI actions. Restart invalidates old AI coroutines.

Five role-locked reserve slots are selected before the match and saved to `user://tactical_deck.cfg`. There are nine definitions in [units/](../data/units/), including the supplied Ironbound Knight. Cards support click, keys 1–5 and drag-and-drop. Shift-click or box-select a contiguous pawn row, then click its forward tiles or press G. R selects ranged fire; red ranged targets can also be clicked directly.

## Buildings and capture

- Every castle and mine has a **2×2 footprint**, keyed by its northwest anchor. `BoardState.buildings` stores the four cells; each tile points back to its anchor through `building_anchor`.
- Owner, income and shield state live **only on the anchor tile**. Income and mine counts iterate unique objective anchors, not occupied footprint cells.
- All four cells block movement and deployment. Ground attack rays and projectiles stop at structures; siege checks test every castle footprint cell and count each threatening unit once.
- `capture_ring(anchor)` returns the free, same-elevation perimeter, excluding the building. Castle deployment uses this ring, with unit-specific landing restrictions (including no rooks in forest).
- At the active side's turn end, a mine is claimed only if that side occupies its ring and no opponent occupies the ring. A contested ring preserves existing ownership. Vacating a captured mine does not erase ownership; its income begins at the next owner's turn start.
- `BattlefieldConfig.validation_error()` rejects overlapping, off-map, uneven or obstructed footprints and vanguard collisions. The custom scene's castle anchors and vanguard positions were adjusted for the new footprint.
- Buildings are solid in the grid model. Ground picking ignores decorative building meshes so the far side of a capture/deployment ring remains addressable.

## Movement, vision and siege

[TacticalMovement](../domain/tactical_movement.gd) owns capped chess geometry. Pawns move 1–2 forward and capture one diagonal; ordinary knights make one L-jump, Dawn Riders two chained L-jumps within radius four. Bishops move three diagonal points, rooks four orthogonal points, queens four in either geometry. Forest costs two movement points; rooks cannot enter it. Cliff transitions need ramps; knights ignore crossed obstacles/elevation but need a valid landing cell outside structures.

Ranged bishops have three diagonal tiles, or four from high ground. Shooting uphill requires an allied spotter at equal/higher elevation, within four tiles with clear height/structure line of sight. [MovementRules](../domain/movement_rules.gd) delegates UnitData units to this logic while retaining classical rules for legacy pieces.

[TacticalMatch](../domain/tactical_match.gd) owns phase, gold, CP, turn changes, mine capture and victory. A castle left besieged at its owner's turn end loses one of three shields; zero shields loses the match. [SiegeSearch](../domain/siege_search.gd) incrementally searches complete defensive command sequences, including affordable deployments, ranged fire and formations. An unfinished search is never treated as mate; zero CP alone is not mate. Unknown future ability scripts conservatively disable mate proof until they have a simulation contract, while shield loss still applies.

[TacticalCommands](../domain/tactical_commands.gd) is shared by UI, [SiegeAI](../domain/siege_ai.gd) and search. The AI uses role-aware terrain graphs to approach mine capture rings and castles. [UnitAbility](../domain/unit_ability.gd) supplies committed deploy/move/capture/end-turn hooks; previews never execute them. There are no unit HP, damage, upgrades or levels.

## Rendering and asset sockets

The PC project now defaults to **Forward+**. [BattleAtmosphere](../presentation/battle_atmosphere.gd) enables SDFGI, SSAO, volumetric fog at density .02, a low-canyon FogVolume, glow threshold .9, ACES and contrast 1.15. The midnight procedural sky has an amber/crimson horizon; a lowered, wet water surface fills the abyss. Moonlight is angled at 38° with softened shadows. An explicit Compatibility launch keeps basic depth fog and lighting but cannot provide the full Forward+ feature set.

[triplanar_stone.gdshader](../shaders/triplanar_stone.gdshader) blends seamless noise and normal maps in world-space YZ/XZ/XY coordinates. [BattlefieldTerrainView](../presentation/battlefield_terrain_view.gd) builds welded ground/ramp surfaces and cliff faces; there is no permanent global checkerboard/grid. Static terrain and buildings participate in GI; unit geometry uses dynamic GI.

[ObjectiveView](../presentation/objective_view.gd) owns an **AssetSocket**, footprint-sized procedural fallback art, owner banner, coin/+income emblem or three physical shield pips, GPU flame/embers and a flickering shadowed light. Assign a PackedScene to `BattlefieldConfig.mine_prefab` or `castle_prefab` to replace the fallback. Meshes are centered, grounded and fitted to a 2.05-unit footprint width and 2.15-unit height without changing rules. The five mine aprons show subdued runes; claimed mines recolor their banners, rings and torch light.

The user-supplied knight is documented in [ironbound/README.md](../assets/models/ironbound/README.md). `UnitData.model_includes_pedestal` avoids adding a second foundation; `preserve_model_materials` retains authored PBR colors. Existing role-specific foundation assets remain supported for other units.

## Interaction and HUD

- [UnitView](../presentation/unit_view.gd): 1.05× hover, rim light, .3-unit selected lift/bob, parabolic movement/deployment, one landing event. Reissued moves cancel the previous tween and its landing callback; animations never spend actions.
- [BattleEffects](../presentation/battle_effects.gd): short-lived GPU dust/debris and impact decal. Camera kick lasts .15 seconds.
- [BattleDecal](../presentation/battle_decal.gd): pulsing cyan move fill/border, crimson attack crosshair, selection runes. Hover adds a curved trajectory and translucent attack coverage from a copied hypothetical position, without mutating live state.
- [ReserveCard](../ui/reserve_card.gd): freestanding vertical tablets, bronze corners, cost hexagon, role emblem, torso/helmet portraits, 30px lift and 1.12× zoom. Unaffordable cards desaturate and cannot issue commands.
- [TacticalCrest](../ui/tactical_crest.gd): compact angled economy/castle crests, interpolated gold counter, CP crystal fragments and shield indicators. The main hand has no backing panel.
- [TacticalHUD](../ui/tactical_hud.gd) retains deck, pause, music, result and restart flows. Music volume is saved in `user://settings.cfg`.

## Validation and limits

On Godot 4.7.2 / Apple M4, the native tests used **Metal 4.0 Forward+**. Results in this implementation: 427 classical rule checks, 380 classical UI checks, 45 tactical field checks, 53 match checks, 60 movement/terrain checks, 153 building checks, 37 full tactical UI checks and 37 vertical-slice rendering/interaction checks passed (1,192 assertions).

The tactical UI tests exercise native mouse/keyboard/drag events. The visual test checks real renderer settings, model selection, no duplicate pedestal, card hover/dimming, lift/arc/landing/shake, gold animation and building widgets. Captures are written under `/tmp`, not committed as assets. This is a local AI vertical slice; network multiplayer and physical mobile-device builds are not included. The unit ability extension contract exists, but unspecified fire/rewind effects are not invented.
