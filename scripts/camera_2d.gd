extends Camera2D

var shake_strength: float = 0.0
var shake_decay: float = 5.0  # how fast the shake fades out
var shake_amount: float = 2.0 # maximum pixel offset

func _process(delta: float) -> void:
	if shake_strength > 0:
		offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		) * shake_strength
		shake_strength = lerp(shake_strength, 0.0, delta * shake_decay)
	else:
		offset = Vector2.ZERO

func shake(intensity: float = 1.0):
	shake_strength = intensity
