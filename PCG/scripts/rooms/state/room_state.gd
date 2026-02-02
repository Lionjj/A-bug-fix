# ============================================================================
# RoomState
# ============================================================================
## Modulo che gestisce lo **stato runtime** di una stanza.[br]
##
## Questo nodo NON rappresenta la stanza fisica, ma il suo stato logico
## durante una run di gioco.[br]
##
## Responsabilità:[br]
## - Tenere traccia dello stato di item, nemici, trappole e decorazioni.[br]
## - Indicare se la stanza è stata completata ([member done]).[br]
##
## Note architetturali:[br]
## - Ogni [RoomTemplateMeta] possiede un [RoomState] associato.[br]
## - I vari *State* (RoomItemState, RoomEnemyState, ecc.) sono contenitori
##   indipendenti, così da mantenere separata la logica per sottosistemi.[br]
## - Questo oggetto NON ha logica attiva: viene letto e modificato dai manager
##   (es. RoomsManager, spawner, combat flow).[br]
# ============================================================================

extends Node
class_name RoomState


# ---------------------------------------------------------------------------
# Sub-states
# ---------------------------------------------------------------------------

## Stato degli item della stanza.[br]
## Contiene riferimenti runtime agli item istanziati e informazioni di spawn.
var items_state: RoomItemState

## Stato dei nemici della stanza.[br]
## Contiene queue, ondate, nemici vivi, nemici totali, ecc.
var enemies_state: RoomEnemyState

## Stato delle trappole della stanza.[br]
## Contiene riferimenti e informazioni di spawn delle trappole.
var traps_state: RoomTrapState

## Stato delle decorazioni della stanza.[br]
## Contiene riferimenti runtime alle decorazioni istanziate.
var decos_state: RoomDecoState


# ---------------------------------------------------------------------------
# Completion state
# ---------------------------------------------------------------------------

## Indica se la stanza è stata completata dal giocatore.[br]
##
## True se:[br]
## - il combattimento (se presente) è terminato con successo[br]
## - le porte sono state sbloccate definitivamente[br]
##
## Questo valore viene tipicamente settato da RoomsManager a fine combattimento.
var done: bool = false:
	get:
		return done
	set(_done):
		done = _done


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruttore dello stato stanza.[br]
##
## Permette di iniettare stati già esistenti oppure creare stati di default.[br]
## Usato principalmente durante la costruzione del mondo / inizializzazione run.[br]
##
## [param _items_state] Stato iniziale degli item (default: nuovo RoomItemState).[br]
## [param _enemies_state] Stato iniziale dei nemici (default: nuovo RoomEnemyState).[br]
## [param _trap_state] Stato iniziale delle trappole (default: nuovo RoomTrapState).[br]
## [param _decos_state] Stato iniziale delle decorazioni (default: nuovo RoomDecoState).[br]
func _init(
	_items_state: RoomItemState = RoomItemState.new(),
	_enemies_state: RoomEnemyState = RoomEnemyState.new(),
	_trap_state: RoomTrapState = RoomTrapState.new(),
	_decos_state: RoomDecoState = RoomDecoState.new()
) -> void:
	items_state = _items_state
	enemies_state = _enemies_state
	traps_state = _trap_state
	decos_state = _decos_state
