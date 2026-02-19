# ============================================================================
# PlayerTraversalProfile
# ============================================================================
## Rappresenta le capacità di movimento del player
## in termini DISCRETI (tile-based).
##
## NON simula la fisica.
# ============================================================================

class_name PlayerTraversalProfile
extends Resource

## Altezza massima salto (in tile)
@export var max_jump_tiles: int = 3

## Altezza massima risalibile con wall jump
@export var wall_jump_tiles: int = 3

## di quanto si sposta orizzontalmente dopo un wall_jump
@export var wall_jump_horizontal_tiles: int = 1

## Può usare wall jump?
@export var can_wall_jump: bool = true
