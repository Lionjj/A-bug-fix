## Nodo del grafo [MissionGraph] rappresentsante le informazioni logiche dele stanze nella generazioni 
## procedurale.
class_name MissionNode

## Identificativo della stanza.
var id: String

## Tipo di stanza, usata poi per scegliere un template.
var kind: String

var grants: Array[int] = []
var requires: Array[int] = []

## Difficolta di ciascuna stanza, influenza la difficolta dei nemici, e il numero di oggetti 
## che la stanza conterrà.
var diff: int = 1

## Catalogo di oggetti che la stanza contiene
var catalog: NodeCatalogue = NodeCatalogue.new([] as Array[Item]):
	get: return catalog

## Direttive logiche usate per gestire lo spawn dei nemici.
var enemy_directive: EnemyDirective = EnemyDirective.new()

func _init(_id:String,_kind:String): id=_id; kind=_kind
