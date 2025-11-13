extends Enemy


func _ready():
	super._ready()
	hit_points = 6
	max_hit_points = hit_points
	$HealthBar.max_value = max_hit_points
	$HealthBar.value = max_hit_points
	move_speed = 64
	detection_radius = 64
