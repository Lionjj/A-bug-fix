# res://pcg/debug/FreeCam2D.gd
extends Camera2D

@export var move_speed := 800.0
@export var boost := 2.5
@export var zoom_step := 0.1
@export var min_zoom := 0.2
@export var max_zoom := 3.0

var dragging := false
var last_mouse := Vector2.ZERO

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			last_mouse = get_global_mouse_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = Vector2(clamp(zoom.x - zoom_step, min_zoom, max_zoom),
						   clamp(zoom.y - zoom_step, min_zoom, max_zoom))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = Vector2(clamp(zoom.x + zoom_step, min_zoom, max_zoom),
						   clamp(zoom.y + zoom_step, min_zoom, max_zoom))
	elif event is InputEventMouseMotion and dragging:
		var now := get_global_mouse_position()
		var delta := (now - last_mouse)
		position -= delta
		last_mouse = now

func _process(delta):
	var s = move_speed * delta * (boost if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  dir.y += 1
	position += dir * s
	
