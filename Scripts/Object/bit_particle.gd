extends Node2D

func _ready():
	# Avvia entrambe le emissioni
	$Bit0Particles.emitting = true

	# Timer per autodistruzione
	await get_tree().create_timer(1.5).timeout
	queue_free()
