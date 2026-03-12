extends Node
class_name Abilities

enum Ability {DOUBLE_JUMP, DASH, GRAPPLE}

static func name(a:int) -> String:
	return Ability.keys()[a]

static func to_lable(ability: int) -> String:
	match ability:
		Ability.DOUBLE_JUMP:
			return "Doppio salto"
		Ability.DASH:
			return "Scatto"
		Ability.DOUBLE_JUMP:
			return "Arrampicata"
		_:
			return "NaN"
