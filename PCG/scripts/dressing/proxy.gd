extends Node
class_name AtlasToScene

@export var atlas_source_id: int
@export var target: TileMapLayer
@onready var generator: WFC2DGenerator = $"../generator"

var spawn_scenes: Dictionary = {
	Vector2i(1, 0): preload("res://Scenes/Object/Lamp0.tscn"),
	Vector2i(2, 0): preload("res://Scenes/Object/Lamp1.tscn"),
}

func _ready() -> void:
	if generator == null: return
	
	generator.done.connect(_on_generator_done)

func _on_generator_done() -> void:
	await _replace_proxy_with_scenes()
	
func _replace_proxy_with_scenes() -> void:
	if target == null: return 
	
	for to_replace in spawn_scenes.keys():
		for tile in target.get_used_cells_by_id(atlas_source_id, to_replace):
			var scene = spawn_scenes.get(to_replace).instantiate()
			scene.global_position = (tile * target.tile_set.tile_size) + target.tile_set.tile_size/2
			
			target.set_cell(tile, -1)
			get_parent().add_child(scene)
