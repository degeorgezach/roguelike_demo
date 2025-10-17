extends CharacterBody2D
class_name Enemy

@export var tile_size: int = 16
@export var move_speed: float = 128
@export var detection_radius: float = 64.0
@export var wander_radius: float = 96.0
@export var wander_chance: float = 0.5

@onready var anim: AnimationPlayer = $AnimationPlayer

var target_position: Vector2
var moving: bool = false
var direction: Vector2 = Vector2.ZERO
var home_position: Vector2 = Vector2.ZERO

func _ready():
	if home_position == Vector2.ZERO:
		home_position = global_position
	target_position = global_position
	anim.play("idle_down")

# Called by player after they move
func take_turn(player_pos: Vector2, last_player_pos: Vector2):
	if moving:
		return # mid-move, skip this turn

	var distance_to_player = global_position.distance_to(player_pos)

	if distance_to_player <= detection_radius:
		move_toward_player(player_pos, last_player_pos)
	else:
		random_wander()

# -----------------------------
# CHASE + WANDER BEHAVIOR
# -----------------------------
func move_toward_player(player_pos: Vector2, last_player_pos: Vector2):
	var delta = player_pos - global_position
	var move_vector = Vector2.ZERO

	# Prefer the largest axis first
	if abs(delta.x) > abs(delta.y):
		move_vector.x = sign(delta.x)
	else:
		move_vector.y = sign(delta.y)

	try_move_tile(move_vector, player_pos, last_player_pos)

func random_wander():
	if randf() < wander_chance:
		var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		var dir = dirs[randi() % dirs.size()]
		var next_pos = global_position + dir * tile_size

		# Keep wandering near home
		if next_pos.distance_to(home_position) <= wander_radius:
			try_move_tile(dir)

# -----------------------------
# MOVEMENT + COLLISION
# -----------------------------
func try_move_tile(dir: Vector2, player_pos: Vector2 = Vector2.INF, last_player_pos: Vector2 = Vector2.INF):
	if dir == Vector2.ZERO:
		return

	var next_pos = global_position + dir * tile_size

	# Avoid stepping on player
	if player_pos != Vector2.INF and next_pos == player_pos:
		moving = false
		return
	elif last_player_pos != Vector2.INF and next_pos == last_player_pos:
		target_position = next_pos
		direction = dir
		update_walk_animation(dir)
		moving = true
		return

	# Normal collision check
	if not test_move(global_transform, dir * tile_size):
		target_position = next_pos
		direction = dir
		update_walk_animation(dir)
		moving = true
	else:
		moving = false

func _physics_process(delta):
	if moving:
		move_towards_target(delta)
	else:
		update_idle_animation()

func move_towards_target(delta):
	var distance = target_position - global_position
	if distance.length() < 0.01:
		global_position = target_position
		moving = false
		return

	var step = distance.normalized() * move_speed * delta
	if step.length() > distance.length():
		step = distance
	global_position += step

# -----------------------------
# ANIMATIONS
# -----------------------------
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
	# Idle based on last move direction
	if direction.x > 0:
		anim.play("idle_right")
	elif direction.x < 0:
		anim.play("idle_left")
	elif direction.y > 0:
		anim.play("idle_down")
	elif direction.y < 0:
		anim.play("idle_up")
