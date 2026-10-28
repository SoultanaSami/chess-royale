class_name SiegeAI
extends RefCounted
## Uses the exact same commands and costs as the player. Terrain BFS guides
## long-range movers toward bridges/mines rather than straight into rivers.
static func choose(game: TacticalMatch) -> Dictionary:
	var side := game.turn
	if not game.can_act(side):
		return {}
	var options := TacticalCommands.actions(game.board, side, game.reserves[side], game.gold[side], game.catalog)
	if options.is_empty():
		return {}
	var search: SiegeSearch = game.searches[side]
	if search != null and search.done and search.defensible and not search.solution.is_empty():
		var defense: Dictionary = search.solution[0]
		if TacticalCommands.legal(game.board, defense, side, game.reserves[side], game.gold[side], game.catalog):
			return defense
	var fields := {}
	for role in ["PAWN","KNIGHT","BISHOP","ROOK","QUEEN"]:
		fields[role] = objective_distances(game.board, side, role)
	var best: Dictionary = {}
	var best_score := -INF
	var own_count := 0
	for unit in game.board.units.values():
		if unit.team == side: own_count += 1
	for action in options:
		var next := game.board.copy(false)
		TacticalCommands.apply(next, action, side, game.reserves[side], game.catalog)
		var score := 0.0
		score -= TacticalCommands.threats(next, side).size() * 250.0
		score += TacticalCommands.threats(next, 1 - side).size() * 110.0
		if action.kind == "deploy":
			var data := game.catalog.get_unit(game.reserves[side][action.slot])
			score += (20.0 if own_count < 7 else 3.0) + data.resource_cost * .5
			score -= float(fields[data.chess_type()].get(action.to, 1000)) * .05
		else:
			var origins: Array = action.cells if action.kind == "formation" else [action.from]
			for from in origins:
				var to: Vector2i = from + Vector2i(-1 if side == 0 else 1, 0) if action.kind == "formation" else action.to
				var victim := game.board.at(to)
				if victim != null:
					score += 70.0 + victim.definition.resource_cost * 12.0
				if action.kind == "shoot":
					continue
				var distances: Dictionary = fields[game.board.at(from).chess_type]
				score += (float(distances.get(from, 1000)) - float(distances.get(to, 1000))) * 3.5
				for anchor in game.board.objectives(BattlefieldTileData.Terrain.RESOURCE_NODE):
					var ring := game.board.capture_ring(anchor)
					var owner := game.board.tile_at(anchor).owner
					if to in ring and owner != side:
						score += 55.0 if side not in game.board.ring_teams(anchor) else 6.0
					if from in ring and to not in ring and owner != side:
						score -= 45.0
				var mover := game.board.at(from)
				if mover.position_history.size() >= 2 and to == mover.position_history[-2]:
					score -= 18.0
				if MovementRules.attacked(next, to, 1 - side):
					score -= mover.definition.resource_cost * 4.0
		if score > best_score:
			best_score = score
			best = action
	return best

static func objective_distances(board: BoardState, side: int, role: String) -> Dictionary:
	var distance: Dictionary = {}
	var queue: Array[Vector2i] = []
	for anchor in board.objectives(BattlefieldTileData.Terrain.RESOURCE_NODE):
		var occupants := board.ring_teams(anchor)
		if board.tile_at(anchor).owner != side and not (occupants.size() == 1 and occupants[0] == side):
			for cell in board.capture_ring(anchor):
				if board.at(cell) == null or board.at(cell).team != side:
					queue.append(cell)
	if queue.is_empty():
		queue.append_array(board.footprint(TacticalCommands.castle(board, 1 - side)))
	for cell in queue:
		distance[cell] = 0
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		var steps: Array = MovementRules.LEAPS if role == "KNIGHT" else MovementRules.DIAGONAL if role == "BISHOP" else MovementRules.ORTHOGONAL + MovementRules.DIAGONAL if role == "QUEEN" else [Vector2i(1 if side == 0 else -1,0)] if role == "PAWN" else MovementRules.ORTHOGONAL
		for step in steps:
			var neighbor: Vector2i = cell + step
			if board.can_enter(neighbor) and not distance.has(neighbor) and (role == "KNIGHT" or TacticalMovement.can_step(board, neighbor, cell, role, true)):
				distance[neighbor] = distance[cell] + 1
				queue.append(neighbor)
	return distance
