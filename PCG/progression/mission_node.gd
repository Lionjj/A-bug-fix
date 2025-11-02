class_name MissionNode
var id: String
var kind: String       # "START","HUB","CHALLENGE","KEY_ROOM","SAVE","BOSS","SIDE"
var grants: Array[int] = []
var requires: Array[int] = []
var diff: int = 1
func _init(_id:String,_kind:String): id=_id; kind=_kind
