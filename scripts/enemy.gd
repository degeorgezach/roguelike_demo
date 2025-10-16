extends CharacterBody2D

class_name Enemy

var threatened = false
var attacking = false
var hurting = false
var dying = false
var dead = false

# these directions could be changed to behave like player
var up = false
var down = false
var left = false
var right = false


var original_position
var is_chasing = false
var is_returning = false
var home = true
var hit_points = 0
var max_hit_points = 0
var detection_radius = 200
var detection_radius_min = 48
var xp = 0
var move_speed = 32
var pendingDamage = 0
var gold_drop_chance = 0.25
var attack_power = 1
var hit_margin = 16
var arrow_direction 
var respawn_time = 0

func _ready():
	$RespawnTimer.timeout.connect(_on_respawn_timer_timeout)
	original_position = global_position
	respawn_time = 100000000
	threatened = false
	attacking = false
	hurting = false
	dying = false
	dead = false
	is_chasing = false
	is_returning = false
	
	var directions = ["up", "down", "left", "right"]
	var chosen_direction = directions[randi() % directions.size()]	
	up = false
	down = false
	left = false
	right = false
	
	set(chosen_direction, true)
	$AnimationPlayer.play("idle_" + chosen_direction)


func _process(delta):
	if GlobalData.Player == null:
		return
		
	if hurting or dying or dead:
		return  # skip everything else while hurt/dying

	var distance_to_player = global_position.distance_to(GlobalData.Player.global_position)
	var distance_from_home = global_position.distance_to(original_position)

	# Only attack when very close (within melee range)
	if threatened and distance_to_player <= detection_radius_min and !attacking and !hurting and !dying and !dead and GlobalData.hit_points > 0:
		attack(GlobalData.Player)

	if distance_to_player < detection_radius and distance_to_player > detection_radius_min:
		is_chasing = true
		is_returning = false
	elif is_chasing and distance_to_player > detection_radius:
		is_chasing = false
		is_returning = true
	elif distance_to_player < detection_radius and distance_to_player <= detection_radius_min:
		is_chasing = false
		is_returning = false

	if GlobalData.hit_points <= 0:
		is_chasing = false
		is_returning = true
		threatened = false
		attacking = false
		#$AnimationPlayer.stop()

	if is_chasing:
		chase_player(delta)
	elif is_returning:
		return_to_original_position(delta)
	else:
		# Idle animation when not moving or attacking
		if !threatened and !attacking and !hurting and !dying and !dead:
			if down:
				play_animation("idle_down")
			elif up:
				play_animation("idle_up")
			elif left:
				play_animation("idle_left")
			elif right:
				play_animation("idle_right")





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



var current_animation = ""

func play_animation(name):
	if current_animation != name:
		$AnimationPlayer.play(name)
		current_animation = name



func _on_hit_box_body_entered(body):
	if body is Player:
		threatened = true
		attack(GlobalData.Player)


func _on_hit_box_body_exited(body):
	if body is Player:
		threatened = false
		# If the player leaves, immediately cancel any in-progress attack
		cancel_attack()



func attack(body):
	if GlobalData.hit_points <= 0:
		# Stop attacking and go back home
		attacking = false
		threatened = false
		is_chasing = false
		is_returning = true
		update_animation_from_velocity()
		return
		
	if !attacking and !dying and !hurting:
		attacking = true
		$AttackTimer.start()
		$MidSwingTimer.start()
		var direction = body.global_position - global_position
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				down = false
				up = false
				right = true
				left = false
				$AnimationPlayer.play("attack_right")
			else:
				down = false
				up = false
				right = false
				left = true
				$AnimationPlayer.play("attack_left")
		else:
			if direction.y > 0:
				down = true
				up = false
				right = false
				left = false
				$AnimationPlayer.play("attack_down")
			else:
				down = false
				up = true
				right = false
				left = false
				$AnimationPlayer.play("attack_up")
	else:
		$AnimationPlayer.stop()



func cancel_attack():
	# Do not cancel attacks if we're dying/dead — let die() and dying timers handle animations
	if dying or dead:
		return

	if attacking:
		attacking = false
		$AttackTimer.stop()
		$MidSwingTimer.stop()
		# stop attack animation so we can switch to walk/idle
		if not dying and not dead:
			update_animation_from_velocity()
		# If chasing, resume walk animation based on current velocity/direction
		if is_chasing:
			update_animation_from_velocity()
		else:
			# fallback to idle that matches last known facing
			if down:
				play_animation("idle_down")
			elif up:
				play_animation("idle_up")
			elif left:
				play_animation("idle_left")
			elif right:
				play_animation("idle_right")




func hurt(value):
	if dying or dead or hurting:
		return
	
	pendingDamage = value
	if hit_points == null:
		hit_points = 0
	var newHP = hit_points - pendingDamage
	
	if newHP <= 0:
		$AnimationPlayer.stop()
		die()
	else:
		hurting = true
		attacking = false
		$HurtTimer.start()
		
		# Play appropriate hurt animation (only one)
		if down:
			play_animation("hurt_down")
		elif left:
			play_animation("hurt_left")
		elif right:
			play_animation("hurt_right")
		elif up:
			play_animation("hurt_up")
	
	hit_points = newHP
	return newHP



func die():
	if dying or dead:
		return
			
	$CollisionShape2D.disabled = true
	dying = true
	hurting = false
	attacking = false
	threatened = false
	is_chasing = false
	is_returning = false

	$HurtTimer.stop()
	$AttackTimer.stop()
	$MidSwingTimer.stop()

	# Determine facing if none set
	if not (up or down or left or right):
		if abs(velocity.y) > abs(velocity.x):
			down = velocity.y > 0
			up = velocity.y < 0
		else:
			left = velocity.x < 0
			right = velocity.x > 0
		if not (up or down or left or right):
			down = true

	# Play death animation immediately
	if down:
		play_animation("death_down")
	elif up:
		play_animation("death_up")
	elif left:
		play_animation("death_left")
	elif right:
		play_animation("death_right")

	$DeathTimer.start()




func chase_player(_delta):
	if dead or dying or hurting:
		return

	var direction = (GlobalData.Player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	# Force walking animation if not currently attacking
	if !attacking:
		update_animation_from_velocity()
	else:
		# Attack in progress, don't move/animate
		velocity = Vector2.ZERO




func return_to_original_position(_delta):
	threatened = false

	if hurting or attacking or dying or dead:
		return

	var distance = global_position.distance_to(original_position)

	# Stop movement if very close to home
	if distance < 1:
		velocity = Vector2.ZERO
		is_returning = false
		home = true

		# Reset direction and play idle once
		down = true
		up = false
		left = false
		right = false
		play_animation("idle_down")
		return

	# Move toward home
	var direction = (original_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	# Update animation based on velocity
	update_animation_from_velocity()






func is_player_hit() -> bool:
	var player_position = GlobalData.Player.global_position
	var enemy_position = global_position

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
		if abs(difference.y) <= hit_margin and (sign(difference.x) == sign(arrow_direction.x) or difference.x == 0):
			return true
			
	elif arrow_direction == Vector2(0, 1) or arrow_direction == Vector2(0, -1):  # Up/Down
		if abs(difference.x) <= hit_margin and (sign(difference.y) == sign(arrow_direction.y) or difference.y == 0):
			return true

	return false


func respawn():
	dead = false
	dying = false
	hurting = false
	hit_points = max_hit_points
	global_position = original_position
	reactivate_enemy()
	
	
func deactivate_enemy():
	hide()
	set_process(false)
	set_physics_process(false)
	$HitBox.monitoring = false
	$HitBox.set_deferred("monitorable", false)
	$HitBox/CollisionShape2D.disabled = true
	$CollisionShape2D.disabled = true
	$HitBox/CollisionShape2D.set_deferred("disabled", true)

func reactivate_enemy():
	show()
	set_process(true)
	set_physics_process(true)
	$HitBox.monitoring = true
	$HitBox.set_deferred("monitorable", true)
	$HitBox/CollisionShape2D.disabled = false
	$CollisionShape2D.disabled = false
	$HitBox/CollisionShape2D.set_deferred("disabled", false)
	down = true
	$AnimationPlayer.play("idle_down")


# TIMER TIMEOUTS -----------------------------------------------------------------------------------


func _on_hurt_timer_timeout():
	# Stop the hurt timer but preserve facing flags for subsequent animations (including death)
	$HurtTimer.stop()
	hurting = false
	# Instead of clearing facing, just choose an idle/walk based on movement
	if velocity.length() == 0:
		# idle matching facing
		if down:
			play_animation("idle_down")
		elif up:
			play_animation("idle_up")
		elif left:
			play_animation("idle_left")
		elif right:
			play_animation("idle_right")
	else:
		update_animation_from_velocity()



func _on_death_timer_timeout():
	$DeathTimer.stop()
	dead = true
	dying = false
	
	# Begin respawn timer and cleanup
	$RespawnTimer.wait_time = respawn_time
	$RespawnTimer.start()
	deactivate_enemy()


func _on_mid_swing_timer_timeout():
	if GlobalData.Player != null and threatened and !hurting and !dying and attacking:
		if move_speed == 0:
			if is_player_hit():
				GlobalData.Player.hurt(attack_power)
		else:
			GlobalData.Player.hurt(attack_power)
	$MidSwingTimer.stop()


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


func _on_respawn_timer_timeout() -> void:
	$RespawnTimer.stop()
	respawn()

# END REGION ---------------------------------------------------------------------------------------
