extends CharacterBody2D
class_name Player

@export var tile_size: int = 16
@export var move_speed: float = 128.0 # pixels per second
@export var attack_duration: float = 0.4

@onready var anim: AnimationPlayer = $AnimationPlayer

var hurting = false
var dying = false
var pendingDamage = 0
var hit_points

var down = false
var up = false
var right = false
var left = false

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
	elif Input.is_action_just_pressed("pass") and not attacking:
		handle_enemy_turns()


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

	# Mark that enemies are taking turns
	GlobalData.enemies_taking_turns = true
	GlobalData.enemy_turns_remaining = enemy_nodes.size()

	# Save the player's current position
	var last_player_pos = global_position

	# Populate occupied tiles with walls and enemies
	GlobalData.populate_occupied_tiles()

	for enemy in enemy_nodes:
		if enemy and enemy.has_method("take_turn") and enemy.is_visible_on_screen:
			# Pass both current player position and last player position
			await enemy.take_turn(global_position, last_player_pos)
			# Update last_player_pos so next enemy can follow accurately
			last_player_pos = global_position

	# All enemies done
	GlobalData.enemies_taking_turns = false
	GlobalData.player_can_move = true

	# Update occupied tiles for next turn
	GlobalData.populate_occupied_tiles()



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
	elif attacking:
		if direction.x > 0:
			anim.play("attack_right")
		elif direction.x < 0:
			anim.play("attack_left")
		elif direction.y > 0:
			anim.play("attack_down")
		elif direction.y < 0:
			anim.play("attack_up")
	elif hurting:
		if direction.x > 0:
			anim.play("hurt_right")
		elif direction.x < 0:
			anim.play("hurt_left")
		elif direction.y > 0:
			anim.play("hurt_down")
		elif direction.y < 0:
			anim.play("hurt_up")
	elif dying:
		if direction.x > 0:
			anim.play("death_right")
		elif direction.x < 0:
			anim.play("death_left")
		elif direction.y > 0:
			anim.play("death_down")
		elif direction.y < 0:
			anim.play("death_up")
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
	if attacking:
		return

	attacking = true
	idling = false

	var has_target = enemies.size() > 0
	if has_target:
		attack(enemies[0])
	else:
		# play attack animation even if not hitting an enemy
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

	$AttackTimer.start()
	body.hurt(attack_power)
	await handle_enemy_turns()



func _on_attack_timer_timeout():
	$AttackTimer.stop()
	attacking = false
	idling = true


# -----------------------------
# Death
# -----------------------------
func die() -> void:
	if dying or dead:
		return

	print("Player died")
	dying = true
	hurting = false
	attacking = false
	moving = false
	GlobalData.player_can_move = false

	# Pick death animation based on direction
	var anim_name := ""
	match direction:
		Vector2.UP: anim_name = "death_up"
		Vector2.DOWN: anim_name = "death_down"
		Vector2.LEFT: anim_name = "death_left"
		Vector2.RIGHT: anim_name = "death_right"
		_: anim_name = "death_down"

	anim.play(anim_name)

	# Wait for animation to finish before fully dying
	await anim.animation_finished

	dead = true
	dying = false

	print("Death animation finished")
	
	GlobalData.hit_points = GlobalData.max_health
	queue_free()
	get_tree().change_scene_to_file("res://scenes/test.tscn")

	# You can add fade-out or respawn logic here:
	# get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
	# or queue_free()



func hurt(value):
	if dying or dead or hurting:
		return

	pendingDamage = value
	if GlobalData.hit_points == null:
		GlobalData.hit_points = 0
	var newHP = GlobalData.hit_points - pendingDamage

	if newHP <= 0:
		$AnimationPlayer.stop()
		die()
	else:
		hurting = true
		attacking = false		
		moving = false
		$HurtTimer.start()

		update_animation()

	GlobalData.hit_points = newHP






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


func _on_hurt_timer_timeout() -> void:
	$HurtTimer.stop()
	hurting = false
	update_animation()


func _on_death_timer_timeout() -> void:
	dead = true
	$DeathTimer.stop()
	GlobalData.hit_points = GlobalData.max_health
	queue_free()
	get_tree().change_scene_to_file("res://scenes/test.tscn")
