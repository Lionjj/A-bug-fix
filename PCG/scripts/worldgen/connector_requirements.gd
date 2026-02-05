# ============================================================================
# ConnectorRequirements
# ============================================================================
## Modulo responsabile del calcolo dei requisiti di connettività (N/E/S/W)[br]
## per una stanza già piazzata su griglia.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Determinare quali lati di una stanza richiedono un connettore fisico.[br]
## - Basarsi esclusivamente sulle adiacenze reali nella griglia.[br]
## - Fornire un output minimale e diretto per la selezione dei template stanza.[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non verifica la validità logica delle connessioni.[br]
## - Non consulta il grafo logico della missione.[br]
## - Non applica regole di gating o compatibilità dei template.[br]
##[br]
## [b]Dipendenze[/b]:[br]
## - [MissionGraph]: responsabile della validità logica delle connessioni.[br]
## - [RoomAssembler]: utilizza l’output per filtrare i template compatibili.[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Modulo stateless: espone solo funzioni statiche.[br]
## - Complessità O(1): controlla esclusivamente le 4 celle adiacenti.[br]
## - Richiede una mappa inversa `occupied` (Vector2i → id) per lookup immediato.[br]
# ============================================================================

extends RefCounted
class_name ConnectorRequirements


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Calcola i requisiti di connettività per una stanza.[br]
##[br]
## [b]Strategia[/b]:[br]
## - Recupera la posizione della stanza corrente dalla mappa `positions`.[br]
## - Controlla la presenza di stanze nelle celle adiacenti (N/E/S/W).[br]
## - Ogni adiacenza rilevata implica la necessità di un connettore su quel lato.[br]
##[br]
## [b]Output[/b]:[br]
## Dizionario con chiavi "N","E","S","W" e valori booleani:[br]
## - [code]true[/code]  → esiste una stanza adiacente → connettore richiesto.[br]
## - [code]false[/code] → nessuna stanza adiacente su quel lato.[br]
##[br]
## [param id]: id della stanza di cui calcolare i requisiti.[br]
## [param positions]: [code]dizionario[id, Vector2i][/code] con le posizioni piazzate.[br]
## [param occupied]: [code]dizionario[Vector2i,id][/code] per lookup inverso rapido.[br]
##[br]
## Ritorna: [code] dizionario { "N":bool, "E":bool, "S":bool, "W":bool }[/code].[br]
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

	# Guard: input non valido o stanza non piazzata
	if positions == null or occupied == null:
		return req
	if not positions.has(id):
		return req

	var p: Vector2i = positions[id]

	# Mappa direzioni → offset su griglia (lookup O(1), niente if ripetuti)
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
