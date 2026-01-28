class_name TileMapUtility

static func merge_tile_map_layer(
	level: Node,
	rooms: Array[RoomTemplateMeta] = []
) -> TileMapLayer:
	var rooms_copy: Array[RoomTemplateMeta] = rooms.duplicate()
	if rooms.is_empty():
		rooms_copy = get_rooms(level)
	
	var final: TileMapLayer = _get_or_create_final_layer(level)
	
	var source: Array[TileMapLayer] = _get_all_collison(rooms_copy)
	if source.is_empty():
		push_error("La lista di collsioni delle stanze è vuota!")
		return final
	
	var corridor: TileMapLayer = _get_corriodr(level)
	if corridor == null:
		push_error("Il layer del corridoio non è nello scene_tree!")
		return final
	
	source.append(corridor)
	final.clear()
	
	if final.tile_set == null: final.tile_set = source[0].tile_set
	
	_merge_tile(source, final)
	
	return final


static func _get_or_create_final_layer(level: Node, final_layer_name: NodePath = "Final") -> TileMapLayer:
	var out: TileMapLayer = level.get_node_or_null(final_layer_name) as TileMapLayer
	if out != null: return out
	
	out = TileMapLayer.new()
	out.name = String(final_layer_name)
	level.add_child(out)
	out.owner = level
	return out
	
static func _get_all_collison(rooms: Array[RoomTemplateMeta]) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	
	for room: RoomTemplateMeta in rooms: out.append(room.collision)
	
	return out

static func get_rooms(level: Node, 	room_group: StringName = &"rooms") -> Array[RoomTemplateMeta]:
	var out: Array[RoomTemplateMeta] = []
	
	for node: Node in level.get_tree().get_nodes_in_group(room_group):
		var room: RoomTemplateMeta = node as RoomTemplateMeta
		if room == null: continue
		
		out.append(room)
	
	return out

static func _get_corriodr(level: Node, corridor_group: StringName = &"corridor") -> TileMapLayer:
	var out: TileMapLayer = null
	out = level.get_tree().get_first_node_in_group(corridor_group) as TileMapLayer
	
	if out != null: return out
	
	out = level.get_node_or_null(CorridorBuilder.TM_CORRIDOR) as TileMapLayer
	if out != null: return out
	
	return out

static func _merge_tile(
	sources: Array[TileMapLayer], 
	final: TileMapLayer, 
	overwrite_existing: bool = true
) -> void:
	
	for layer: TileMapLayer in sources:
		if layer == null: continue
		
		if layer.tile_set == null: continue

		for src_cell: Vector2i in layer.get_used_cells():
			var src_id : int = layer.get_cell_source_id(src_cell)
			if src_id == -1: continue

			var atlas: Vector2i = layer.get_cell_atlas_coords(src_cell)
			var alt: int = layer.get_cell_alternative_tile(src_cell)

			# src cell -> world (centro cella, stabile)
			var src_local: Vector2 = layer.map_to_local(src_cell)
			var world: Vector2 = layer.to_global(src_local)

			# world -> final cell
			var final_local: Vector2 = final.to_local(world)
			var dst_cell: Vector2i = final.local_to_map(final_local)

			if not overwrite_existing and final.get_cell_source_id(dst_cell) != -1:
				continue

			final.set_cell(dst_cell, src_id, atlas, alt)
		
		layer.visible = false
