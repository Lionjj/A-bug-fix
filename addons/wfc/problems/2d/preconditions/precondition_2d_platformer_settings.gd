extends WFC2DPrecondition2DNullSettings
## Settings for a precondition that generates a platform-like structure.
class_name WFC2DPreconditionPlatformSettings

@export_group("Level")

@export_node_path var level_path: NodePath

@export_group("Tile classes")
## Name of meta attribute/custom data layer that marks passable tiles.
@export
var platform_class: String = "wfc_platform"
@export
var air_class: String = "wfc_air"
#=== TEST ===
@export
var props_class: String = "wfc_props"
@export
var interactable_class: String = "wfc_interactable"
#=== TEST ===




## If set, the precondition will extract tile classes (passable/wall) from a map node instead of
## tile meta attributes.
## [br]
## First row of the map should contain all passable tiles.
## Second row should contain all wall tiles.
## Second row may be empty.
## In such case, all tiles except for ones from first row will be considered as walls.
@export_node_path
var classes_map: NodePath

func create_precondition(parameters: WFC2DPrecondition2DNullSettings.CreationParameters) -> WFC2DPrecondition:
	var res: WFC2DPreconditionPlaftorm = WFC2DPreconditionPlaftorm.new()

	res.rect = parameters.problem_settings.rect

	var mapper := parameters.problem_settings.rules.mapper

	if classes_map != null and not classes_map.is_empty():
		var map_node := parameters.generator_node.get_node(classes_map)
		res.learn_classes_from_map(mapper, map_node)
	else:
		res.learn_classes(mapper, platform_class, air_class, props_class, interactable_class)

	res.level = parameters.generator_node.get_node(level_path)


	return res
