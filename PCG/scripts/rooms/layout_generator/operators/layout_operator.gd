# ============================================================================
# LayoutOperator
# ============================================================================
## Operatore di shape grammar.
## Applica una trasformazione locale alla RoomLayoutMask.
## Deve essere:
## - stateless
## - fallibile
## - rollback-safe
# ============================================================================

class_name LayoutOperator
extends RefCounted

## Applica l'operatore alla mask.
## Ritorna true se applicato con successo, false se non applicabile.
func apply(mask: RoomLayoutMask, context: LayoutContext) -> bool:
	push_error("LayoutOperator.apply() not implemented")
	return false

func _carve_rect_transaction(
	mask: RoomLayoutMask,
	rect: Rect2i
) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.is_solid(x, y):
				mask.set_solid(x, y)
				changed.append(Vector2i(x, y))

	return changed

func _rollback(mask: RoomLayoutMask, cells: Array[Vector2i]) -> void:
	for c in cells:
		mask.set_empty(c.x, c.y)
