extends WFC2DPrecondition
## Generates a dungeon.
##
## Uses an algorithm based on one from
## [url=https://indienova.com/u/root/blogread/1766]this article[/url].
class_name WFC2DPreconditionPlaftorm

var platform_domain: WFCBitSet
var air_domain: WFCBitSet
#=== TEST ====
var prop_domain: WFCBitSet
var interact_domain: WFCBitSet
var border_domain: WFCBitSet
var inner_domain: WFCBitSet
var mapper_size: int = 0
#=== TEST ====

var rect: Rect2i 
var level: TileMapLayer

# Not modified since not used. may be broken
func learn_classes_from_map(
	mapper: WFCMapper2D,
	map: Node,
):
	assert(mapper.supports_map(map))

	var used_rect := mapper.get_used_rect(map)

	assert(used_rect.has_area())
	# Either 1 row (passable tiles) or 2 rows (passable tiles and wall tiles)
	assert(used_rect.size.y == 1 or used_rect.size.y == 2)

	air_domain = WFCBitSet.new(mapper.size())

	for x_off in range(used_rect.size.x):
		var p := used_rect.position + Vector2i(x_off,0)
		var tile := mapper.read_cell(map, p)
		if tile >= 0:
			air_domain.set_bit(tile)

	if used_rect.size.y == 1:
		platform_domain = air_domain.invert()
	else:
		platform_domain = WFCBitSet.new(mapper.size())

		for x_off in range(used_rect.size.x):
			var p := used_rect.position + Vector2i(x_off,1)
			var tile := mapper.read_cell(map, p)
			if tile >= 0:
				platform_domain.set_bit(tile)

	assert(not platform_domain.is_empty())


func learn_classes(
	mapper: WFCMapper2D,
	platform_class: String,
	air_class: String,
	#=== TEST ====
	prop_class: String,
	interact_class: String
	#=== TEST ====
):
	#=== TEST ====
	mapper_size = mapper.size()
	#=== TEST ====
	
	air_domain = WFCBitSet.new(mapper_size)
	platform_domain = WFCBitSet.new(mapper_size)
	#=== TEST ====
	prop_domain = WFCBitSet.new(mapper_size)
	interact_domain = WFCBitSet.new(mapper_size)
	border_domain = WFCBitSet.new(mapper_size)
	inner_domain = WFCBitSet.new(mapper_size)

	#=== TEST ====

	for i in range(mapper_size):
		
		var is_air       := mapper.read_tile_meta_boolean(i, air_class)
		var is_platform  := mapper.read_tile_meta_boolean(i, platform_class)
		var is_prop      := mapper.read_tile_meta_boolean(i, prop_class)
		var is_interact  := mapper.read_tile_meta_boolean(i, interact_class)
		
		if is_air:
			air_domain.set_bit(i)
		if is_platform:
			platform_domain.set_bit(i)
		#=== TEST ====
		if is_prop:
			prop_domain.set_bit(i)
		if is_interact:
			interact_domain.set_bit(i)
		
		
		if is_air:
			border_domain.set_bit(i)
		
		if is_air or is_prop or is_interact:
			inner_domain.set_bit(i)
		#=== TEST ====
		

	assert(not air_domain.is_empty())
	assert(not platform_domain.is_empty())


func prepare():
	assert(rect.has_area())

func _is_border(coords: Vector2i) -> bool:
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	return coords.x == min_x \
		or coords.x == max_x \
		or coords.y == min_y \
		or coords.y == max_y


func read_domain(coords: Vector2i) -> WFCBitSet:
 
	if not rect.has_point(coords):
		return null

	# if we have any tile on level layer, it means we have a solid real tile
	var value = level.get_cell_source_id(coords)
	if value != -1:
		return platform_domain
		
	if _is_border(coords):
		return border_domain
	
	return inner_domain
	
