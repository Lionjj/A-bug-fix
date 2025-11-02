extends Node2D
class_name RoomTemplateMeta

@export var kind: String = "ARENA"												# "ARENA","SHAFT","GAP"...
@export var size_tiles: Vector2i = Vector2i(80,48)
@export var requires: Array[Abilities.Ability] = []								# Abilities.Ability enum (es. [Abilities.Ability.DOUBLE_JUMP])
@export var difficulty: int = 1

# Connettori dichiarati: true = presente, false = assente
@export var connectors := {"N":false, "E":true, "S":false, "W":true}

# Convenzione: nel scene tree devono esistere Marker2D con questi nomi se true
const CONNECTOR_NAMES := {"N":"conn_N","E":"conn_E","S":"conn_S","W":"conn_W"}


const PIXEL = 16


@export var base_weight: float = 1.0												# “quanto vuole apparire” il template
@export var tags: Array[String] = []												# es: ["vertical","gap","combat","platforming"]
