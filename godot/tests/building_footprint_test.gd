extends SceneTree
var checks := 0
var failures := 0
func _initialize(): run.call_deferred()
func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func run():
 var config := load("res://data/battlefields/ashen_cliffs.tres") as BattlefieldConfig
 check(config.validation_error().is_empty(),"All 2x2 foundations fit on flat, unobstructed ground")
 var game := TacticalMatch.new(config)
 check(game.board.buildings.size()==7,"Five mines and two castles")
 for anchor in game.board.buildings:
  check(game.board.footprint(anchor).size()==4,"Every structure occupies four cells")
  for cell in game.board.footprint(anchor):
   check(not game.board.can_enter(cell) and game.board.tile_at(cell).building_anchor==anchor,"Footprint is solid and resolves to anchor")
  for cell in game.board.capture_ring(anchor):
   check(game.board.can_enter(cell) and cell not in game.board.footprint(anchor),"Capture/deployment ring is outside the mesh")
 var clone := game.board.copy()
 for anchor in clone.buildings:
  for cell in clone.footprint(anchor): check(not clone.can_enter(cell),"Independent simulation preserves all structural cells")
 var mine := Vector2i(14,7)
 var ring := game.board.capture_ring(mine)
 game.board.units.clear()
 var own := game.board.spawn(game.catalog.get_unit("phalanx"),0,ring[0])
 var enemy := game.board.spawn(game.catalog.get_unit("phalanx"),1,ring[1])
 game.end_turn(0)
 check(game.board.tile_at(mine).owner==-1,"Contested neutral mine stays neutral")
 game.end_turn(1)
 check(game.board.tile_at(mine).owner==-1,"Neither side wins a contested ring by ending first")
 game.board.remove(enemy)
 game.end_turn(0)
 check(game.board.tile_at(mine).owner==0,"Uncontested friendly apron claims mine")
 var gold_before := game.gold[0]
 game.end_turn(1)
 check(game.gold[0]==gold_before+4,"A 2x2 mine pays once, never four times")
 enemy = game.board.spawn(game.catalog.get_unit("phalanx"),1,ring[1])
 game.end_turn(0)
 game.end_turn(1)
 check(game.board.tile_at(mine).owner==0,"Contestation preserves the existing owner")
 game.board.remove(own)
 game.end_turn(0)
 game.end_turn(1)
 check(game.board.tile_at(mine).owner==1 and game.mines_owned(1)==1,"Uncontested enemy ring recaptures one mine")
 var broken := config.duplicate(true) as BattlefieldConfig
 broken.player_castle = Vector2i(23,31)
 check(not broken.validation_error().is_empty(),"Building cannot hang over map boundary")
 broken = config.duplicate(true) as BattlefieldConfig
 broken.resource_cells.append(config.resource_cells[0]+Vector2i(0,1))
 check(not broken.validation_error().is_empty(),"Footprint overlap is rejected even with different anchors")
 game.board.units.clear()
 var castle := TacticalCommands.castle(game.board,0)
 var flank := castle+Vector2i(1,4)
 var attacker := game.board.spawn(game.catalog.get_unit("ram"),1,flank)
 check(not MovementRules.attacks_from(game.board,attacker,castle),"Attack need not intersect castle anchor")
 check(TacticalCommands.threats(game.board,0).size()==1,"Attack on another footprint tile still besieges castle exactly once")
 var forest := game.board.capture_ring(castle)[0]
 game.board.tile_at(forest).forest = true
 check(forest not in game.deploy_targets(3,0) and not game.execute({"kind":"deploy","slot":3,"to":forest},0),"Rook deployment respects forest exclusion")
 var catalog := TacticalCatalog.new()
 check(catalog.get_unit("ironbound").model_includes_pedestal and catalog.get_unit("ironbound").preserve_model_materials,"Supplied knight keeps its pedestal and authored materials")
 print("BUILDINGS: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
