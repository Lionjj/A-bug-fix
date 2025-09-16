extends Resource
class_name Quest

@export var quest_id: StringName
@export var titolo: String = ""
@export var descrizione: String = ""
@export var obiettivi: Array[Objective] = []
@export var attiva: bool = false
@export var completata: bool = false
@export var description_on_completate: String

func stato_testo() -> String:
	for o in obiettivi:
		if not o.completato:
			if o.tipo == "counter":
				return "%s (%d/%d)" % [o.descrizione, o.progress, o.target]
			return o.descrizione
	return description_on_completate

func on_event(ev: StringName, payload := {}) -> bool:
	if completata: return false
	var changed := false
	for o in obiettivi:
		if o.apply_event(ev, payload):
			changed = true
	completata = obiettivi.all(func(x): return x.completato)
	return changed
