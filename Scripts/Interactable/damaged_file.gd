extends Area2D

@export var interaction_key := "interact"   # mappa a "E" nelle InputMap
@export var repair_time := 1.5               # secondi necessari per riparare
@export var decay_when_released := true      # la barra scende se lasci il tasto
@export var decay_speed := 60.0              # % per secondo di discesa
@export var file_name : String

var player_in_area := false
var repaired := false
var progress := 0.0                          # 0..100

@onready var bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var hint: Label =  $VBoxContainer/Label   # opzionale, puoi rimuoverla
@onready var label_2: Label = $VBoxContainer2/Label2

func _ready():
	GameManager.file_num += 1
	label_2.text = file_name
	bar.visible = false
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	if hint:
		hint.visible = false

func _process(delta):
	$VBoxContainer2/Label2.text = file_name
	if repaired:
		return
	
	if player_in_area:
		# Mostra UI quando il giocatore è vicino
		if not bar.visible:
			bar.visible = true
		if hint and not hint.visible:
			hint.visible = true

		# Tieni premuto per riparare
		if Input.is_action_pressed(interaction_key):
			progress += (delta / repair_time) * 100.0
			$AnimationPlayer.play("Reparing")
		elif decay_when_released and progress > 0.0:
			$AnimationPlayer.play("IdleCorrupted")
			progress -= decay_speed * delta
	else:
		# Fuori dall’area: nascondi/decresci
		if decay_when_released and progress > 0.0:
			progress -= decay_speed * delta
		elif bar.visible and progress <= 0.0:
			bar.visible = false
			if hint:
				hint.visible = false

	progress = clamp(progress, 0.0, 100.0)
	bar.value = progress

	if progress >= 100.0:
		_on_repair_complete()

func _on_repair_complete():
	repaired = true
	bar.value = 100.0
	if hint:
		hint.text = "Struttura conforme"
	# Disattiva l’area per non riattivarla
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	# (Opzionali) effetti: animazioni, suono, shader, cambio sprite…
	# emit_signal("file_repaired")  # se vuoi avvisare altri nodi
	$AnimationPlayer.play("IdleClear")
	$AudioStreamPlayer2D.play()
	
	ObjectiveManager._on_game_event(&"file_corrupted", {"amount": 1})

# Collega questi due segnali dall’Inspector
func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_area = true

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_area = false

func _reset_conture():
	GameManager.file_num = 0
