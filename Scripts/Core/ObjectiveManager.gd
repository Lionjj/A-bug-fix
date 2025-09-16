extends Node

signal quest_started(quest_id: StringName)
signal quest_updated(quest_id: StringName)
signal quest_completed(quest_id: StringName)

var quests: Dictionary = {}             # id -> Quest
var quest_corrente: StringName = &""

# Connessioni dinamiche per quest (per cleanup)
var _dyn_bindings := {}                 # quest_id -> Array[Dictionary]

func _ready() -> void:
	EventBus.game_event.connect(_on_game_event)

func add_quest(q: Quest) -> void:
	quests[q.quest_id] = q

func start(quest_id: StringName) -> void:
	var q: Quest = quests.get(quest_id)
	if not q or q.attiva or q.completata: return
	q.attiva = true
	quest_corrente = quest_id
	quest_started.emit(quest_id)
	quest_updated.emit(quest_id)

func current_objective_text() -> String:
	var q: Quest = quests.get(quest_corrente)
	return "" if q == null else q.stato_testo()

func _on_game_event(ev: StringName, payload := {}) -> void:
	for q: Quest in quests.values():
		if not q.attiva or q.completata:
			continue
		var was_completed := q.completata
		if q.on_event(ev, payload):
			quest_updated.emit(q.quest_id)       
			if q.completata and not was_completed:
				quest_completed.emit(q.quest_id)

# --------------------------
# BIND DINAMICO, GENERICO
# --------------------------
func bind_dynamic_targets(q: Quest, level_root: Node) -> void:
	_disconnect_dyn(q.quest_id)
	_dyn_bindings[q.quest_id] = []

	# inizializza da proprietà
	for o in q.obiettivi:
		if o.tipo != "counter" or o.dynamic_target_path == "": continue
		_set_target_from_path(q, o, level_root)

		# se richiesto, segui un segnale (es. enemy_count_changed)
		if o.dynamic_target_signal != StringName():
			var data := _connect_signal_for_objective(q, o, level_root)
			if data != null:
				_dyn_bindings[q.quest_id].append(data)

	# blocca gli aggiornamenti alla prima progressione, se richiesto
	if q.obiettivi.any(func(x): return x.tipo == "counter" and x.dynamic_target_path != "" and x.dynamic_lock_on_first_progress):
		var lock_cb := func(id: StringName):
			if id != q.quest_id: return
			for d in _dyn_bindings[q.quest_id]:
				var obj: Objective = d.get("objective")
				if obj and obj.progress > 0 and obj.dynamic_lock_on_first_progress:
					var n: Node = d.get("node")
					var sig: String = d.get("sig")
					var cb = d.get("cb")
					if n and n.is_connected(sig, cb):
						n.disconnect(sig, cb)
		quest_updated.connect(lock_cb)
		_dyn_bindings[q.quest_id].append({"lock_cb": lock_cb})

func _set_target_from_path(q: Quest, o: Objective, level_root: Node) -> void:
	var parts := o.dynamic_target_path.split(":")
	if parts.size() != 2: return
	var node_path := parts[0]
	var prop := parts[1]
	var node: Node = null
	if node_path.begins_with("/root/"):
		node = get_node_or_null(node_path)
	else:
		node = level_root.get_node_or_null(node_path)
	if node == null: return
	var value := 0
	if node.has_method("get"): # property access
		value = int(node.get(prop))
	if o.dynamic_track_peak:
		o.target = max(o.target, value)
	else:
		o.target = value
	quest_updated.emit(q.quest_id)

func _connect_signal_for_objective(q: Quest, o: Objective, level_root: Node) -> Dictionary:
	var parts := o.dynamic_target_path.split(":")
	if parts.size() != 2: return {}
	var node_path := parts[0]
	var prop := parts[1]
	var node: Node = get_node_or_null(node_path) if node_path.begins_with("/root/") else level_root.get_node_or_null(node_path)
	if node == null: return {}

	var cb := func(_args = null):
		var value := int(node.get(prop))
		if o.dynamic_track_peak:
			o.target = max(o.target, value)
		else:
			o.target = value
		quest_updated.emit(q.quest_id)

	# NB: se il segnale emette argomenti numerici (es. count), puoi leggere da _args invece che dal prop
	node.connect(String(o.dynamic_target_signal), cb)
	return {"node": node, "sig": String(o.dynamic_target_signal), "cb": cb, "objective": o}

func _disconnect_dyn(quest_id: StringName) -> void:
	if not _dyn_bindings.has(quest_id): return
	for d in _dyn_bindings[quest_id]:
		if d.has("node"):
			var n: Node = d["node"]; var sig: String = d["sig"]; var cb = d["cb"]
			if n and n.is_connected(sig, cb):
				n.disconnect(sig, cb)
		elif d.has("lock_cb"):
			if quest_updated.is_connected(d["lock_cb"]):
				quest_updated.disconnect(d["lock_cb"])
	_dyn_bindings.erase(quest_id)
