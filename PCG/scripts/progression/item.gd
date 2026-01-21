## Rappresenta le informazioni di un generico oggetto logico.
extends Resource

class_name Item

## Priorità dell'oggetto: [br]
## Un oggetto di tipo [b]MANDATORY[/b] deve essere istanzaito; 
## Un oggetto di tipo [b]OPTIONAL[/b] può essere istanziato in base allo [member spawn_rate]
## e alla difficoltà delle stanze.
enum Priority {MANDATORY, OPTIONAL}

## Id univoco dell'oggetto.
var id: ItemRegistry.ID

## Nome dell'oggetto logico.
@export var name: String

## Icona rappresentante la parte estetica dell'oggetto.
@export var texture: Texture2D

## Priorità dell'oggetto.
@export var priority: Priority

## Probabilità che l'oggetto appaia nella stanza, gli oggetti con [member priority] = [b]MANDATORY[/b] non
## sono influenzati da questa proprità. [br]
## Si consiglia di tenere questo valore compreso tra 0 e 1.
@export var spawn_rate: float = 1.0

## Massima quantità di oggetti che devono essere istanziati.[br]
## Solitamente gli oggetti con [member priority] = [b]MANDATORY[/b] hanno questo valore a [b]1[/b],
## mentre gli altri possono averlo > 1.
@export var max_quantity: int = 1

func _init(_id: ItemRegistry.ID = ItemRegistry.ID.DEFAULT, _name: String = "", _priority: Priority = Priority.MANDATORY, _spawn_rate: float = 1.0, _max_quantity: int = 1) -> void:
	id = _id
	name = _name
	priority = _priority
	spawn_rate = _spawn_rate
	max_quantity = _max_quantity
