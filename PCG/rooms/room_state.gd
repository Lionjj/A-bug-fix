## Modulo che gestice lo stato di una stanza.
extends Node
class_name RoomState

## Stato degli item della stanza.
var items_state: RoomItemState
## Stato dei nemici della stanza.
var enemies_state: RoomEnemyState

## Valore che specifica se la stanza è stata completata del giocatore.
var done: bool = false:
	get: return done
	set(_done): done = _done
	

func _init(_items_state: RoomItemState = RoomItemState.new(), _enemies_state: RoomEnemyState = RoomEnemyState.new()) -> void:
	items_state = _items_state
	enemies_state = _enemies_state
