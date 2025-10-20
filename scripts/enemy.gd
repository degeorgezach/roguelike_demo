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
var hurting = false
var dying = false
var dead = false
var pendingDamage = 0
var hit_points = 0
var max_hit_points = 0

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



func hurt(value: int) -> void:
	if dying or dead or hurting:
		return

	pendingDamage = value
	var newHP = hit_points - pendingDamage
	hit_points = newHP

	if newHP <= 0:
		die()
		return

	hurting = true
	attacking = false
	dying = false

	# Pick hurt animation direction
	var anim_name = ""
	if down:
		anim_name = "hurt_down"
	elif up:
		anim_name = "hurt_up"
	elif left:
		anim_name = "hurt_left"
	elif right:
		anim_name = "hurt_right"
	else:
		anim_name = "hurt_down"

	play_animation(anim_name)
	$HurtTimer.start()



func die() -> void:
	if dying or dead:
		return

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

	# Choose correct death animation
	var anim_name = ""
	if down:
		anim_name = "death_down"
	elif up:
		anim_name = "death_up"
	elif left:
		anim_name = "death_left"
	elif right:
		anim_name = "death_right"
	else:
		anim_name = "death_down"

	play_animation(anim_name)
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


# --------------------------------------------------
# Timers
# --------------------------------------------------

func _on_attack_timer_timeout() -> void:
	pass # Replace with function body.
	
	
	
func _on_hurt_timer_timeout() -> void:
	$HurtTimer.stop()
	hurting = false
	update_idle_animation()


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
