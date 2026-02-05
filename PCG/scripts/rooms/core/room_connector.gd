# ============================================================================
# RoomConnector
# ============================================================================
## Marker dati che descrive “dove” e “quanto” scavare un varco sul bordo stanza.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Definire un punto di riferimento ([Marker2D]) usato per posizionare l’apertura.[br]
## - Esporre offset in tile per controllare l’altezza/larghezza del varco in ogni direzione.[br]
## - Rendere i template stanza configurabili senza toccare codice (tutto via export).[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non scava tile e non apre passaggi: l’operazione fisica è responsabilità di [CorridorBuilder].[br]
## - Non decide quali stanze collegare: riceve solo l’uso come “ancora” sul template stanza.[br]
##[br]
## [b]Convenzione di posizionamento[/b]:[br]
## - I marker vanno messi sulle [b]estremità esterne[/b] della stanza (bordo N/E/S/W).[br]
## - L’orientamento/direzione effettiva del varco dipende da quale lato della stanza stai marcando.[br]
## - Gli offset indicano quanti tile “liberare” attorno al marker lungo l’asse del varco.[br]
##[br]
## [b]Dipendenze[/b]:[br]
## - [CorridorBuilder]: legge questi offset e applica lo scavo coerente nel [TileMapLayer] del corridoio.[br]
# ============================================================================

extends Marker2D
class_name RoomConnector


# ---------------------------------------------------------------------------
# Export / Shape offsets
# ---------------------------------------------------------------------------

## Numero di tile verso l’alto da considerare “apertura” quando il varco è verticale.[br]
## Serve a controllare l’altezza utile del passaggio sul lato superiore.[br]
## Vedi anche [member RoomConnector.offset_down].[br]
@export var offset_up: int = 0

## Numero di tile verso il basso da considerare “apertura” quando il varco è verticale.[br]
## Serve a controllare l’altezza utile del passaggio sul lato inferiore.[br]
## Vedi anche [member RoomConnector.offset_up].[br]
@export var offset_down: int = 0

## Numero di tile verso sinistra da considerare “apertura” quando il varco è orizzontale.[br]
## Serve a controllare la larghezza utile del passaggio sul lato sinistro.[br]
## Vedi anche [member RoomConnector.offset_right].[br]
@export var offset_left: int = 0

## Numero di tile verso destra da considerare “apertura” quando il varco è orizzontale.[br]
## Serve a controllare la larghezza utile del passaggio sul lato destro.[br]
## Vedi anche [member RoomConnector.offset_left].[br]
@export var offset_right: int = 0
