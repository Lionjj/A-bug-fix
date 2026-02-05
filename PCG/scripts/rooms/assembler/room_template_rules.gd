# ============================================================================
# RoomTemplateRules
# ============================================================================
## Regole e predicati "pure" per filtrare e valutare template stanza.[br]
##
## Questo modulo NON prende decisioni.[br]
## Espone solo funzioni deterministiche usate dal picker.[br]
##
## Responsabilità:[br]
## - Ability gating: verifica che le abilità richieste siano disponibili.[br]
## - Compatibilità semantica: verifica che il template possa soddisfare
##   il ruolo richiesto dal nodo (via tag bitmask).[br]
## - Vincoli connettori espliciti: verifica compatibilità direzionale.[br]
## - Utility: direzioni cardinali e mapping direzione -> stringa.[br]
# ============================================================================

extends RefCounted
class_name RoomTemplateRules


# ---------------------------------------------------------------------------
# Grid directions
# ---------------------------------------------------------------------------

## Direzioni cardinali usate per ragionare su adiacenze in griglia.[br]
## Ordine coerente con il MissionGraph (UP, LEFT, DOWN, RIGHT).
const DIRS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.RIGHT
]

## Mapping da direzione vettoriale a chiave di connettore.[br]
## Usato per tradurre adiacenze in richieste "N/E/S/W".
const DIRS_STR: Dictionary[Vector2i, String] = {
	Vector2i.UP: "N",
	Vector2i.LEFT: "W",
	Vector2i.DOWN: "S",
	Vector2i.RIGHT: "E"
}

## Mapping richiesta -> lato opposto nel template.[br]
## Se devo collegarmi a "N" (c'è un vicino a nord), il template deve avere "S".
const OPPOSITE_DIR: Dictionary[String, String] = {
	"N": "S",
	"E": "W",
	"S": "N",
	"W": "E"
}

## Costanti leggibili per conversione key.
const VEC_KEY_PREFIX: String = "v:"
const EMPTY_DIRS: Array[String] = []


# ---------------------------------------------------------------------------
# Ability gating
# ---------------------------------------------------------------------------

## Verifica che tutte le abilità richieste siano disponibili.[br]
##
## Comportamento:[br]
## - Controlla prima le abilità richieste dal template.[br]
## - Poi le abilità richieste dal nodo logico.[br]
## - Tutte devono essere presenti nell'array [param abilities].[br]
##
## Fail-first:[br]
## - Se [param info] è null -> false.[br]
## - Al primo requisito mancante -> false.[br]
##
## [param info] DTO del template (RoomTemplateInfo).[br]
## [param node_requires] Abilità richieste dal nodo logico.[br]
## [param abilities] Abilità attualmente disponibili al player.[br]
## [return] True se tutte le abilità sono presenti, altrimenti false.
static func abilities_match(
	info: RoomTemplateInfo,
	node_requires: Array[Abilities.Ability],
	abilities: Array[Abilities.Ability]
) -> bool:
	if info == null:
		return false

	## Requisiti del template
	for a: Abilities.Ability in info.requires:
		if not abilities.has(a):
			return false

	## Requisiti del nodo logico
	for a: Abilities.Ability in node_requires:
		if not abilities.has(a):
			return false

	return true


# ---------------------------------------------------------------------------
# Kind / tags rules (bitmask)
# ---------------------------------------------------------------------------

## Verifica la compatibilità semantica tra nodo e template.[br]
##
## Regola:[br]
## - Il nodo espone un SOLO ruolo (un singolo bit: RoomTags.Tag).[br]
## - Il template espone una bitmask di ruoli che può ricoprire.[br]
## - Se il bit del nodo è presente nella mask del template → match valido.[br]
##
## [param info] DTO del template (RoomTemplateInfo).[br]
## [param node_kind] Ruolo richiesto dal nodo (singolo RoomTags.Tag).[br]
## [return] True se il template può soddisfare il ruolo, altrimenti false.
static func kind_match(
	info: RoomTemplateInfo,
	node_kind: RoomTags.Tag
) -> bool:
	if info == null:
		return false

	## Strong match
	if info.kind == node_kind:
		return true

	## Bitwise match: il template dichiara di poter essere quel tipo
	return (info.tag_mask & int(node_kind)) != 0


# ---------------------------------------------------------------------------
# Connectors helpers
# ---------------------------------------------------------------------------

## Verifica che il template soddisfi TUTTI i connettori richiesti.[br]
##
## Semantica:[br]
## - [param req] rappresenta le connessioni richieste dal nodo logico.[br]
## - Il controllo avviene sul lato OPPOSTO del template.[br]
##
## Esempio:[br]
## - req["N"] == true  → serve collegarsi a nord[br]
## - il template deve avere "S"[br]
##
## [param info] DTO del template (RoomTemplateInfo).[br]
## [param req] Requisiti espliciti sui connettori.[br]
## [return] True se tutti i requisiti sono soddisfatti, altrimenti false.
static func satisfies_req(
	info: RoomTemplateInfo,
	req: Dictionary[String, bool]
) -> bool:
	if info == null:
		return false

	if req.is_empty():
		return true

	for d: String in OPPOSITE_DIR.keys():
		if not bool(req.get(d, false)):
			continue

		var opposite: String = OPPOSITE_DIR[d]
		if not bool(info.connectors.get(opposite, false)):
			return false

	return true


## Calcola le direzioni richieste (N/E/S/W) in base alle adiacenze in griglia.
##
## [param node_id] Id del nodo logico di cui calcolare le adiacenze.
## [param positions] Mappa { node_id -> Vector2i } (layout su griglia).
## [return] Array[String] con subset di ["N","E","S","W"] richiesti.
static func needed_connectors(node_id: String, positions: Dictionary) -> Array[String]:
	if not positions.has(node_id):
		return EMPTY_DIRS.duplicate()

	var base: Vector2i = positions[node_id]
	var need: Array[String] = []

	## lookup rapido: posizione -> true (key string stable)
	var occupied: Dictionary[String, bool] = {}
	for id in positions.keys():
		var p: Vector2i = positions[id]
		occupied[_vec_key(p)] = true

	for d: Vector2i in DIRS:
		var p: Vector2i = base + d
		if occupied.has(_vec_key(p)):
			need.append(DIRS_STR[d])

	return need


## Score 0..1: frazione di direzioni richieste effettivamente disponibili nel template.
##
## [param info] DTO del template (RoomTemplateInfo).
## [param need_dirs] Direzioni richieste dal grafo (output di needed_connectors).
## [return] 0..1 dove 1 = match perfetto.
static func connectors_coverage(info: RoomTemplateInfo, need_dirs: Array[String]) -> float:
	if info == null:
		return 0.0

	if need_dirs.is_empty():
		return 1.0

	var have: int = 0
	for d: String in need_dirs:
		if bool(info.connectors.get(d, false)):
			have += 1

	return float(have) / float(need_dirs.size())


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Crea una chiave stabile per usare Vector2i in lookup Dictionary senza ambiguità.[br]
## (Evita "magic str(p)" ripetuti e centralizza la convenzione.)
static func _vec_key(v: Vector2i) -> String:
	return VEC_KEY_PREFIX + str(v.x) + "," + str(v.y)
