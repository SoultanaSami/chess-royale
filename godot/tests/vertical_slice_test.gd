extends "res://tests/tactical_view_smoke.gd"
var impact_count := 0
var saw_shake := false
func run() -> void:
 root.size = Vector2i(1440,810)
 scene = load("res://scenes/tactical_battlefield.tscn").instantiate()
 scene.persistence_enabled = false
 scene.ai_enabled = false
 root.add_child(scene)
 current_scene = scene
 root.grab_focus()
 scene.camera_controller.edge_pan_enabled = false
 await create_timer(1).timeout
 for i in range(scene.hud.selectors[1].item_count):
  if str(scene.hud.selectors[1].get_item_metadata(i)) == "ironbound":
   scene.hud.selectors[1].select(i)
   scene.hud.selectors[1].item_selected.emit(i)
 await frames()
 await click(button("SCHLACHT BEGINNEN").get_global_rect().get_center())
 await create_timer(.5).timeout
 check(scene.started,"Native deck confirms supplied knight")
 var env: Environment = scene.board_view.find_children("*","WorldEnvironment",true,false)[0].environment
 check(RenderingServer.get_current_rendering_method()=="forward_plus","Real Forward+ rendering backend")
 check(env.sdfgi_enabled and env.ssao_enabled and env.volumetric_fog_enabled,"GI, ambient occlusion and volumetric fog enabled")
 check(env.tonemap_mode==Environment.TONE_MAPPER_ACES and is_equal_approx(env.adjustment_contrast,1.15),"ACES and contrast configured")
 check(env.glow_enabled and is_equal_approx(env.glow_hdr_threshold,.9),"Bloom threshold configured")
 var markers: Dictionary = scene.board_view.get_meta("objective_markers")
 check(markers.size()==7,"Seven multi-tile building views")
 for anchor in markers:
  var objective: ObjectiveView = markers[anchor]
  check(objective.asset_socket.name=="AssetSocket" and objective.torch.fire is GPUParticles3D,"Building socket and GPU fire exist")
  if objective.terrain==BattlefieldTileData.Terrain.CASTLE:
   check(objective.pips.size()==3,"Three physical shield pips")
  for label in objective.find_children("*","Label3D",true,false):
   check(label.text.begins_with("+"),"Building UI contains only numeric income, no raw names")
 var knight: UnitState
 for unit in scene.game.board.units.values():
  if unit.team==0 and unit.variant_id=="ironbound": knight=unit
 check(knight!=null,"Provided GLB deployed as selected variant")
 var view: UnitView = scene.board_view.units[knight.uid]
 check(view.foundation==null and not view.plate.visible,"Integrated pedestal is not duplicated")
 await motion(point(knight.cell,.6))
 await create_timer(.18).timeout
 check(view.scale.x>1.04,"Hover physically raises unit scale")
 await click(point(knight.cell,.6))
 await create_timer(.20).timeout
 check(view.model.position.y-view._model_rest_y>.25 and view.selection.visible,"Selected figurine floats over glowing pedestal rune")
 var destination := Vector2i(17,2)
 check(destination in scene.targets,"Knight destination remains legal during selection animation")
 var before_cp: int = scene.game.cp
 var before_position := knight.cell
 await motion(point(destination))
 check(scene.board_view.preview_layer.get_child_count()>1,"Hover draws trajectory and ghost attack threat")
 check(scene.game.cp==before_cp and knight.cell==before_position,"Hover preview never mutates the game")
 scene.board_view.unit_impact.connect(func():
  impact_count += 1
  saw_shake = scene.camera_controller.shake_remaining>0
 )
 await click(point(destination))
 check(view._moving and view.position.y>scene.board_view.cell_position(destination).y+.05,"Move follows airborne arc")
 await create_timer(.5).timeout
 check(knight.cell==destination and view.position.distance_to(scene.board_view.cell_position(destination))<.01,"Animated move lands exactly on authoritative tile")
 check(impact_count==1 and saw_shake,"One landing triggers one impact and camera kick")
 check(scene.game.cp==before_cp-1,"Animation does not spend a second action")
 await motion(scene.hud.cards[0].get_global_rect().get_center())
 await create_timer(.2).timeout
 check(scene.hud.cards[0].lift>29 and scene.hud.cards[0].scale.x>1.11,"Tarot card lifts 30 pixels and scales on hover")
 check(not scene.hud.footer is PanelContainer,"Cards have no giant backing panel")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/vertical-slice-final.png")
 scene.game.gold[0] = 0
 scene.refresh()
 await create_timer(.35).timeout
 check(scene.hud.cards[0].disabled and scene.hud.cards[0].portrait.material.get_shader_parameter("saturation")==0,"Unaffordable cards dim and desaturate")
 check(scene.hud.left_crest.gold_display<.01,"Gold counter animates to actual total")
 var mine := Vector2i(14,7)
 scene.game.board.tile_at(mine).owner = 0
 var castle := TacticalCommands.castle(scene.game.board,0)
 scene.game.board.tile_at(castle).garrison_shields = 2
 scene.refresh()
 check(markers[mine].torch.color==Color("67b9fa"),"Mine torch follows captured faction color")
 check(markers[castle].pips[2].material_override.emission_energy_multiplier==0 and scene.hud.right_crest.shields[0]==2,"World and HUD shield pips agree")
 current_scene.queue_free()
 await frames()
 await create_timer(.3).timeout
 print("VERTICAL SLICE: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
