extends Node

var damage = 1

func deal_damage(enemy: Enemy):
	enemy.current_hp -= enemy.current_hp - damage
