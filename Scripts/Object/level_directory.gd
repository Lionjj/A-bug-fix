extends Area2D
class_name Livello

@export var text = ""
@export var is_lock_visible : bool = false
@export var is_area_diasbled : bool = true
@export var unlockable: bool
@export var unlock_on_quest: StringName
var next_level: PackedScene

signal change_scene(ack: Callable)
signal proceed

signal close_level

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"): return
	if next_level == null: return
	
	var ack:= func (): proceed.emit()
	change_scene.emit(ack)
	
	
	set_deferred("monitoring", false)  # evita doppi trigger
	$AudioStreamPlayer2D.play()
	
	body.movement_enabled = false
	
	await proceed
	
	GameManager.from_level = get_parent().name
	var player = get_tree().current_scene.get_node_or_null("Player")
	GameManager.set_player(player)
	player.get_parent().remove_child(player)
	
	
	body.movement_enabled = true
	get_tree().change_scene_to_packed(next_level)
	

func _ready() -> void:
	var next_level_name = "res://Scenes/WorldScenes/%s.tscn" % self.name
	ObjectiveManager.quest_completed.connect(unlock)
	next_level = load(next_level_name)
	$Control/TitleLevel.text = text
	$Lock.visible = is_lock_visible
	$CollisionShape2D.disabled = is_area_diasbled
	unlock_on_quest = "%s_%s" % [unlock_on_quest, get_tree().current_scene.name]
	
	if is_lock_visible:
		close_level.emit()

func unlock(id: StringName) -> void:
	if not unlockable: return
	if not is_lock_visible: return 
	if id != unlock_on_quest: return

	$AnimationPlayer.play("Unlock")

func _on_close_level() -> void:
	$AnimationPlayer.play("lock")
	await $AnimationPlayer.animation_finished
