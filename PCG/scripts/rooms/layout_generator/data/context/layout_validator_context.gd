extends RefCounted
class_name LayoutValidatorContext

var score: float
var is_valid: bool

func _init(_score: float, _is_valid: bool) -> void:
	score = _score
	is_valid = _is_valid
