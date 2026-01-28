extends TrapEntity
@onready var notifier: DinamicNotifier = $VisibleOnScreenNotifier2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if not body.get_invicible():
			CombatMechanic.applay_knockback(body, global_position, 1200, .08)
		body.take_damage(damage)
		
func _ready() -> void:
	var texture: Texture2D = $AnimatedSprite2D.sprite_frames.get_frame_texture("default", 0)
	notifier.set_up(texture.get_size())
	notifier.screen_entered.connect(_on_enter)
	notifier.screen_exited.connect(_on_exit)
	var frames = $AnimatedSprite2D.sprite_frames.get_frame_count("default")
	$AnimatedSprite2D.set_frame_and_progress(randi() % frames, randf())

func _on_enter():
	activate(true)

func _on_exit():
	activate(false)
	
func activate(value: bool):
	$CollisionShape2D.visible = value
	$AnimatedSprite2D.visible = value
	$PointLight2D.visible = value
	$PointLight2D.enabled = value
