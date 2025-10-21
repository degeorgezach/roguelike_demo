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

var threatened = false
var attacking = false
var queued_attack = false

var hurting = false
var dying = false
var dead = false
var pendingDamage = 0
var hit_points = 0
var max_hit_points = 0

var attack_power = 1

var up = false
var down = false
var left = false
var right = false

var is_chasing = false
var is_returning = false


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

	# --- Determine relationship to player ---
	var distance_to_player = global_position.distance_to(player_pos)
	var diff = player_pos - global_position
	var move_dir: Vector2 = Vector2.ZERO

	# --- If player is within striking distance, ATTACK ---
	if distance_to_player <= tile_size * 1.1:
		# Face toward player
		if abs(diff.x) > abs(diff.y):
			direction = Vector2(sign(diff.x), 0)
		else:
			direction = Vector2(0, sign(diff.y))
		if !hurting and !dying:
			update_idle_animation()

		# Attack
		await attack_action()
	else:
		# --- If player is close enough to chase ---
		if distance_to_player <= detection_radius:
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
	if !hurting and !dying:
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
			if !hurting and !dying:
				update_idle_animation()



func hurt(value):
	if dying or dead:
		return

	if hurting:
		return  # Already taking damage — ignore reentry

	pendingDamage = value
	var newHP = hit_points - pendingDamage

	if newHP <= 0:
		$AnimationPlayer.stop()
		die()
		return

	hurting = true
	attacking = false
	moving = false
	queued_attack = true  # mark that we should attack after hurt finishes
	$HurtTimer.start()

	if down:
		play_animation("hurt_down")
	elif left:
		play_animation("hurt_left")
	elif right:
		play_animation("hurt_right")
	elif up:
		play_animation("hurt_up")

	hit_points = newHP






func die() -> void:
	if dying or dead:
		return

	print("Enemy died")
	dying = true
	hurting = false
	attacking = false
	moving = false
	threatened = false
	is_chasing = false
	is_returning = false

	$CollisionShape2D.disabled = true
	$HurtTimer.stop()
	$AttackTimer.stop()
	$MidSwingTimer.stop()

	var anim_name = ""
	if up:
		anim_name = "death_up"
	elif down:
		anim_name = "death_down"
	elif left:
		anim_name = "death_left"
	elif right:
		anim_name = "death_right"
	else:
		anim_name = "death_down"

	print("Playing animation:", anim_name)
	anim.play(anim_name)

	$DeathTimer.start()







# --------------------------------------------------
# Animations
# --------------------------------------------------
func update_walk_animation(dir: Vector2):
	if dir.x > 0:
		right = true
		left = false
		up = false
		down = false
		anim.play("walk_right")
	elif dir.x < 0:
		right = false
		left = true
		up = false
		down = false
		anim.play("walk_left")
	elif dir.y > 0:
		right = false
		left = false
		up = false
		down = true
		anim.play("walk_down")
	elif dir.y < 0:
		right = false
		left = false
		up = true
		down = false
		anim.play("walk_up")


func update_idle_animation():
	if direction.x > 0:
		right = true
		left = false
		up = false
		down = false
		anim.play("idle_right")
	elif direction.x < 0:
		right = false
		left = true
		up = false
		down = false
		anim.play("idle_left")
	elif direction.y > 0:
		right = false
		left = false
		up = false
		down = true
		anim.play("idle_down")
	elif direction.y < 0:
		right = false
		left = false
		up = true
		down = false
		anim.play("idle_up")


var current_animation = ""

func play_animation(name):
	if current_animation != name:
		$AnimationPlayer.play(name)
		current_animation = name


func deactivate_enemy():
	queue_free()
	#hide()
	#set_process(false)
	#set_physics_process(false)
	#$HitBox.monitoring = false
	#$HitBox.set_deferred("monitorable", false)
	#$HitBox/CollisionShape2D.disabled = true
	#$CollisionShape2D.disabled = true
	#$HitBox/CollisionShape2D.set_deferred("disabled", true)


func is_player_hit() -> bool:
	var player_position = GlobalData.Player.global_position
	var enemy_position = global_position
	var arrow_direction
	# Calculate the difference between player and enemy positions
	var difference = player_position - enemy_position

	if up:
		arrow_direction = Vector2(0, -1)
	elif down:
		arrow_direction = Vector2(0, 1)
	elif left:
		arrow_direction = Vector2(-1, 0)
	elif right:
		arrow_direction = Vector2(1, 0)

	if arrow_direction == Vector2(1, 0) or arrow_direction == Vector2(-1, 0):  # Left/Right
		if (sign(difference.x) == sign(arrow_direction.x) or difference.x == 0):
			return true

	elif arrow_direction == Vector2(0, 1) or arrow_direction == Vector2(0, -1):  # Up/Down
		if (sign(difference.y) == sign(arrow_direction.y) or difference.y == 0):
			return true

	return false



func update_animation_from_velocity():
	if attacking and $AnimationPlayer.is_playing() and current_animation.begins_with("attack"):
		return

	# Determine dominant direction from velocity
	if velocity.length() == 0:
		# Enemy is idle, pick last known direction
		if down:
			play_animation("idle_down")
		elif up:
			play_animation("idle_up")
		elif left:
			play_animation("idle_left")
		elif right:
			play_animation("idle_right")
		return

	if abs(velocity.y) > abs(velocity.x):
		if velocity.y > 0:
			down = true
			up = false
			right = false
			left = false
			play_animation("walk_down")
		else:
			up = true
			down = false
			left = false
			right = false
			play_animation("walk_up")
	else:
		if velocity.x > 0:
			right = true
			up = false
			down = false
			left = false
			play_animation("walk_right")
		else:
			left = true
			up = false
			down = false
			right = false
			play_animation("walk_left")


func attack_action() -> void:
	if attacking or hurting or dying or dead:
		return

	attacking = true
	hurting = false
	dying = false

	# Pick correct attack animation
	var anim_name = ""
	if down:
		anim_name = "attack_down"
	elif up:
		anim_name = "attack_up"
	elif left:
		anim_name = "attack_left"
	elif right:
		anim_name = "attack_right"
	else:
		anim_name = "attack_down"

	play_animation(anim_name)

	# Start timers
	$MidSwingTimer.start()   # This will trigger damage mid-swing
	$AttackTimer.start()     # This resets after attack finishes
	await get_tree().create_timer($AttackTimer.wait_time).timeout




# --------------------------------------------------
# Timers
# --------------------------------------------------

func _on_attack_timer_timeout():
	$AttackTimer.stop()
	attacking = false
	# Do NOT clear facing flags here — we want to preserve last known facing so death/hurt animations can use it.
	# If currently chasing, switch to walk animation now
	if is_chasing:
		update_animation_from_velocity()
	else:
		# otherwise go to idle matching facing (preserves facing flags)
		if down:
			play_animation("idle_down")
		elif up:
			play_animation("idle_up")
		elif left:
			play_animation("idle_left")
		elif right:
			play_animation("idle_right")


func _on_mid_swing_timer_timeout():
	if GlobalData.Player != null and !hurting and !dying and attacking:
		if move_speed == 0:
			if is_player_hit():
				GlobalData.Player.hurt(attack_power)
		else:
			GlobalData.Player.hurt(attack_power)
	$MidSwingTimer.stop()


func _on_hurt_timer_timeout() -> void:
	$HurtTimer.stop()
	hurting = false
	update_idle_animation()

	if queued_attack and !dying and !dead:
		queued_attack = false
		await attack_action()



func _on_death_timer_timeout():
	$DeathTimer.stop()
	dead = true
	dying = false

	# Begin respawn timer and cleanup
	#$RespawnTimer.wait_time = respawn_time
	#$RespawnTimer.start()
	deactivate_enemy()


func _on_dying_timer_timeout():
	$DyingTimer.stop()
	if down:
		$AnimationPlayer.play("death_down")
	if left:
		$AnimationPlayer.play("death_left")
	if right:
		$AnimationPlayer.play("death_right")
	if up:
		$AnimationPlayer.play("death_up")
