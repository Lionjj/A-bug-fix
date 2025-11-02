# RoomConnector.gd
extends Marker2D
class_name RoomConnector

@export_enum("N","E","S","W") var axis: String = "E"

# Offset per aprire varchi larghi (in TILE)
@export var offset_up: int = 0
@export var offset_down: int = 0
@export var offset_left: int = 0
@export var offset_right: int = 0

# Spessore corridoio (in tile)
@export var thickness: int = 1

# Estetica: angoli/cappucci quando non poggia a pavimento/soffitto
@export var clearance_top: int = 0
@export var clearance_bottom: int = 0

# Piano di uscita relativo al marker (in tile; 0 = livello marker)
@export var vertical_offset_from_marker: int = 0

const TILE := 16
func tile_pos() -> Vector2i:
	var p := global_position.snapped(Vector2(TILE, TILE))
	return Vector2i(int(p.x)/TILE, int(p.y)/TILE)
