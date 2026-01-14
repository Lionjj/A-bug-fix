## Questo modulo si occupa della creazione di missioni all'iterno del gioco

extends Resource
class_name Quest

## Idnetificativo della missione
@export var quest_id: StringName
## Titolo della quest che verrà mostrato al giocatore
@export var titolo: String = ""
## Descrizione dell'della missione
@export var descrizione: String = ""
## Lista di obbiettivi che il giocatore deve portare a termine 
## per colcudere la quest.
@export var obiettivi: Array[Objective] = []
## Indicatore che specifica se la quest è ancora attivata
@export var attiva: bool = false
## Indicatore che specifica se la quest è stata completata 
@export var completata: bool = false
## Messaggio che viene mostrato quando la quest è terminata
@export var description_on_completate: String

## Funziona usata per aggiornare lo stato degli [member obbiettivi] 
## da mostrare a schermo all'utente.
func stato_testo() -> String:
	for o in obiettivi:
		if not o.completato:
			if o.tipo == "counter":
				return "%s (%d/%d)" % [o.descrizione, o.progress, o.target]
			return o.descrizione
	return description_on_completate


func on_event(ev: StringName, payload := {}) -> bool:
	if completata: return false
	var changed : bool = false
	for o in obiettivi:
		if o.apply_event(ev, payload):
			changed = true
	completata = obiettivi.all(func(x): return x.completato)
	return changed
