extends Node


var Player

var max_health = 12
var hit_points = 12

var player_can_move
var enemies_taking_turns: bool = false
var enemy_turns_remaining: int = 0


var occupied_tiles: Array = []

# Suppose you have a TileMap called "Walls"
func populate_occupied_tiles():
	GlobalData.occupied_tiles.clear()

	# Add all wall tiles
	var walls = get_tree().get_nodes_in_group("Walls")
	for wall in walls:
		GlobalData.occupied_tiles.append(wall.global_position)

	# Add player position
	GlobalData.occupied_tiles.append(GlobalData.Player.global_position)
