# ============================================================================
# WorldFinalize
# ============================================================================
## Modulo di finalizzazione livello:[br]
## - merge dei TileMapLayer in un layer finale[br]
## - set seed per autotiles[br]
## - spawn del player e setup del GameManager[br]
##
## Note:[br]
## - Stateless: opera su un context.[br]
# ============================================================================

extends RefCounted
class_name WorldFinalize

static func merge_and_spawn(ctx: WorldFinalizeContext) -> TileMapLayer:
	## Guard
	if ctx == null or ctx.level_root == null:
		return null
	if ctx.player_scene == null:
		push_error("WorldFinalize: player_scene is null")
		return null

	## Merge tilemap
	var final_layer: TileMapLayer = TileMapUtility.merge_tile_map_layer(ctx.level_root)

	## Seed autotiles (se presente)
	if ctx.auto_tiles != null:
		ctx.auto_tiles.seed = ctx.seed

	## Spawn player
	var p: Player = ctx.player_scene.instantiate()
	p.global_position = ctx.spawn_point
	ctx.level_root.add_child(p)

	## Setup player
	p.movement_enabled = true
	p.wall_check_enabled = true
	GameManager.set_player(p)

	return final_layer
