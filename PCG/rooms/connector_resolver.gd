# ConnectorResolver.gd
extends Node
class_name ConnectorResolver

const TILE := 16

# DTO semplice (Port)
class Port:
	var axis: String               # "N","E","S","W"
	var pos: Vector2i              # posizione in tile
	var offset_up := 0
	var offset_down := 0
	var offset_left := 0
	var offset_right := 0
	var corridor_height := 1
	var clearance_top := 0
	var clearance_bottom := 0
	var vertical_offset_from_marker := 0

	static func from_defaults(axis:String, pos:Vector2i) -> Port:
		var p := Port.new()
		p.axis = axis
		p.pos = pos
		return p

# Restituisce una mappa {"N":Port, "E":Port, ...} solo per i connettori attivi
func resolve_ports(room: Node) -> Dictionary:
	var result := {}
	var connectors := room.get("connectors")
	var names := room.get("CONNECTOR_NAMES")
	var size_tiles: Vector2i = room.get("size_tiles") if room.has_method("get") else Vector2i(80,48)

	for dir in ["N","E","S","W"]:
		if connectors is Dictionary and connectors.get(dir, false):
			var node_name := (names.get(dir, "") if names is Dictionary else "")
			var marker := room.get_node_or_null(node_name) if node_name != "" else null
			var port := _build_port_from_marker_or_fallback(dir, marker, room, size_tiles)
			result[dir] = port
	return result

func _build_port_from_marker_or_fallback(dir:String, marker: Node, room: Node, size_tiles: Vector2i) -> Port:
	if marker != null:
		# Se il marker ha RoomConnector.gd
		if marker is Node and marker.has_method("tile_pos"):
			var port := Port.new()
			port.axis = (marker.get("axis") if marker.has_method("get") else dir)
			port.pos = marker.tile_pos()

			# Leggi i parametri export se presenti
			for k in ["offset_up","offset_down","offset_left","offset_right",
					  "corridor_height","clearance_top","clearance_bottom",
					  "vertical_offset_from_marker"]:
				if marker.has_variable(k):
					port.set(k, marker.get(k))
			return port

		# Marker senza script: usa posizione da global_position e default
		var p := marker.global_position.snapped(Vector2(TILE, TILE))
		return Port.from_defaults(dir, Vector2i(int(p.x)/TILE, int(p.y)/TILE))

	# Nessun marker: fallback stimato sul bordo stanza (centro lato)
	match dir:
		"N":
			return Port.from_defaults("N", Vector2i(size_tiles.x/2, 0))
		"S":
			return Port.from_defaults("S", Vector2i(size_tiles.x/2, size_tiles.y-1))
		"E":
			return Port.from_defaults("E", Vector2i(size_tiles.x-1, size_tiles.y/2))
		"W":
			return Port.from_defaults("W", Vector2i(0, size_tiles.y/2))
	return Port.from_defaults(dir, Vector2i.ZERO)
