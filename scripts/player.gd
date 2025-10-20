extends CharacterBody2D
class_name Player

@export var tile_size: int = 16
@export var move_speed: float = 128.0 # pixels per second
@export var attack_duration: float = 0.4

@onready var anim: AnimationPlayer = $AnimationPlayer

var moving: bool = false
var target_position: Vector2
var direction: Vector2 = Vector2.ZERO

var attacking: bool = false
var idling: bool = true
var enemies: Array = [] # nearby enemies tracked via signals
var threatened: bool = false
var attack_power: int = 1

var dead: bool = false


func _ready():
	anim.play("idle_down")
	target_position = global_position
	direction = Vector2.DOWN
	GlobalData.player_can_move = true


func _physics_process(delta):
	if GlobalData.hit_points <= 0:
		die()
	
	# Only allow input when player is allowed to move
	if !moving and !attacking and !dead and GlobalData.player_can_move:
		handle_input()

	# Always update animation — keeps idle and walk states synced
	update_animation()


# -----------------------------
# Player Input
# -----------------------------
func handle_input():
	var input_vector = Vector2(
		int(Input.is_action_just_pressed("right")) - int(Input.is_action_just_pressed("left")),
		int(Input.is_action_just_pressed("down")) - int(Input.is_action_just_pressed("up"))
	)

	# Prevent diagonal movement
	if input_vector.x != 0:
		input_vector.y = 0

	if input_vector != Vector2.ZERO:
		if input_vector.x > 0:
			direction = Vector2.RIGHT
		elif input_vector.x < 0:
			direction = Vector2.LEFT
		elif input_vector.y > 0:
			direction = Vector2.DOWN
		elif input_vector.y < 0:
			direction = Vector2.UP

		var next_pos = global_position + direction * tile_size
		var blocked = false

		for enemy in get_tree().get_nodes_in_group("Enemies"):
			if enemy and enemy.global_position.distance_to(next_pos) < 0.1:
				blocked = true
				break

		if not blocked:
			try_move_tile(direction)
		else:
			update_animation()
	
	if Input.is_action_just_pressed("attack") and not attacking:
		attack_action()


# -----------------------------
# Move One Tile
# -----------------------------
func try_move_tile(dir: Vector2):
	var next_pos = global_position + dir * tile_size

	var query = PhysicsRayQueryParameters2D.new()
	query.from = global_position
	query.to = next_pos
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = get_world_2d().direct_space_state.intersect_ray(query)

	if result.size() == 0:
		target_position = next_pos
		move_to_target_tile()
	else:
		update_animation()


# -----------------------------
# Smooth Tile Movement
# -----------------------------
func move_to_target_tile() -> void:
	if moving or not GlobalData.player_can_move:
		return

	moving = true
	GlobalData.player_can_move = false

	var start_pos = global_position
	update_animation()

	# Smooth movement to target tile
	while (global_position - target_position).length() > 0.01:
		var distance = target_position - global_position
		var step = distance.normalized() * move_speed * get_physics_process_delta_time()
		if step.length() > distance.length():
			step = distance
		global_position += step
		update_animation()
		await get_tree().process_frame

	global_position = target_position
	moving = false

	# Start enemy turns
	await handle_enemy_turns()

# -----------------------------
# Handle Enemy Turns
# -----------------------------
func handle_enemy_turns() -> void:
	var enemy_nodes = get_tree().get_nodes_in_group("Enemies")
	if enemy_nodes.size() == 0:
		GlobalData.player_can_move = true
		return

	GlobalData.enemies_taking_turns = true
	GlobalData.enemy_turns_remaining = enemy_nodes.size()

	# Reset occupied tiles at start of turn
	GlobalData.reset_occupied_tiles(global_position, enemy_nodes)

	var last_player_pos = global_position

	for enemy in enemy_nodes:
		if enemy and enemy.has_method("take_turn"):
			await enemy.take_turn(global_position, last_player_pos)
			last_player_pos = global_position

	GlobalData.enemies_taking_turns = false
	GlobalData.player_can_move = true


# -----------------------------
# Unified Animation System
# -----------------------------
func update_animation():
	if moving:
		if direction.x > 0:
			anim.play("walk_right")
		elif direction.x < 0:
			anim.play("walk_left")
		elif direction.y > 0:
			anim.play("walk_down")
		elif direction.y < 0:
			anim.play("walk_up")
	else:
		if direction.x > 0:
			anim.play("idle_right")
		elif direction.x < 0:
			anim.play("idle_left")
		elif direction.y > 0:
			anim.play("idle_down")
		elif direction.y < 0:
			anim.play("idle_up")


# -----------------------------
# Attack
# -----------------------------
func attack_action():
	attacking = true
	idling = false
	if enemies.size() > 0:
		attack(enemies[0])
	else:
		if direction.y > 0:
			anim.play("attack_down")
		elif direction.y < 0:
			anim.play("attack_up")
		elif direction.x < 0:
			anim.play("attack_left")
		elif direction.x > 0:
			anim.play("attack_right")
	$AttackTimer.start()


func attack(body):
	if not attacking:
		attacking = true
		$AttackTimer.start()

		var diff = body.global_position - global_position
		if abs(diff.x) > abs(diff.y):
			if diff.x > 0:
				direction = Vector2.RIGHT
				anim.play("attack_right")
			else:
				direction = Vector2.LEFT
				anim.play("attack_left")
		else:
			if diff.y > 0:
				direction = Vector2.DOWN
				anim.play("attack_down")
			else:
				direction = Vector2.UP
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
		match direction:
			Vector2.DOWN:
				anim.play("death_down")
			Vector2.UP:
				anim.play("death_up")
			Vector2.LEFT:
				anim.play("death_left")
			Vector2.RIGHT:
				anim.play("death_right")
		GlobalData.hit_points = 0


# -----------------------------
# Enemy Detection
# -----------------------------
func _on_hit_box_body_entered(body):
	if body is Enemy:
		threatened = true
		if not enemies.has(body):
			enemies.append(body)

func _on_hit_box_body_exited(body):
	if body is Enemy:
		if enemies.has(body):
			enemies.erase(body)
		if enemies.size() == 0:
			threatened = false
