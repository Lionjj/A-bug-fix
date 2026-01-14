## Modulo usato per la creazione degli obbiettivi per le [Quest],
extends Resource
class_name Objective

## Identificativo univoco dell'obbiettivo.
@export var id: StringName
## Descrizione dell'obbiettivo che verrà mostrato al giocatore.
@export var descrizione := ""
## Tipo di obbiettivo.
@export var tipo : String = "counter"               # "counter" | "flag"
## Nome dell'evento che deve essere intercettato affinché l’obiettivo possa avanzare.
@export var evento: StringName = &""
## Valore da raggiungere per completare l’obiettivo (solo per tipo "counter").
@export var target : int = 1
## Avanzamento corrente dell’obiettivo.
@export var progress : int = 0
## True se l'obiettivo è stato completato.
@export var completato : bool = false

# --- BIND DINAMICO (opzionale) ---
# Esempio: "/root/GameManager:enemy_num"
@export var dynamic_target_path: String = ""     # "<Nodo>:<Proprieta>"
# Esempio: "enemy_count_changed" su quel nodo; se impostato, aggiorna il target quando emesso
@export var dynamic_target_signal: StringName = &""
# Blocca l’aggiornamento del target alla **prima progressione** (es. dopo la prima kill)
@export var dynamic_lock_on_first_progress := true
# Se true, il target segue il **picco** massimo; se false, riassegna ogni volta
@export var dynamic_track_peak := true

func apply_event(ev: StringName, payload := {}) -> bool:
	if completato or ev != evento:
		return false

	var changed : bool = false

	match tipo:
		"counter":
			var before : int = progress
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
