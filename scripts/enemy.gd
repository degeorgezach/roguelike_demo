extends CharacterBody2D
class_name Enemy

@export var tile_size: int = 16
@export var move_speed: float = 128
@export var detection_radius: float = 48.0
@export var wander_radius: float = 96.0
@export var wander_chance: float = 0.5

@onready var anim: AnimationPlayer = $AnimationPlayer

var target_position: Vector2
var moving: bool = false
var direction: Vector2 = Vector2.ZERO
var home_position: Vector2 = Vector2.ZERO


# --------------------------------------------------
# Setup
# --------------------------------------------------
func _ready():
	if home_position == Vector2.ZERO:
		home_position = global_position
	target_position = global_position
	anim.play("idle_down")
	add_to_group("Enemies")


# Utility: Convert world pos to grid coordinate
func grid_pos(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / tile_size), round(pos.y / tile_size))


# --------------------------------------------------
# Enemy Turn
# --------------------------------------------------
func take_turn(player_pos: Vector2, last_player_pos: Vector2) -> void:
	# Rebuild occupied tiles (walls + other enemies)
	GlobalData.occupied_tiles.clear()

	for wall in get_tree().get_nodes_in_group("WallTiles"):
		GlobalData.occupied_tiles.append(grid_pos(wall.global_position))

	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if enemy != self:
			GlobalData.occupied_tiles.append(grid_pos(enemy.global_position))

	# Decide move
	var move_dir: Vector2 = Vector2.ZERO
	var distance_to_player = global_position.distance_to(player_pos)

	if distance_to_player <= detection_radius:
		# --- Chase player ---
		var diff = player_pos - global_position
		if abs(diff.x) > abs(diff.y):
			move_dir = Vector2(sign(diff.x), 0)
		else:
			move_dir = Vector2(0, sign(diff.y))
	else:
		# --- Wander randomly ---
		if randf() < wander_chance:
			var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			move_dir = dirs[randi() % dirs.size()]

	# Attempt to move (allow stepping on player)
	if try_move_tile(move_dir, player_pos):
		GlobalData.occupied_tiles.append(grid_pos(target_position))

	# Smooth movement to new tile
	await move_towards_target()

	# End turn
	GlobalData.enemy_turns_remaining -= 1
	if GlobalData.enemy_turns_remaining <= 0:
		GlobalData.enemies_taking_turns = false


# --------------------------------------------------
# Try to move in given direction
# --------------------------------------------------
func try_move_tile(dir: Vector2, player_pos: Vector2 = Vector2.INF) -> bool:
	if dir == Vector2.ZERO:
		return false

	var next_pos = global_position + dir * tile_size
	var next_grid = grid_pos(next_pos)
	var player_grid = grid_pos(player_pos)

	# --- Don't move into player tile ---
	if next_grid == player_grid:
		# Optional: trigger an attack or stop
		return false

	# --- Check for wall collisions ---
	if test_move(global_transform, dir * tile_size * 0.5):
		return false

	# --- Check for enemy collisions ---
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if enemy != self and enemy.global_position.distance_to(next_pos) < tile_size * 0.5:
			return false

	# --- Move is valid ---
	target_position = next_pos
	direction = dir
	return true




# --------------------------------------------------
# Smooth movement
# --------------------------------------------------
func move_towards_target() -> void:
	if target_position == global_position:
		return

	moving = true
	update_walk_animation(direction)

	while (global_position - target_position).length() > 0.01:
		var distance = target_position - global_position
		var step = distance.normalized() * move_speed * get_physics_process_delta_time()
		if step.length() > distance.length():
			step = distance
		global_position += step
		await get_tree().process_frame

	global_position = target_position
	moving = false
	update_idle_animation()


# --------------------------------------------------
# Physics (optional)
# --------------------------------------------------
func _physics_process(delta):
	if moving:
		var distance = target_position - global_position
		if distance.length() > 0.01:
			var step = distance.normalized() * move_speed * delta
			if step.length() > distance.length():
				step = distance
			global_position += step
		else:
			global_position = target_position
			moving = false
			update_idle_animation()


# --------------------------------------------------
# Animations
# --------------------------------------------------
func update_walk_animation(dir: Vector2):
	if dir.x > 0:
		anim.play("walk_right")
	elif dir.x < 0:
		anim.play("walk_left")
	elif dir.y > 0:
		anim.play("walk_down")
	elif dir.y < 0:
		anim.play("walk_up")


func update_idle_animation():
	if direction.x > 0:
		anim.play("idle_right")
	elif direction.x < 0:
		anim.play("idle_left")
	elif direction.y > 0:
		anim.play("idle_down")
	elif direction.y < 0:
		anim.play("idle_up")
