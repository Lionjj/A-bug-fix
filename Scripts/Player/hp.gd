# res://Scripts/Player.gd
extends Node

@export var max_hp: int = 5
var current_hp: int

signal died
signal hp_changed(current, max)

func  _ready():
	current_hp = max_hp

func take_damage(amount):
	current_hp -= amount
	hp_changed.emit(current_hp, max_hp)
	print("Player Health: ", current_hp)
	$AnimatedSprite2D.play("death")
	if current_hp <= 0:
		die()

func die():
	died.emit()
	print("Game Over")
	$AnimatedSprite2D.play("death")
	queue_free()
