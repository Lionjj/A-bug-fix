extends Node

class_name RoomTemplate
var kind:String
var size_tiles := Vector2i(80, 48)
var connectors:= {"N":false, "E":true, "S":false, "W":true}
var requires:Array[int] = []
var difficulty:int = 1
func supports(abilities:Array[int]) -> bool:
	for r in requires:
		if not abilities.has(r): return false
	return true
