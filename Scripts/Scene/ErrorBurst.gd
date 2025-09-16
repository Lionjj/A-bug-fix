extends Control
class_name VirusPopups

@export var popup_scene: PackedScene
@export var max_windows := 120
@export var spawn_rate := 25.0          # finestre al secondo
@export var burst_duration := 2.5       # durata dello spam (s)
@export var cascade_offset := Vector2(20, 18)
@export var allow_random_rotation := true

var _elapsed := 0.0
var _spawn_acc := 0.0
var _count := 0
var _casc_start := Vector2(80, 60)

func start_burst(duration : float = burst_duration, rate : float = spawn_rate):
	_elapsed = 0.0
	_spawn_acc = 0.0
	_count = 0
	set_process(true)
	burst_duration = duration
	spawn_rate = rate

func _ready():
	set_process(false) # parte solo quando chiami start_burst()

func _process(delta):
	_elapsed += delta
	if _elapsed >= burst_duration or _count >= max_windows:
		set_process(false)
		return

	_spawn_acc += spawn_rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		_spawn_one()

func _spawn_one():
	if not popup_scene: return
	var w := popup_scene.instantiate() as Control
	add_child(w)

	# contenuto random
	w.randomize_content()

	# dimensioni e limiti schermo
	var vp := get_viewport_rect().size
	var size := w.size
	if size == Vector2.ZERO:
		size = Vector2(220, 120) # fallback

	# scegli: o posizione random, o cascata che "sfugge"
	var use_cascade := (randi() % 3 == 0) # 1/3 a cascata
	var pos := Vector2.ZERO
	if use_cascade:
		pos = _casc_start + cascade_offset * Vector2(_count % 12, _count % 12)
	else:
		pos = Vector2(
			randf_range(0, max(0.0, vp.x - size.x)),
			randf_range(0, max(0.0, vp.y - size.y))
		)

	# applica
	w.position = pos
	if allow_random_rotation:
		w.rotation = deg_to_rad(randf_range(-3, 3))
	w.z_index = 100 + _count

	w.pop_in()
	if (randi() % 2) == 0:
		w.tiny_shake()

	_count += 1

func close_all():
	for c in get_children():
		if c is Control:
			c.queue_free()
