extends StaticBody2D


func _ready():
	GlobalData.Player = $Player
	GlobalData.max_health = 10
	GlobalData.hit_points = 10
	GlobalData.occupied_tiles.clear()
	for wall in get_tree().get_nodes_in_group("Walls"):
		GlobalData.occupied_tiles.append(wall.global_position)
