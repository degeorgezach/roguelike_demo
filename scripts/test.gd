extends StaticBody2D


func _ready():
	GlobalData.Player = $Player
	GlobalData.occupied_tiles.clear()
	for wall in get_tree().get_nodes_in_group("Walls"):
		GlobalData.occupied_tiles.append(wall.global_position)


func _on_attack_timer_timeout() -> void:
	pass # Replace with function body.
