extends Node2D
class_name DecorationEntity

## Offset da applicare quando l'oggetto viene istanziato in scena
@export var spawn_offset: Vector2 = Vector2.ZERO

var decoration_type: Decoration.DECO_TYPE = Decoration.DECO_TYPE.GROUND
var sprite_2d_name: String = "Sprite2D"
var footprint_cells: int = 1
var sprite: Sprite2D = null

func _ready() -> void:
	spawn_offset = _compute_anchor_offset()
	footprint_cells = compute_footprint_cells()

func set_type(type: Decoration.DECO_TYPE):
	decoration_type = type

func get_spawn_offset() -> Vector2: 
	if spawn_offset != Vector2.ZERO: return spawn_offset
	
	spawn_offset = _compute_anchor_offset()
	return spawn_offset

func _compute_anchor_offset() -> Vector2:
	sprite = get_node_or_null(sprite_2d_name)
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO

	# Rect del disegno in coordinate locali del nodo Sprite2D
	var r: Rect2 = sprite.get_rect()

	# Applica la scala del nodo sprite (get_rect NON include scale)
	r.position *= sprite.scale
	r.size *= sprite.scale

	# r.position è l'angolo alto-sinistra del disegno
	# bottom_local = r.position.y + r.size.y
	# top_local = r.position.y

	match decoration_type:
		Decoration.DECO_TYPE.GROUND:
			# Voglio che il BORDO INFERIORE del disegno tocchi il punto di contatto (y=0)
			var bottom_local := r.position.y + r.size.y
			return Vector2(0.0, -bottom_local)

		Decoration.DECO_TYPE.CEILING:
			# Voglio che il BORDO SUPERIORE del disegno tocchi il punto di contatto (y=0)
			var top_local := r.position.y
			return Vector2(0.0, -top_local)

		_:
			return Vector2.ZERO

func compute_footprint_cells(tile_size: Vector2i = Vector2i(16, 16)) -> int:
	var sprite: Sprite2D = get_node_or_null(sprite_2d_name)
	if sprite == null or sprite.texture == null:
		return 1

	var tile_w : float = float(tile_size.x)
	if tile_w <= 0.0:
		return 1

	# Rect del disegno in coordinate locali del nodo Sprite2D
	var r: Rect2 = sprite.get_rect()

	# get_rect non include scale: applicala
	var sx : float = abs(sprite.scale.x)
	r.position.x *= sx
	r.size.x *= sx

	# Larghezza reale in pixel
	var w_px : float = max(1.0, float(r.size.x))

	# celle richieste
	var cells : int = int(ceil(w_px / tile_w))

	# forza dispari (1,3,5...) per simmetria
	if cells % 2 == 0:
		cells += 1

	return max(1, cells)

func prepare_for_spawn() -> void:
	pass
