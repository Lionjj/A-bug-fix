extends Control

@onready var mouse_anim = $MouseAnimation
@onready var modal_anim = $ModalOpening

@onready var modal_sprite = $Modal
@onready var dir2_sprite = $Directory2
@onready var dir3_sprite = $Directory3
@onready var exe_sprite = $Exe

@onready var lable_explorer = $explorer
@onready var lable_dir2 = $Dir2
@onready var lable_die3 = $Dir3
@onready var lable_name = $ABugFix
@onready var xbtn_sprite = $XBtn
@onready var notification = $Notification


func _ready() -> void:
	mouse_anim.play("wind_open")
	await mouse_anim.animation_finished
	
	mouse_anim.play("click_modal")
	await mouse_anim.animation_finished
	
	modal_sprite.visible = true
	modal_anim.play("open")
	await modal_anim.animation_finished
	
	lable_explorer.visible = true
	lable_dir2.visible = true
	lable_die3.visible = true
	lable_name.visible = true
	xbtn_sprite.visible = true
	dir2_sprite.visible = true
	dir3_sprite.visible = true
	exe_sprite.visible = true
	
	mouse_anim.play("click_exe")
	await mouse_anim.animation_finished
	
	var anim_notification = notification.get_node("AnimationPlayer")
	notification.visible = true
	anim_notification.play("show")
	
	await  get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/WorldScenes/Livello0.tscn")
	
	
	
	
