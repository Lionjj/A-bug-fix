# ============================================================================
# RoomSizeProfile
# ============================================================================
## Definisce le dimensioni consentite per le stanze generate.
## NON genera layout, NON crea forme.
# ============================================================================

extends Resource
class_name RoomSizeProfile

## Dimensione minima della stanza (in celle).
@export var min_size: Vector2i = Vector2i(20, 20)

## Dimensione massima della stanza (in celle).
@export var max_size: Vector2i = Vector2i(32, 24)

## Step discreti per larghezza e altezza.
@export var step: Vector2i = Vector2i(4, 4)

## Dimensione minima di un varco
@export var opening_min_tiles: int = 4

## Dimensione massima di un varco
@export var opening_max_tiles: int = 10

## Dimensione minima delle indentazioni
@export var min_width_indent: int = 4

## Dimensione minima delle indentazioni
@export var max_width_indent: int = 10

## Dimensione minima delle indentazioni
@export var min_depth_indent: int = 4

## Dimensione max delle indentazioni
@export var max_depth_indent: int = 10

## Dimensione minima dei passaggi percorribili dal player
@export var min_passage_tiles: int = 4

## Margine estra attorno al connettore sul bordo
@export var connector_guard: int = 1 
