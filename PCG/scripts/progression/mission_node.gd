## Nodo del grafo [MissionGraph] rappresentsante le informazioni logiche dele stanze nella generazioni 
## procedurale.
class_name MissionNode

## Identificativo della stanza.
var id: String

## Tipo di stanza, usata poi per scegliere un template.
var kind: RoomTags.Tag

var grants: Array[Abilities.Ability] = []
var requires: Array[Abilities.Ability] = []
var logical_abilities_before: Array[Abilities.Ability] = []

## Difficolta di ciascuna stanza, influenza la difficolta dei nemici, e il numero di oggetti 
## che la stanza conterrà.
var diff: int = 1

## Catalogo di oggetti che la stanza contiene
var catalog: NodeCatalogue = NodeCatalogue.new([] as Array[Item]):
	get: return catalog

## Direttive logiche usate per gestire lo spawn dei nemici.
var enemy_directive: EnemyDirective = EnemyDirective.new()

## Direttive logiche usate per gestire lo spawn delle trappole.
var trap_directive: TrapDirective = TrapDirective.new()

func _init(_id: String, _kind: RoomTags.Tag, _diff: int = 1): 
	id = _id
	kind = _kind
	diff = _diff
