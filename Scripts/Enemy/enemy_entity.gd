## Modulo condiviso da tutte le categorie di nemici.
extends CharacterBody2D
class_name EnemyEntity

## Offset da applicare quando l'oggetto viene istanziato in scena
@export var spawn_offset: Vector2 = Vector2.ZERO

## Segnale emesso da nemico alla sua morte-
signal died(enemy: EnemyEntity)

## Specifica lo stato attivo/disattivo del nemico.
var _active: bool = true

## Funzione che attiva la fisica del nemico e lo mostra nella scena.
func show_entity() -> void:
	_set_active(true)

## Funzione che disattiva la fisica del nemico e lo nasconde nella scena.
func hide_entity() -> void:
	_set_active(false)

## Verifica se il nemcio è attivo.
func is_active() -> bool:
	return _active

## Funzione che attiva il nemico in base a [param active].
func _set_active(active: bool) -> void:
	## Cambia lo stato interno del nemico.
	_active = active
	## Lo rendo visibile in base allo stato.
	visible = active
	## Abilito/disabilito processi e fisica in base allo stato.
	set_process(active)
	set_physics_process(active)
	
	## Fermo/attivo il suo movimento.
	if not active:
		velocity = Vector2.ZERO

	## Disabilito le sue collsioni;
	_disable_collision(active)
	## Disabilito la logia interna;
	_disable_ai(active)
	## Disabilito aree o RayCast;
	_disable_sensors(active)
	## Disabilito le animazioni;
	_disable_animation(active)

	if active:
		_on_activated()
	else:
		_on_deactivated()

## Metodo da overridare nei figli che ereditano questa classe, questa funzione
## ha il compito di attivare tutti i nodi necessari per far funzionare la logica
## della classe ereditaria.
func _on_activated() -> void:
	pass

## Metodo da overridare nei figli che ereditano questa classe, questa funzione
## ha il compito di disattivare tutti i nodi necessari per far funzionare la logica
## della classe ereditaria.
func _on_deactivated() -> void:
	pass

## Metodo da overridare nei figli che ereditano questa classe, questa funzione
## ha il compito riportare alle impostazioni originarie tutti i nodi necessari 
## per far funzionare la logica della classe ereditaria.
func reset() -> void:
	pass

## Metodo chiamato quando un nemico viene sconfitto per gestire gli eventi che 
## ne susseguono.
func die() -> void:
	emit_signal("died", self)
	hide_entity()

## Metodo utilizzato per disabilitare/abilitare in base a [param active] le 
## evetuali collisioni.
func _disable_collision(active: bool) -> void:
	var collider: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null:
		collider.set_deferred("disabled", not active)

## Metodo utilizzato per disabilitare/abilitare in base a [param active] il 
## comportamento del nemico.
func _disable_ai(active: bool) -> void:
	var sm: Node = get_node_or_null("StateMachine")
	if sm != null:
		sm.set_process(active)
		sm.set_physics_process(active)

## Metodo da overridare utilizzato per disabilitare/abilitare in base a 
## [param active] aree, RayCast e altri sensori del nemico.
func _disable_sensors(active: bool) -> void:
	pass
	
## Metodo utilizzato per disabilitare/abilitare in base a [param active] le 
## animazioni del nemico.
func _disable_animation(active: bool) -> void:
	var anim: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null:
		if active: anim.play()
		else: anim.stop()
