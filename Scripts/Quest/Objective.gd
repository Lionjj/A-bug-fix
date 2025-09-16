extends Resource
class_name Objective

@export var id: StringName
@export var descrizione := ""
@export var tipo := "counter"               # "counter" | "flag"
@export var evento: StringName = &""
@export var target := 1
@export var progress := 0
@export var completato := false

# --- BIND DINAMICO (opzionale) ---
# Esempio: "/root/GameManager:enemy_num"
@export var dynamic_target_path: String = ""     # "<Nodo>:<Proprieta>"
# Esempio: "enemy_count_changed" su quel nodo; se impostato, aggiorna il target quando emesso
@export var dynamic_target_signal: StringName = &""
# Blocca l’aggiornamento del target alla **prima progressione** (es. dopo la prima kill)
@export var dynamic_lock_on_first_progress := true
# Se true, il target segue il **picco** massimo; se false, riassegna ogni volta
@export var dynamic_track_peak := true

# Objective.gd
func apply_event(ev: StringName, payload := {}) -> bool:
	if completato or ev != evento:
		return false

	var changed := false

	match tipo:
		"counter":
			var before := progress
			progress = min(progress + int(payload.get("amount", 1)), target)
			if progress != before:
				changed = true
			if progress >= target and not completato:
				completato = true
				changed = true

		"flag":
			if not completato:
				completato = true
				changed = true

	return changed
