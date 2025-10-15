extends Enemy


func _ready():
	super._ready()
	original_position = global_position
	hit_points = 4
	max_hit_points = hit_points
	xp = 40
	move_speed = 24
	detection_radius  = 64
	detection_radius_min = 16
