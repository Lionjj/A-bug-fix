# ============================================================================
# ConnectorRequirements
# ============================================================================
## Modulo responsabile del calcolo dei requisiti di connettività (N/E/S/W)
## per una stanza già piazzata su griglia.[br]
##
## Responsabilità principali:[br]
## - Determinare quali lati di una stanza devono avere un connettore fisico.[br]
## - Basarsi esclusivamente sulle adiacenze reali nella griglia (non sul grafo).[br]
## - Fornire un output semplice e diretto per la selezione dei template stanza.[br]
##
## Note architetturali:[br]
## - Modulo stateless: espone solo funzioni statiche.[br]
## - Complessità O(1): controlla solo le 4 celle adiacenti.[br]
## - Richiede una mappa inversa `occupied` (Vector2i → id) per lookup rapido.[br]
## - NON verifica la validità logica delle connessioni (responsabilità di
##   [MissionGraph] e [RoomAssembler]).[br]
# ============================================================================

extends RefCounted
class_name ConnectorRequirements


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Calcola quali connettori (N/E/S/W) sono richiesti per una stanza.[br]
## [br]
## Strategia:[br]
## - Recupera la posizione della stanza corrente.[br]
## - Controlla la presenza di stanze nelle 4 celle adiacenti (UP/RIGHT/DOWN/LEFT).[br]
## - Ogni adiacenza corrisponde a un connettore richiesto.[br]
## [br]
## Output:[br]
## Dizionario con chiavi "N","E","S","W" e valori booleani.[br]
## - true  → esiste una stanza adiacente su quel lato → serve un connettore.[br]
## - false → nessuna stanza su quel lato.[br]
## [br]
## [param id] Id della stanza di cui calcolare i requisiti.[br]
## [param positions] Dizionario { id(String) -> Vector2i } con posizioni piazzate.[br]
## [param occupied] Dizionario { Vector2i -> id(String) } inverso di positions.[br]
## [return] Dizionario { "N":bool, "E":bool, "S":bool, "W":bool }. [br]
static func required_for(
	id: String,
	positions: Dictionary[String, Vector2i],
	occupied: Dictionary[Vector2i, String]
) -> Dictionary[String, bool]:
	var req: Dictionary[String, bool] = {
		"N": false,
		"E": false,
		"S": false,
		"W": false,
	}

	## Guard: input invalidi / stanza non piazzata
	if positions == null or occupied == null:
		return req
	if not positions.has(id):
		return req

	var p: Vector2i = positions[id]

	## Tabella direzioni (stesso O(1), meno ripetizione)
	const DIRS := {
		"N": Vector2i.UP,
		"E": Vector2i.RIGHT,
		"S": Vector2i.DOWN,
		"W": Vector2i.LEFT,
	}

	for k: String in DIRS.keys():
		if occupied.has(p + DIRS[k]):
			req[k] = true

	return req
