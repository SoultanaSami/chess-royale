class_name StartingArmy
extends RefCounted
## Fixed chess slots. Changing a variant never changes piece counts or starting squares.
static func formation(catalog: Catalog, deck: Array, side: int) -> Array[Dictionary]:
	assert(catalog.valid_deck(deck))
	var result: Array[Dictionary] = []
	for index in range(16):
		var row := (7 if index < 8 else 6) if side == 0 else (0 if index < 8 else 1)
		result.append({"id":deck[index],"cell":Vector2i(row,index%8)})
	return result
