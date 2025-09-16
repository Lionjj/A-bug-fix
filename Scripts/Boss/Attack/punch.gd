extends Area2D

@export var damage :int


@export var drop_speed: float = 400.0
@export var wave_scene: PackedScene

@onready var rayGround = $RayCast2D
signal punch_hit_ground(global_pos: Vector2)
var is_dropping := false
var ground_pos;

func _ready():
	$AnimationPlayer.play("preper_attack")
	await $AnimationPlayer.animation_finished
	
	is_dropping = true
	rayGround.enabled = true
	
	$AnimationPlayer.play("move")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(damage)
		
func _physics_process(delta):
	
	if is_dropping:
		position.y += drop_speed * delta   # movimento verso il basso

		# controlla il terreno con il RayCast
		if rayGround.is_colliding():
			is_dropping = false
			
			ground_pos = rayGround.get_collision_point()
			
			emit_signal("punch_hit_ground", global_position)
			_on_impact()

func _on_impact():
	# Effetti ll'impatto: suon, shacke della telecamere, ecc..
	$AnimationPlayer.play("impact")
	$Sprite2D.modulate = Color(1, 0.8, 0.8)  # flash all’impatto
	
	var camera = get_tree().get_first_node_in_group("PlayerCamera")
	if camera:
		camera.shake(10.0, 6.0)   # intensità e decay
	
	if wave_scene:
		spawn_wave(-1, ground_pos)  # sinistra
		spawn_wave(1, ground_pos)   # destra
		
	await $AnimationPlayer.animation_finished
	queue_free()

func spawn_wave(dir: int, ground_pos: Vector2):
	var wave = wave_scene.instantiate()
	wave.global_position = ground_pos + Vector2(0, -5)
	wave.direction = dir
	get_tree().current_scene.add_child(wave)
