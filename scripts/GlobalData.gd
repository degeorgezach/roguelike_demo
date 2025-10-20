extends Node


var Player

var max_health = 12
var hit_points = 12

var player_can_move
var enemies_taking_turns: bool = false
var enemy_turns_remaining: int = 0


var occupied_tiles: Array = []

func reset_occupied_tiles(player_pos: Vector2, enemy_nodes: Array) -> void:
	occupied_tiles.clear()
	occupied_tiles.append(player_pos)
	for enemy in enemy_nodes:
		if enemy:
			occupied_tiles.append(enemy.global_position)
