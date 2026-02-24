extends Node
class_name Abilities

enum Ability {DOUBLE_JUMP, DASH, GRAPPLE}

static func name(a:int) -> String:
	return Ability.keys()[a]
