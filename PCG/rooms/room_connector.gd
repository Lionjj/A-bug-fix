## Modulo contenente le informazioni dei conettori che collegano due stanze.
##
## La logica che permette di aprire i varchi è contenuta in [CorridorBuilder], la convenzione vuole
## che questi marker vanno posizionati alle [b]estremità esterne[/b] delle stanze.
extends Marker2D
class_name RoomConnector

## Specifica il numero di tile verso l'alto da lasciare libere per creare un varco che si apre 
## verticalmente vedi anche [member offset_down]
@export var offset_up: int = 0

## Specifica il numero di tile verso il basso da lasciare libere per creare un varco che si apre 
## verticalmente vedi anche [member offset_up]
@export var offset_down: int = 0

## Specifica il numero di tile verso sinistra da lasciare libere per creare un varco che si apre 
## orizzontalmente vedi anche [member offset_right]
@export var offset_left: int = 0

## Specifica il numero di tile verso destra da lasciare libere per creare un varco che si apre 
## orizzontalmente vedi anche [member offset_left]
@export var offset_right: int = 0
