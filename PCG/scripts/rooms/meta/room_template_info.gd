# ============================================================================
# RoomTemplateInfo
# ============================================================================
## Metadati tipizzati derivati da un RoomTemplateMeta.[br]
##
## Responsabilità:[br]
## - Rappresentare in forma compatta e tipizzata i dati di una stanza.[br]
## - Fornire accesso rapido e coerente ai parametri di selezione.[br]
##
## Nota di design:[br]
## - Questa classe è un semplice data container (DTO).[br]
## - NON contiene logica di selezione o gameplay.[br]
## - I dati vengono estratti una sola volta e poi riutilizzati.[br]
## - Pensata per essere trattata come immutabile dopo la creazione.[br]
# ============================================================================

extends RefCounted
class_name RoomTemplateInfo


# ---------------------------------------------------------------------------
# Constants (no magic values / shared defaults)
# ---------------------------------------------------------------------------

## Direzioni cardinali standard per i connettori.
const CARDINAL_DIRS: Array[String] = ["N", "E", "S", "W"]

## Default connectors (tutti false) usato per init e per copie sicure.
const DEFAULT_CONNECTORS: Dictionary[String, bool] = {
	"N": false,
	"E": false,
	"S": false,
	"W": false
}


# ---------------------------------------------------------------------------
# Data (DTO)
# ---------------------------------------------------------------------------

## Chiave univoca del template nel catalogo
## (derivata dal basename del file scena)
var key: String

## Categoria logica della stanza (es. HUB, CHALLENGE, SAVE, ecc.)
var kind: RoomTags.Tag

## Dimensione della stanza in tiles (bounding box logica)
var size_tiles: Vector2i

## Abilità richieste per poter utilizzare questo template
## Usate per gating progressione
var requires: Array[Abilities.Ability] = []

## Difficoltà associata al template
## Usata per il matching con la difficoltà del nodo
var difficulty: int = 1

## Connettori disponibili nel template
## Direzioni cardinali -> presenza apertura
var connectors: Dictionary[String, bool] = DEFAULT_CONNECTORS.duplicate()

## Peso base del template
## Influenza la probabilità di selezione (moltiplicatore)
var base_weight: float = 1.0

## Bitmask dei tag semantici (checkbox via @export_flags in [RoomTemplateMeta])
## Fonte di verità per fallback e matching "solido"
var tag_mask: int = 0


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Costruisce un RoomTemplateInfo a partire da un RoomTemplateMeta
##
## Comportamento:[br]
## - Copia i dati rilevanti dal template.[br]
## - Duplica array/dict per evitare side-effect.[br]
## - Non valida la coerenza dei dati (responsabilità del template).[br]
##
## Fail-first implicito:[br]
## - Si assume che room sia un RoomTemplateMeta valido.[br]
## - La validazione avviene a monte (Catalog / MetaDB).
static func from_room(key_: String, room: RoomTemplateMeta) -> RoomTemplateInfo:
	var info := RoomTemplateInfo.new()

	info.key = key_

	info.kind = room.kind
	info.size_tiles = room.size_tiles
	info.requires = room.requires.duplicate()
	info.difficulty = int(room.difficulty)

	## Copia “safe”: evita che modifiche al template runtime tocchino l'info (DTO immutabile)
	info.connectors = _copy_connectors_safe(room.connectors)

	info.base_weight = room.base_weight
	info.tag_mask = int(room.tag_mask)

	return info


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Copia i connettori garantendo:
## - chiavi standard N/E/S/W presenti
## - valori bool
## - nessun alias verso il dict originale
static func _copy_connectors_safe(src: Dictionary) -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = DEFAULT_CONNECTORS.duplicate()

	if src == null or src.is_empty():
		return out

	for dir: String in CARDINAL_DIRS:
		if src.has(dir):
			out[dir] = bool(src[dir])

	return out
