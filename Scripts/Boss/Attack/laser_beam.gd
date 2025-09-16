extends Node2D
class_name LaserBeam

@export var width: float = 12.0          # spessore visivo + collisione
@export var damage: int = 15
@export var speed: float = 600.0         # px/s
@export var windup: float = 0.6          # telegraph prima di attivarsi
@export var lifetime_padding: float = 0.3 # tempo extra dopo l’uscita

@onready var dmg_area: Area2D = $Area2D
@onready var shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var laser: Line2D = $Line2D
@onready var tele: Line2D = $Line2D2
@onready var vis: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _dir := Vector2.RIGHT          # direzione di movimento
var _arena_height := 480.0         # altezza del raggio (adatta alla tua arena)
var _active := false

signal hit(body)

func setup(start_pos: Vector2, dir: int, arena_height: float, speed_px_s: float, dmg: int, windup_sec: float, thickness: float) -> void:
	# dir: +1 = sinistra→destra, -1 = destra→sinistra
	global_position = start_pos
	_dir = Vector2(dir, 0)
	arena_height = max(1.0, arena_height)
	_arena_height = arena_height
	if speed_px_s > 0: speed = speed_px_s
	if dmg > 0: damage = dmg
	if windup_sec >= 0.0: windup = windup_sec
	if thickness > 0.0: width = thickness

	# Disegno linee verticali (due Line2D: telegraph e laser)
	var half = _arena_height * 0.5
	tele.clear_points()
	tele.width = width
	tele.default_color = Color(1, 0.6, 0.2, 0.55)  # arancio semi-trasp
	tele.add_point(Vector2(0, -half))
	tele.add_point(Vector2(0, +half))

	laser.clear_points()
	laser.width = width
	laser.default_color = Color(1, 0.1, 0.05, 1.0) # rosso pieno
	laser.add_point(Vector2(0, -half))
	laser.add_point(Vector2(0, +half))
	laser.visible = false

	# Collisione verticale centrata
	var r := RectangleShape2D.new()
	r.size = Vector2(width, _arena_height)
	shape.shape = r
	dmg_area.monitoring = false  # attivo solo dopo il windup

	# Start telegraph → poi attivo
	_start_sequence()

func _start_sequence() -> void:
	_active = false
	# piccolo flash/telegrafo; poi accendo
	var t := create_tween()
	t.tween_property(tele, "modulate:a", 0.25, windup).from(0.75)
	t.finished.connect(func():
		laser.visible = true
		tele.visible = false
		dmg_area.monitoring = true
		_active = true)

func _physics_process(delta: float) -> void:
	if not _active: return
	global_position += _dir * speed * delta

func _ready() -> void:
	# Danno a contatto
	dmg_area.body_entered.connect(_on_body_entered)
	dmg_area.area_entered.connect(_on_area_entered)
	# Cleanup quando completamente fuori dallo schermo
	vis.screen_exited.connect(func():
		await get_tree().create_timer(lifetime_padding).timeout
		queue_free())

func _on_body_entered(b: Node) -> void:
	_apply_damage(b)

func _on_area_entered(a: Area2D) -> void:
	# se i colpi del player sono aree, puoi ignorarle o gestirle
	if a.is_in_group("player"): _apply_damage(a)

func _apply_damage(n: Node) -> void:
	if not _active: return
	if n.is_in_group("player"):
		if n.has_method("take_damage"): n.take_damage(damage)
		hit.emit(n)
