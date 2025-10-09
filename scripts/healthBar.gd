extends Node2D

# Frame constants for your tilesheet
const FRAME_EMPTY_LEFT = 6
const FRAME_FULL_LEFT = 3
const FRAME_EMPTY_MID = 7
const FRAME_FULL_MID = 4
const FRAME_EMPTY_RIGHT = 8
const FRAME_FULL_RIGHT = 5
const FRAME_FULL_SINGLE = 10

@export var segment_sprites: Array[Sprite2D] = []  # Assign your 8 Sprite2D nodes here

func _process(_delta: float) -> void:
	update_health_bar()

func update_health_bar() -> void:
	for i in range(GlobalData.max_health):
		var sprite := segment_sprites[i]

		# Special case: single segment filled
		if GlobalData.current_health == 1 and i == 0:
			sprite.frame = FRAME_FULL_SINGLE
			continue

		# Left edge
		if i == 0:
			sprite.frame = FRAME_FULL_LEFT if GlobalData.current_health > 0 else FRAME_EMPTY_LEFT
			continue

		# Right edge
		if i == GlobalData.max_health - 1:
			sprite.frame = FRAME_FULL_RIGHT if GlobalData.current_health > i else FRAME_EMPTY_RIGHT
			continue

		# The "end" of current health (the rightmost filled segment)
		if i == GlobalData.current_health - 1 and GlobalData.current_health < GlobalData.max_health:
			sprite.frame = FRAME_FULL_RIGHT
			continue

		# Middle segments
		sprite.frame = FRAME_FULL_MID if GlobalData.current_health > i else FRAME_EMPTY_MID
