extends SceneTree
## Chess regressions and published perft reference counts. No presentation dependency.
var checks: int = 0
var failures: int = 0
var catalog := Catalog.new()
const IDS = {"p":"phalanx", "n":"cavalry", "b":"assassin", "r":"ram", "q":"queen", "k":"guard"}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func square(text: String) -> Vector2i:
	return Vector2i(8 - int(text[1]), text.unicode_at(0) - 97)

func position(fen: String) -> GameManager:
	var game := GameManager.new(catalog)
	game.board = BoardState.new()
	var fields := fen.split(" ")
	var ranks := fields[0].split("/")
	for row in range(8):
		var col := 0
		for letter in ranks[row]:
			if letter.is_valid_int():
				col += int(letter)
			else:
				game.board.spawn(catalog.get_piece(IDS[letter.to_lower()]), 0 if letter == letter.to_upper() else 1, Vector2i(row,col))
				col += 1
	game.turn = 0 if fields[1] == "w" else 1
	for right in fields[2]:
		if right == "-":
			continue
		var side := 0 if right == right.to_upper() else 1
		var row := 7 if side == 0 else 0
		game.board.king(side).castle_eligible = true
		var rook := game.board.at(Vector2i(row,7 if right.to_lower() == "k" else 0))
		if rook != null:
			rook.castle_eligible = true
	if fields[3] != "-":
		game.board.en_passant_target = square(fields[3])
		game.board.en_passant_pawn = game.board.en_passant_target + Vector2i(1 if game.turn == 0 else -1,0)
	return game

func play(game: GameManager, from: String, to: String, promote: String = "") -> bool:
	return game.move_unit(square(from),square(to),promote)

func legal(game: GameManager, from: String, to: String) -> bool:
	return square(to) in game.legal_targets(square(from))

func fingerprint(board: BoardState) -> String:
	var values: Array[String] = []
	for row in range(8):
		for col in range(8):
			var u := board.at(Vector2i(row,col))
			if u != null:
				values.append("%d:%s:%s:%s:%s:%s:%s" % [u.uid,u.variant_id,u.chess_type,u.team,u.cell,u.has_moved,u.castle_eligible])
	return str(values) + str(board.en_passant_target) + str(board.en_passant_pawn) + str(board.next_uid)

func perft(board: BoardState, side: int, depth: int) -> int:
	if depth == 0:
		return 1
	var nodes := 0
	for unit in board.units.values():
		if unit.team != side:
			continue
		for to in MovementRules.targets(board, unit):
			var choices: Array = MovementRules.PROMOTIONS.keys() if MovementRules.needs_promotion(unit,to) else ["queen"]
			for promotion in choices:
				var next := board.copy()
				MovementRules.apply_move(next,next.at(unit.cell),to,promotion)
				nodes += perft(next,1-side,depth-1)
	return nodes

func _initialize() -> void:
	test_catalog_and_setup()
	test_turns_and_capture()
	test_king_safety()
	test_castling()
	test_en_passant()
	test_promotion()
	test_outcomes()
	test_perft()
	test_ai()
	print("RULES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_catalog_and_setup() -> void:
	check(catalog.entries.size() == 10,"Eight models and two spell descriptions")
	check(catalog.valid_deck(Catalog.DEFAULT_DECK),"Full 16-slot deck valid")
	check(not catalog.valid_deck(Catalog.DEFAULT_DECK + ["bind"]),"Spells have no loadout slots or invented limits")
	check(not catalog.valid_deck(Catalog.DEFAULT_DECK.slice(0,10)),"No accidental ten-piece setup")
	for raw in JSON.parse_string(FileAccess.get_file_as_string("res://data/variants.json")):
		check(not raw.has("attack") and not raw.has("maxHp") and not raw.has("manaCost"),"No obsolete combat stats: " + raw.id)
	check(catalog.get_piece("bind").rules_status == "planned" and catalog.get_piece("protect").rules_status == "planned","Spells explicitly remain planned")
	var chosen := Catalog.DEFAULT_DECK.duplicate()
	chosen[0] = "trebuchet"
	var g := GameManager.new(catalog, chosen)
	check(g.board.units.size() == 32,"All 32 units exist at match start")
	check(g.board.at(square("a1")).variant_id == "trebuchet" and g.board.at(square("h1")).variant_id == "golem","Independent rook variants survive deck setup")
	for side in [0,1]:
		var counts := {"PAWN":0,"ROOK":0,"KNIGHT":0,"BISHOP":0,"QUEEN":0,"KING":0}
		for unit in g.board.units.values():
			if unit.team == side:
				counts[unit.chess_type] += 1
		check(counts == {"PAWN":8,"ROOK":2,"KNIGHT":2,"BISHOP":2,"QUEEN":1,"KING":1},"Exact chess composition on side " + str(side))
		check(g.board.king(side).cell == Vector2i(7 if side == 0 else 0,4),"King starts on E")
	var before := fingerprint(g.board)
	for unit in g.board.units.values():
		MovementRules.targets(g.board,unit)
	check(before == fingerprint(g.board),"Legal move queries do not mutate any piece or castling rights")

func test_turns_and_capture() -> void:
	var g := GameManager.new(catalog)
	check(play(g,"e2","e4") and g.turn == 1 and g.ply_count == 1,"One move immediately passes turn")
	check(not play(g,"d2","d4") and g.ply_count == 1,"Second white move rejected without mutation")
	check(play(g,"d7","d5") and g.turn == 0,"One black reply returns turn")
	check(play(g,"e4","d5") and g.board.units.size() == 31 and g.board.at(square("e4")) == null,"Capture removes defender and occupies square")
	check(play(g,"d8","d5"),"Black queen can capture on a clear file")
	g = position("7k/8/8/3r4/4P3/8/8/K7 w - - 0 1")
	check(play(g,"e4","d5") and g.board.at(square("d5")).chess_type == "PAWN" and g.board.units.size() == 3,"Pawn captures rook immediately regardless of former stats")
	g = GameManager.new(catalog)
	check(not play(g,"c1","h6"),"Assassin obeys bishop blockers")
	check(not g.move_unit(Vector2i(-1,0),Vector2i(8,8)),"Out-of-board command rejected")
	check(not g.has_method("play_card") and not g.has_method("end_turn"),"No spell activation or pass-turn command")

func test_king_safety() -> void:
	var g := position("4r2k/8/8/8/8/8/4R3/4K3 w - - 0 1")
	check(not legal(g,"e2","f2") and legal(g,"e2","e8"),"Pinned rook cannot expose own king; may capture attacker")
	check(not play(g,"e2","f2") and g.turn == 0,"Illegal self-check does not consume a turn")
	g = position("4r2k/8/8/8/8/8/R7/4K3 w - - 0 1")
	check(g.in_check(0),"Rook check detected")
	check(legal(g,"a2","e2") and not legal(g,"a2","a3"),"Only replies resolving check are legal")
	check(not legal(g,"e1","e2"),"King cannot walk into attacked square")
	g = position("7k/8/8/8/8/4p3/8/4K3 w - - 0 1")
	check(not legal(g,"e1","d2") and legal(g,"e1","e2"),"Pawn attacks diagonal empty square, not forward square")
	g = position("8/8/8/8/8/4k3/8/4K3 w - - 0 1")
	check(not legal(g,"e1","e2"),"Kings may not become adjacent")
	g = position("4k3/4n3/8/5K2/8/8/8/4R3 w - - 0 1")
	check(MovementRules.attacked(g.board,square("f5"),1) and not legal(g,"f5","g6"),"Pinned knight still attacks king squares")
	g = position("7k/8/8/8/8/8/8/K6R w - - 0 1")
	check(g.in_check(1) and not legal(g,"h1","h8") and not play(g,"h1","h8"),"Enemy king is attacked but never a capture target")

func test_castling() -> void:
	for side in [0,1]:
		for wing in ["c","g"]:
			var g := position("r3k2r/8/8/8/8/8/8/R3K2R %s KQkq - 0 1" % ("w" if side == 0 else "b"))
			var rank := "1" if side == 0 else "8"
			check(play(g,"e"+rank,wing+rank),"Both castling wings legal for both sides")
			var rook_col := "d" if wing == "c" else "f"
			check(g.board.at(square(rook_col+rank)).chess_type == "ROOK" and g.board.at(square(wing+rank)).chess_type == "KING","Castling moves king and rook together")
			check(g.ply_count == 1 and g.turn == 1-side,"Castling consumes exactly one turn")
	for variant in ["ram","trebuchet","golem"]:
		var g := position("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
		g.board.at(square("h1")).variant_id = variant
		check(play(g,"e1","g1"),"All rook variants can castle: " + variant)
	for fen in [
		"4r1k1/8/8/8/8/8/8/4K2R w K - 0 1",
		"5rk1/8/8/8/8/8/8/4K2R w K - 0 1",
		"6rk/8/8/8/8/8/8/4K2R w K - 0 1",
		"4k3/8/8/8/8/8/8/4KB1R w K - 0 1",
		"4k3/8/8/8/8/8/8/4K2R w - - 0 1"]:
		var g := position(fen)
		check(not legal(g,"e1","g1"),"No castling from, through, into check, through blocker or without rights")
	var g := position("4k2r/8/8/8/8/8/8/4K2R w K - 0 1")
	check(legal(g,"e1","g1"),"Attacked rook square does not prevent castling")
	g = position("1r2k3/8/8/8/8/8/8/R3K3 w Q - 0 1")
	check(legal(g,"e1","c1"),"Attacked B1 does not prevent long castling")
	g.board.spawn(catalog.get_piece("cavalry"),0,square("b1"))
	check(not legal(g,"e1","c1"),"Occupied B1 does prevent long castling")
	g = position("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
	check(play(g,"h1","h2") and play(g,"e8","e7") and play(g,"h2","h1") and play(g,"e7","e8"),"Rook can leave and return")
	check(not legal(g,"e1","g1"),"Returned rook cannot restore castling rights")
	g = position("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
	check(play(g,"e1","f1") and play(g,"e8","e7") and play(g,"f1","e1") and play(g,"e7","e8"),"King can leave and return")
	check(not legal(g,"e1","g1"),"Returned king cannot restore castling rights")

func test_en_passant() -> void:
	var g := position("7k/3p4/8/4P3/8/8/8/K7 b - - 0 1")
	check(play(g,"d7","d5") and legal(g,"e5","d6"),"Double step enables immediate en passant")
	check(play(g,"e5","d6") and g.board.at(square("d5")) == null and g.board.units.size() == 3,"En passant removes passed pawn")
	g = position("7k/3p4/8/4P3/8/8/8/K7 b - - 0 1")
	check(play(g,"d7","d5") and play(g,"a1","b1") and play(g,"h8","g8"),"En passant can be declined")
	check(not legal(g,"e5","d6"),"En passant expires after the immediate reply")
	g = position("7k/8/8/r4pPK/8/8/8/8 w - f6 0 1")
	check(not legal(g,"g5","f6"),"En passant may not expose king through both disappearing blockers")
	g = position("7k/8/8/8/3pP3/8/8/K7 b - e3 0 1")
	check(play(g,"d4","e3") and g.board.at(square("e4")) == null,"Black en passant works too")

func test_promotion() -> void:
	for id in MovementRules.PROMOTIONS:
		var g := position("7k/P7/8/8/8/8/8/7K w - - 0 1")
		check(not play(g,"a7","a8") and g.turn == 0,"Promotion requires explicit choice without consuming turn")
		check(not play(g,"a7","a8","guard"),"Promotion to king rejected")
		check(play(g,"a7","a8",id),"All four promotion choices work")
		check(g.board.at(square("a8")).chess_type == MovementRules.PROMOTIONS[id] and g.board.units.size() == 3,"Promotion replaces pawn, creates no extra unit")
		check(not g.board.at(square("a8")).castle_eligible,"Promoted rook gains no castling rights")
	var g := position("1r5k/P7/8/8/8/8/8/7K w - - 0 1")
	check(play(g,"a7","b8","cavalry") and g.board.units.size() == 3,"Capture and underpromotion in one move")

func test_outcomes() -> void:
	var g := GameManager.new(catalog)
	check(play(g,"f2","f3") and play(g,"e7","e5") and play(g,"g2","g4") and play(g,"d8","h4"),"Fool's mate sequence accepted")
	check(g.finished and g.winner == 1 and g.result_reason == "Schachmatt","Checkmate ends game for attacking side")
	check(g.board.king(0) != null and g.board.king(1) != null,"Both kings remain after mate")
	check(not play(g,"a2","a3") and not g.resign(1),"Terminal result cannot be overwritten")
	g = position("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	g.update_outcome()
	check(g.finished and g.winner == -1 and g.result_reason == "Patt","No moves without check is stalemate, not a win")
	g = GameManager.new(catalog)
	check(g.resign(0) and g.finished and g.winner == 1 and g.result_reason == "Aufgabe","Resignation awards opponent a win")
	check(g.board.units.size() == 32,"Resignation never removes king or army")

func test_perft() -> void:
	var g := GameManager.new(catalog)
	check(perft(g.board,0,1) == 20,"Start position perft(1)=20")
	check(perft(g.board,0,2) == 400,"Start position perft(2)=400")
	check(perft(g.board,0,3) == 8902,"Start position perft(3)=8902")
	g = position("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	check(perft(g.board,0,1) == 48,"Kiwipete perft(1)=48")
	check(perft(g.board,0,2) == 2039,"Kiwipete perft(2)=2039, castling and pins")
	g = position("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
	check(perft(g.board,0,3) == 2812,"Rook/pawn endgame perft(3)=2812, en passant and king exposure")

func test_ai() -> void:
	var g := GameManager.new(catalog)
	for _index in range(80):
		if g.finished:
			break
		var side := g.turn
		var count := g.ply_count
		check(TacticalAI.act(g),"AI always finds a legal reply when moves exist")
		check(g.ply_count == count+1 and g.turn == 1-side,"AI consumes exactly one ply")
		check(not g.in_check(side),"AI never leaves own king in check")
		check(g.board.king(0) != null and g.board.king(1) != null,"AI never captures either king")
