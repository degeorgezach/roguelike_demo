extends CharacterBody2D
class_name Player

@export var tile_size: int = 16
@export var move_speed: float = 128.0  # pixels per second
@export var attack_duration: float = 0.4

@onready var anim: AnimationPlayer = $AnimationPlayer

var moving: bool = false
var target_position: Vector2
var direction: Vector2 = Vector2.ZERO

var attacking: bool = false
var idling: bool = true
var enemies: Array = []
var threatened: bool = false
var attack_power: int = 1

# Direction flags
var up: bool = false
var down: bool = true
var left: bool = false
var right: bool = false

var dead: bool = false

func _ready():
	anim.play("idle_down")
	target_position = global_position


func _physics_process(delta):
	if GlobalData.hit_points <= 0:
		die()
	
	if not moving and not attacking and not dead:
		handle_input()

	if not moving:
		update_idle_animation()


# -----------------------------
# Player Input
# -----------------------------
func handle_input():
	var input_vector = Vector2(
		int(Input.is_action_just_pressed("right")) - int(Input.is_action_just_pressed("left")),
		int(Input.is_action_just_pressed("down")) - int(Input.is_action_just_pressed("up"))
	)
	
	if input_vector != Vector2.ZERO:
		direction = input_vector
		try_move_tile(direction)
	
	if Input.is_action_just_pressed("attack") and not attacking:
		attack_action()


# -----------------------------
# Move One Tile
# -----------------------------
func try_move_tile(dir: Vector2):
	var next_pos = global_position + dir * tile_size

	# Collision ray
	var query = PhysicsRayQueryParameters2D.new()
	query.from = global_position
	query.to = next_pos
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 0x7FFFFFFF

	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result.size() == 0:
		target_position = next_pos
		update_walk_animation()
		move_to_target_tile()  # async movement
	else:
		moving = false


# -----------------------------
# Smooth Tile Movement
# -----------------------------
func move_to_target_tile() -> void:
	if moving:
		return

	moving = true
	var start_pos = global_position

	while (global_position - target_position).length() > 0.01:
		var distance = target_position - global_position
		var step = distance.normalized() * move_speed * get_physics_process_delta_time()
		if step.length() > distance.length():
			step = distance
		global_position += step
		await get_tree().process_frame  # wait one frame

	global_position = target_position
	moving = false

	# -----------------------------
	# Player finished moving, now enemies take turns
	# -----------------------------
	var last_pos = start_pos
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if enemy and enemy.has_method("take_turn"):
			enemy.take_turn(global_position, last_pos)


# -----------------------------
# Animations
# -----------------------------
func update_walk_animation():
	if direction.x > 0:
		right = true
		left = false
		up = false
		down = false
		anim.play("walk_right")
	elif direction.x < 0:
		left = true
		right = false
		up = false
		down = false
		anim.play("walk_left")
	elif direction.y > 0:
		down = true
		up = false
		left = false
		right = false
		anim.play("walk_down")
	elif direction.y < 0:
		up = true
		down = false
		left = false
		right = false
		anim.play("walk_up")


func update_idle_animation():
	if down:
		anim.play("idle_down")
	elif up:
		anim.play("idle_up")
	elif left:
		anim.play("idle_left")
	elif right:
		anim.play("idle_right")


# -----------------------------
# Attack
# -----------------------------
func attack_action():
	attacking = true
	idling = false
	if enemies.size() > 0:
		attack(enemies[0])
	else:
		if down:
			anim.play("attack_down")
		elif up:
			anim.play("attack_up")
		elif left:
			anim.play("attack_left")
		elif right:
			anim.play("attack_right")
	$AttackTimer.start()


func attack(body):
	if not attacking:
		attacking = true
		$AttackTimer.start()
		var diff = body.global_position - global_position
		if abs(diff.x) > abs(diff.y):
			if diff.x > 0:
				right = true
				left = false
				up = false
				down = false
				anim.play("attack_right")
			else:
				left = true
				right = false
				up = false
				down = false
				anim.play("attack_left")
		else:
			if diff.y > 0:
				down = true
				up = false
				left = false
				right = false
				anim.play("attack_down")
			else:
				up = true
				down = false
				left = false
				right = false
				anim.play("attack_up")
		body.hurt(attack_power)


func _on_attack_timer_timeout():
	$AttackTimer.stop()
	attacking = false
	idling = true


# -----------------------------
# Death
# -----------------------------
func die():
	if not dead:
		dead = true
		$AnimationPlayer.stop()
		$DeathTimer.start()
		if down:
			anim.play("death_down")
		elif up:
			anim.play("death_up")
		elif left:
			anim.play("death_left")
		elif right:
			anim.play("death_right")
		GlobalData.hit_points = 0


# -----------------------------
# Enemy Detection
# -----------------------------
func _on_hit_box_body_entered(body):
	if body is Enemy:
		threatened = true
		enemies.append(body)


func _on_hit_box_body_exited(body):
	if body is Enemy:
		if enemies.has(body):
			enemies.erase(body)
		if enemies.size() == 0:
			threatened = false
