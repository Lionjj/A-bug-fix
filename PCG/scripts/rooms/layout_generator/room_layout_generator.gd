class_name RoomLayoutGenerator

var room_profile: RoomSizeProfile
var room_piker: RoomSizePicker
var room_mask: RoomLayoutMask
var room_rule: RoomLayoutRules
var rng: RandomNumberGenerator

func _init() -> void:
	room_profile = RoomSizeProfile.new()
	room_piker = RoomSizePicker.new(room_profile)
	room_mask = RoomLayoutMask.new(room_piker.pick())
	rng = RandomNumberGenerator.new()
	room_rule = RoomLayoutRules.new(room_mask, rng)

func generate():
	var width: int
	var depth: int
	var side: RoomLayoutRules.SIDE = room_rule.SIDE.keys().pick_random()
	room_rule.apply_indent(side, )

func _compute_width() -> int:
	return rng.randi_range(room_profile.min_width_indent, room_profile.max_width_indent)

func _compute_depth() -> int:
	return rng.randi_range(room_profile.min_depth_indent, room_profile.max_depth_indent)
