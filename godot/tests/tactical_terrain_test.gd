extends SceneTree
var checks := 0
var failures := 0
var catalog := TacticalCatalog.new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func run() -> void:
 var layout := load("res://data/battlefields/ashen_cliffs.tres") as BattlefieldConfig
 check(layout.validation_error().is_empty(), "Elevated map validates")
 var board := layout.create_board()
 check(TacticalCommands.castle(board, 0) == Vector2i(20,4) and TacticalCommands.castle(board, 1) == Vector2i(3,27), "Diagonal bases")
 check(board.tile_at(Vector2i(20,4)).elevation == 2 and board.tile_at(Vector2i(3,27)).elevation == 2, "Both bases on high ground")
 check(layout.resource_cells.size() == 5 and layout.high_yield_mines.size() == 3, "Two naturals and three contested expansions")
 check(board.tile_at(Vector2i(14,7)).resource_yield == 2 and board.tile_at(Vector2i(12,16)).resource_yield == 3, "Natural and contested income differ")
 check(TacticalMovement.can_step(board,Vector2i(17,6),Vector2i(16,6),"ROOK"), "Base ramp permits descending")
 check(TacticalMovement.can_step(board,Vector2i(16,6),Vector2i(17,6),"ROOK"), "Base ramp permits ascending")
 check(not TacticalMovement.can_step(board,Vector2i(17,5),Vector2i(16,5),"ROOK"), "Cliff next to ramp cannot be walked")
 check(is_equal_approx(board.surface_height(Vector2i(16,6)), 2.4), "Ramp center height is halfway between levels")
 # Ensure each mine and enemy base connects by real ramp-aware ground paths.
 var distance := SiegeAI.objective_distances(board, 0, "ROOK")
 check(distance.has(Vector2i(19,5)), "Rook vanguard can reach an expansion through ramps")
 board = BoardState.new(12,16)
 var pawn := board.spawn(catalog.get_unit("phalanx"),0,Vector2i(8,2))
 check(Vector2i(6,2) in MovementRules.pseudo_targets(board,pawn), "Pawn can move two forward within range away from initial rank")
 board.tile_at(Vector2i(7,2)).forest = true
 check(Vector2i(7,2) in MovementRules.pseudo_targets(board,pawn) and Vector2i(6,2) not in MovementRules.pseudo_targets(board,pawn), "Forest consumes two pawn movement points")
 check(MovementRules.attacks_from(board,pawn,Vector2i(7,3)) and not MovementRules.attacks_from(board,pawn,Vector2i(6,4)), "Pawn attacks only one diagonal")
 var rook := board.spawn(catalog.get_unit("ram"),0,Vector2i(8,8))
 check(Vector2i(4,8) in MovementRules.pseudo_targets(board,rook) and Vector2i(3,8) not in MovementRules.pseudo_targets(board,rook), "Four-tile rook cap")
 board.tile_at(Vector2i(7,8)).forest = true
 check(Vector2i(7,8) not in MovementRules.pseudo_targets(board,rook) and Vector2i(6,8) not in MovementRules.pseudo_targets(board,rook), "Rook cannot enter or pass forest")
 var bishop := board.spawn(catalog.get_unit("assassin"),0,Vector2i(8,4))
 board.tile_at(Vector2i(7,5)).forest = true
 check(Vector2i(7,5) in MovementRules.pseudo_targets(board,bishop) and Vector2i(6,6) in MovementRules.pseudo_targets(board,bishop) and Vector2i(5,7) not in MovementRules.pseudo_targets(board,bishop), "Diagonal forest traversal costs two points")
 var queen := board.spawn(catalog.get_unit("queen"),0,Vector2i(3,8))
 check(Vector2i(3,12) in MovementRules.pseudo_targets(board,queen) and Vector2i(3,13) not in MovementRules.pseudo_targets(board,queen) and Vector2i(4,10) not in MovementRules.pseudo_targets(board,queen), "Queen cap preserves straight/diagonal geometry")
 var knight := board.spawn(catalog.get_unit("cavalry"),0,Vector2i(6,12))
 board.tile_at(knight.cell).elevation = 2
 board.tile_at(Vector2i(5,11)).terrain = BattlefieldTileData.Terrain.IMPASSABLE
 check(Vector2i(4,11) in MovementRules.pseudo_targets(board,knight), "Knight jumps obstacles and height changes")
 check(Vector2i(4,8) not in MovementRules.pseudo_targets(board,knight), "Ordinary knight gets one jump")
 board.remove(knight)
 knight = board.spawn(catalog.get_unit("vanguard"),0,Vector2i(6,12))
 check(Vector2i(4,8) in MovementRules.pseudo_targets(board,knight), "High-mobility variant chains two L jumps")
 for cell in MovementRules.pseudo_targets(board,knight):
  check(maxi(absi(cell.x-6),absi(cell.y-12)) <= 4, "Chained knight stays within radius four")
 board = BoardState.new(12,16)
 bishop = board.spawn(catalog.get_unit("assassin"),0,Vector2i(2,2))
 board.tile_at(Vector2i(5,5)).elevation = 2
 board.spawn(catalog.get_unit("ram"),1,Vector2i(5,5))
 check(Vector2i(5,5) not in MovementRules.ranged_targets(board,bishop), "Low ground cannot shoot unspotted high ground")
 board.tile_at(Vector2i(5,4)).elevation = 2
 board.spawn(catalog.get_unit("phalanx"),0,Vector2i(5,4))
 check(Vector2i(5,5) in MovementRules.ranged_targets(board,bishop), "Allied high-ground scout provides vision")
 board = BoardState.new(12,16)
 bishop = board.spawn(catalog.get_unit("assassin"),0,Vector2i(6,6))
 board.tile_at(bishop.cell).elevation = 2
 check(Vector2i(2,2) in MovementRules.ranged_targets(board,bishop), "High-ground bishop gains a fourth diagonal tile")
 check(Vector2i(1,1) not in MovementRules.ranged_targets(board,bishop) and Vector2i(6,2) not in MovementRules.ranged_targets(board,bishop), "Bonus keeps range limit and diagonal shape")
 board.tile_at(bishop.cell).elevation = 1
 check(Vector2i(2,2) not in MovementRules.ranged_targets(board,bishop), "Mid ground gets no high-ground bonus")
 print("TACTICAL TERRAIN: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
