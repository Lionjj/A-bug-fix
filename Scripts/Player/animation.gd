extends AnimationPlayer

@onready var sprite = get_parent().get_node("Sprite2D")
@onready var manage_attack = $"../AttackArea"

var direction := 1  # 1 = destra, -1 = sinistra
#func update_animation(is_on_floor: bool, velocity: Vector2):
	## Controlla animazione movimento
	#if attacking == false:
		#if is_on_floor:
			#if abs(velocity.x) > 0:
				#play("run")
			#else :
				#play("idle")
		#else:
			#if velocity.y < 0:
				#play("jump")
			#else: 
				#play("fall")
	#switch_direction(velocity)

func switch_direction(velocity: Vector2):
	if velocity.x != 0:
		direction = sign(velocity.x)
		sprite.flip_h = direction < 0
		sprite.position.x = direction * 4
		
		manage_attack.scale.x = direction
		
