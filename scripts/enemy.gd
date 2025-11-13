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

var is_visible_on_screen = false

@export var book_scene: PackedScene


# --------------------------------------------------
# Setup
# --------------------------------------------------
func _ready():
	if home_position == Vector2.ZERO:
		home_position = global_position
	target_position = global_position
	anim.play("idle_down")
	add_to_group("Enemies")
	var notifier = $VisibleOnScreenNotifier2D
	notifier.connect("screen_entered", Callable(self, "_on_screen_entered"))
	notifier.connect("screen_exited", Callable(self, "_on_screen_exited"))


# --- Helpers ---
func _on_screen_entered():
	is_visible_on_screen = true

func _on_screen_exited():
	is_visible_on_screen = false

# Return integer grid Vector2 (same basis as your grid_pos)
func _grid_vec(v: Vector2) -> Vector2:
	return Vector2(int(v.x), int(v.y))

# Check if a grid cell is occupied according to GlobalData.occupied_tiles.
# We allow 'start' to be considered free (so BFS can start from the enemy's current cell).
func _is_occupied(grid: Vector2, start: Vector2) -> bool:
	var g = _grid_vec(grid)
	var s = _grid_vec(start)
	if g == s:
		return false
	for o in GlobalData.occupied_tiles:
		if _grid_vec(o) == g:
			return true
	return false

# BFS to find a path from start_grid to any free neighbor of target_grid.
# Returns an Array of grid positions (Vector2) from start to goal (inclusive).
# If no path found returns empty Array.
func _find_path_to_adjacent(start_grid: Vector2, target_grid: Vector2) -> Array:
	var start = _grid_vec(start_grid)
	var target = _grid_vec(target_grid)
	var dirs = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]

	# Collect goal neighbor cells (cardinal neighbors of the player) that are not occupied.
	var goal_neighbors = []
	for d in dirs:
		var n = target + d
		if not _is_occupied(n, start):
			goal_neighbors.append(n)
	if goal_neighbors.size() == 0:
		return []

	# BFS structures
	var q = []
	var came_from = {} # key: "x,y" -> Vector2 parent
	var start_key = "%d,%d" % [int(start.x), int(start.y)]
	q.append(start)
	came_from[start_key] = null

	while q.size() > 0:
		var cur = q.pop_front()
		# If this cell matches any goal neighbor, reconstruct the path
		for gn in goal_neighbors:
			if _grid_vec(cur) == _grid_vec(gn):
				# reconstruct path from start -> cur
				var path = []
				var node = cur
				while node != null:
					path.insert(0, node)
					var node_key = "%d,%d" % [int(node.x), int(node.y)]
					node = came_from.get(node_key, null)
				return path
		# expand neighbors
		for d in dirs:
			var n = _grid_vec(cur) + d
			var n_key = "%d,%d" % [int(n.x), int(n.y)]
			if came_from.has(n_key):
				continue
			# skip occupied (respecting start)
			if _is_occupied(n, start):
				continue
			came_from[n_key] = cur
			q.append(n)

	# no path
	return []


# Utility: Convert world pos to grid coordinate 
func grid_pos(pos: Vector2) -> Vector2: return Vector2(round(pos.x / tile_size), round(pos.y / tile_size))

func take_turn(player_pos: Vector2, last_player_pos: Vector2) -> void:
	# rebuild occupied tiles (walls + other enemies)
	GlobalData.occupied_tiles.clear()

	for wall in get_tree().get_nodes_in_group("WallTiles"):
		GlobalData.occupied_tiles.append(grid_pos(wall.global_position))

	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if enemy != self:
			GlobalData.occupied_tiles.append(grid_pos(enemy.global_position))

	var distance_to_player = global_position.distance_to(player_pos)
	var diff = player_pos - global_position
	var move_dir: Vector2 = Vector2.ZERO

	# --- If close enough to attack ---
	if distance_to_player <= tile_size * 1.1:
		if abs(diff.x) > abs(diff.y):
			direction = Vector2(sign(diff.x), 0)
		else:
			direction = Vector2(0, sign(diff.y))
		if !hurting and !dying:
			update_idle_animation()
		await attack_action()

	else:
		# --- Chase player if detected ---
		if distance_to_player <= detection_radius:
			var dx = int(sign(diff.x))
			var dy = int(sign(diff.y))

			# Are we already cardinally adjacent? Use grid coords (safer)
			var enemy_grid = grid_pos(global_position)
			var player_grid = grid_pos(player_pos)
			var horizontal_adjacent = (abs(player_grid.x - enemy_grid.x) == 1 and player_grid.y == enemy_grid.y)
			var vertical_adjacent = (abs(player_grid.y - enemy_grid.y) == 1 and player_grid.x == enemy_grid.x)
			if horizontal_adjacent or vertical_adjacent:
				move_dir = Vector2.ZERO
			else:
				# Choose primary and secondary directions
				var primary: Vector2
				var secondary: Vector2
				if abs(diff.x) >= abs(diff.y):
					primary = Vector2(dx, 0)
					secondary = Vector2(0, dy)
				else:
					primary = Vector2(0, dy)
					secondary = Vector2(dx, 0)

				# Try primary axis first (try_move_tile sets target_position if valid)
				if try_move_tile(primary, player_pos):
					move_dir = primary
				elif try_move_tile(secondary, player_pos):
					move_dir = secondary
				else:
					# Both immediate cardinal moves blocked — attempt BFS to any free adjacent tile
					var path = _find_path_to_adjacent(enemy_grid, player_grid)
					if path.size() >= 2:
						# path[0] == enemy_grid, path[1] is next step (grid)
						var next_step = path[1]
						var step_delta = _grid_vec(next_step) - _grid_vec(enemy_grid)
						var step_dir = Vector2(int(step_delta.x), int(step_delta.y))
						# Attempt that step (BFS ensured it's not in GlobalData.occupied_tiles,
						# but try_move_tile still checks collisions/test_move)
						if try_move_tile(step_dir, player_pos):
							move_dir = step_dir
						else:
							move_dir = Vector2.ZERO
					else:
						move_dir = Vector2.ZERO

		else:
			# --- Wander randomly --- 
			# (CALL try_move_tile here — previously you only set move_dir)
			if randf() < wander_chance:
				var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
				var pick = dirs[randi() % dirs.size()]
				# validate the random pick using try_move_tile
				if try_move_tile(pick, player_pos):
					move_dir = pick
				else:
					move_dir = Vector2.ZERO

		# --- Move if target_position was set by try_move_tile ---
		# try_move_tile already sets target_position and direction when it returns true.
		if move_dir != Vector2.ZERO and target_position != global_position:
			GlobalData.occupied_tiles.append(grid_pos(target_position))
			await move_towards_target()

	# End turn bookkeeping
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
	
	$HealthBar.value = newHP

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
# Health Bar
# --------------------------------------------------







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
	
	if book_scene:
		var book_instance = book_scene.instantiate()
		book_instance.global_position = global_position
		get_tree().current_scene.add_child(book_instance)

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
