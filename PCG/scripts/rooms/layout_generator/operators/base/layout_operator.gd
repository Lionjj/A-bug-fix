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

enum Type {DEFAULT, DIVIDER, RING, SPLIT_CORNER, INDENT, PILLAR, PLATFORM}
enum Role {DEFAULT, PRIMARY, SECONDARY}

var type: Type = Type.DEFAULT

var role: Role = Role.DEFAULT:
	get:
		return role

## Peso dell'operatore (valori compresi tra 0.0 e 1.0)
var weight: float = 0.0:
	set(w):
		weight = clampf(w, 0.0, 1.0)


## Applica l'operatore alla mask.
## Ritorna true se applicato con successo, false se non applicabile.
func apply(mask: RoomLayoutMask, context: LayoutContext, params: Dictionary) -> bool:
	push_error("LayoutOperator.apply() not implemented")
	return false

func create_random_params(rng: RandomNumberGenerator, profile: RoomSizeProfile) -> Dictionary:
	push_error("create_random_params non implementato")
	return {}

func mutate_params(params: Dictionary, rng: RandomNumberGenerator, profile: RoomSizeProfile) -> void:
	push_error("mutate_params non implementato")

func _carve_rect_transaction(
	mask: RoomLayoutMask,
	rect: Rect2i
) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if mask.is_solid(x, y):
				mask.set_empty(x, y)
				changed.append(Vector2i(x, y))

	return changed
 
func _rollback(mask: RoomLayoutMask, cells: Array[Vector2i]) -> void:
	for c in cells:
		mask.set_empty(c.x, c.y)
