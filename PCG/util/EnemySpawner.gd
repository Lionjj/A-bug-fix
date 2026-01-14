extends Marker2D

class_name EnemySpawners

@export var enemies: Dictionary[StringName, EnemySpwanOption]
@export var max_enemies: int = 3
@export var spawn_interval: float = 0.05

var difficulty: int = 1
var _current: int = 0
var _timer: float = 0.0

signal done

func _ready() -> void:
	var room: RoomTemplateMeta = get_parent() as RoomTemplateMeta
	if !room: return 
	
	var room_diff: int = room.difficulty
	
	difficulty = room_diff

func _physics_process(delta: float) -> void:
	if _current >= max_enemies: 
		emit_signal("done")
		return
	
	_timer -= delta
	if _timer <= 0.0:
		_spawn_enemy()
		_timer = spawn_interval
		

func _spawn_enemy() -> void:
	var kind: StringName = _chose_enemys()
	if kind == "": return 
	
	var e = enemies.get(kind).scene
	
	var istance = e.instantiate()
	istance.global_position = global_position
	get_tree().current_scene.add_child(istance)
	_current += 1

func _chose_enemys() -> StringName:
	if enemies.is_empty(): return ""
	var chosen :StringName
	var filtered: Array[Dictionary] = []
	
	#=== Filtra per difficoltà e calcola peso effettivo ===
	for option in enemies.keys():
		var enemy: EnemySpwanOption = enemies.get(option)
		if difficulty < enemy.min_difficulty: continue
		if difficulty > enemy.max_difficulty: continue
		
		var w : float = enemy.weight + enemy.extra_wight_per_leve * float(difficulty - enemy.min_difficulty)
		
		if w <= 0.0: continue
		
		filtered.append({
			"enemy": option,
			"weight": w
		})
	#======================================================
	
	if filtered.is_empty(): return ""
	
	#=== Scelta pesata ===
	var total_weight: float = 0.0
	for option in filtered:
		total_weight += option.get("weight")
		
	var r : float = Rng.randf() * total_weight
	
	for option in filtered:
		r -= option.get("weight")
		if r <= 0.0:
			return option.get("enemy") as StringName
	
	return filtered.back()["enmey"] as StringName
	
