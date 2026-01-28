extends Node

@export var level: WorldGen
@export var layout: TileMapLayer
@export var seed: int

@onready var main: AutoMapLayer = $main
@onready var decore: AutoMapLayer = $decore

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if layout == null: return
	main.layout = layout
	
	if level == null: return
	level.connect("final_layer_ready", _on_finisced)


func _on_finisced() -> void: 
	await main.update()
	await decore.update()
