extends Node2D

@export var quest_template: Quest
var next_levels: Array[Node]
var _q: Quest
@onready var world_animation: AnimationPlayer = $WorldAnimation

signal enter_scene

func _ready() -> void:
	if world_animation: 
		world_animation.play("fade_in")
	
	var player = GameManager.player
	if not player:
		return
	
	get_tree().current_scene.add_child(player)
	
	if not GameManager.from_level:
		var current_level_name: String = self.name
		var regex : RegEx = RegEx.new()
		regex.compile(r"\d+")
		var result := regex.search(current_level_name)
		
		if not result: return
		
		var level_num : int = result.get_string() as int
		level_num = max(0, level_num -1)
		GameManager.from_level = current_level_name.substr(0, result.get_start()) + str(level_num) + current_level_name.substr(result.get_end())
		if not GameManager.from_level: return
	
	var spawn = get_node_or_null("%sPos" % GameManager.from_level)
	
	player.global_position = spawn.global_position
	
	_q = quest_template.duplicate(true) as Quest
	_q.quest_id = "%s_%s" % [_q.quest_id, get_tree().current_scene.name]
	
	
	#EventBus.game_event.emit(&"level_entered", {"name": name})
	
	ObjectiveManager.add_quest(_q)
	ObjectiveManager.start(_q.quest_id)
	
	await get_tree().process_frame
	ObjectiveManager.bind_dynamic_targets(_q, self)
	
	next_levels = get_tree().get_nodes_in_group("LevelChanger")
	if not next_levels:
		return
	
	for exit in next_levels:
		if not exit.has_signal("change_scene"): continue #Se il segnale non esiste continua 
		if exit.change_scene.is_connected(_on_livello_change_scene): continue #Se il segnale è già connesso continua 
		
		exit.change_scene.connect(_on_livello_change_scene)

func _on_livello_change_scene(ack: Callable) -> void:
	if world_animation: 
		world_animation.play("fade_out")
		await world_animation.animation_finished
	
	ack.call()
