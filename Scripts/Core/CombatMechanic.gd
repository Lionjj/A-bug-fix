extends Node

func hit_stop(time_sclae: float, duration: float = 0.08) -> void:
	Engine.time_scale = time_sclae
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func applay_knockback(target: CharacterBody2D, source_global_position: Vector2, force: float, knockback_duration: float) -> void:
	var dir = (target.global_position - source_global_position).normalized()
	target.set_knockback(dir * force)
	target.set_knockback_timer(knockback_duration)
