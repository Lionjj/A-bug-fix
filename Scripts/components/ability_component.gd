class_name AbilityComponent
extends Node

signal ability_granted(ability)
signal ability_revoked(ability)

var _owned : Dictionary[int, bool] = {}   # Ability -> true

## Funzione che assgena l'abilità al player [br]
## [param ability]: Abilità che deve essere assegnata.
func grant(ability: Abilities.Ability) -> bool:
	if not Abilities.Ability.values().has(ability):
		return false
	
	if _owned.has(ability):
		return true
	
	_owned[ability] = true
	emit_signal("ability_granted", ability)
	
	return true

## Funzione che rimuove l'abilità dal player [br]
## [param ability]: Abilità che deve essere assegnata.
func revoke(ability: Abilities.Ability) -> bool:
	if not _owned.has(ability):
		return false
	
	_owned.erase(ability)
	emit_signal("ability_revoked", ability)
	
	return true

func has(ability: Abilities.Ability) -> bool:
	return _owned.has(ability)


func clear():
	_owned.clear()
