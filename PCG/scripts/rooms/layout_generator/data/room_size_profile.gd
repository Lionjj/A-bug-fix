# ============================================================================
# RoomSizeProfile
# ============================================================================
## Definisce le dimensioni consentite per le stanze generate.
## NON genera layout, NON crea forme.
# ============================================================================

extends Resource
class_name RoomSizeProfile

#--------------------------------------------------------
# Metriche stanza
#--------------------------------------------------------

## Dimensione minima della stanza (in celle).
@export var min_size: Vector2i = Vector2i(20, 20)

## Dimensione massima della stanza (in celle).
@export var max_size: Vector2i = Vector2i(32, 32)

## Step discreti per larghezza e altezza.
@export var step: Vector2i = Vector2i(4, 4)

## Spessore dei muri
@export var wall_thickness: int = 3


#--------------------------------------------------------
# Metriche codivise dagli operatori
#--------------------------------------------------------

## Dimensione minima di un varco
@export var opening_min_tiles: int = 4

## Dimensione massima di un varco
@export var opening_max_tiles: int = 10

## Dimensione minima dei passaggi percorribili dal player
@export var min_passage_tiles: int = 4

## Margine extra attorno al connettore sul bordo
@export var connector_guard: int = 1 

## Margine tra un oggetto geomterico fiscio nella stanza
## e i muri
@export var border_margin_wall: int = 3

## Margine tra un oggetto geomterico fiscio nella stanza
## e soffitto/pavimento
@export var border_margin_ceil_flor: int = 3


#--------------------------------------------------------
# Metriche operatore: Indent
#--------------------------------------------------------

## Dimensione minima delle indentazioni
@export var min_width_indent: int = 4

## Dimensione minima delle indentazioni
@export var max_width_indent: int = 10

## Dimensione minima delle profondita
@export var min_depth_indent: int = 4

## Dimensione max delle profondita
@export var max_depth_indent: int = 10

## Minimo numero di indentazioni
@export var min_indent_count: int = 0

## Massimo numero di indentazioni
@export var max_indent_count: int = 2


#--------------------------------------------------------
# Metriche operatore: Pillar
#--------------------------------------------------------

## Minimo numero di pillar
@export var min_pillar_count: int = 1

## Massimo numero di pillar
@export var max_pillar_count: int = 3

## Minima largezza di un pillar
@export var min_pillar_width: int = 2

## Massima largezza di un pillar
@export var max_pillar_width: int = 4

## Minima altezza di un pillar
@export var min_pillar_height: int = 2

## Massima altezza di un pillar
@export var max_pillar_height: int = 4


#--------------------------------------------------------
# Metriche operatore: Divider
#--------------------------------------------------------

## Numero minimo di divisori della stanza
@export var min_divider_count: int = 1

## Numero massimo di divisori della stanza
@export var max_divider_count: int = 3

## Valore minimo di divisione tra un seapartore e l'altro
@export var min_divider_separator: int = min_passage_tiles + wall_thickness

## Probabilità minima che i divisori siano verticali
@export var min_divider_vertical: float = 0.2

## Probabilità massima che i divisori siano verticali
@export var max_divider_vertical: float = 0.8

## Soglia per essere verticale
@export var divider_threshold_vertical: float = 0.5


#--------------------------------------------------------
# Metriche operatore: Platform
#--------------------------------------------------------

## Numero minimo di piattaforme della stanza
@export var min_platform_count: int = 1

## Numero massimo di piattaforme della stanza
@export var max_platform_count: int = 3

## Dimensione minima delle piattaforme
@export var min_width_platform: int = 4

## Dimensione minima delle piattaforme
@export var max_width_platform: int = 10

## Minimo spessore delle piattaforme
@export var min_thickness_platform: int = 2

## Massimo spessore delle piattaforme
@export var max_thickness_platform: int = 4


#--------------------------------------------------------
# Metriche operatore: Ring
#--------------------------------------------------------

## Minima distanza del ring dai bordi della stanza
@export var min_ring_offset: int = 3

## Massima distanza del ring dai bordi della stanza
@export var max_ring_offset: int = 8

## Spessore minimo del ring
@export var min_ring_thickness: int = 2

## Spessore massimo del ring
@export var max_ring_thickness: int = 4

## Dimensione minima dell'apertura del ring 
@export var min_ring_gate_width: int = 4

## Dimensione massima dell'apertura del ring 
@export var max_ring_gate_width: int = 6

## Numero minimo di aperture del ring
@export var min_ring_gate_count: int = 1

## Numero massimo di aperture del ring
@export var max_ring_gate_count: int = 3


#--------------------------------------------------------
# Metriche operatore: SplitCorner 
#--------------------------------------------------------

## Largezza minima del angolo
@export var min_width_split_corner: int = 4

## Largezza massima del angolo
@export var max_width_split_corner: int = 8

## Profondità minima del angolo
@export var min_depth_split_corner: int = 4

## Profondità massima del angolo
@export var max_depth_split_corner: int = 8

## Numero minimo di angoli
@export var min_split_corner_count: int = 1

## Numero massimo di angoli
@export var max_split_corner_count: int = 4
