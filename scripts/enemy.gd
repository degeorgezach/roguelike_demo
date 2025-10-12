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
var respawn_time = 30

func _ready():
	$RespawnTimer.timeout.connect(_on_respawn_timer_timeout)
	original_position = global_position
	respawn_time = 10
	threatened = false
	attacking = false
	hurting = false
	dying = false
	dead = false
	is_chasing = false
	is_returning = false
	up = false
	down = true
	left = false
	right = false
	
	
func _process(delta):
	if GlobalData.Player != null:
		if threatened and !attacking and !hurting and !dying and !dead and GlobalData.hit_points > 0:
			attack(GlobalData.Player)
		var distance_to_player = global_position.distance_to(GlobalData.Player.global_position)
		var distance_from_home = global_position.distance_to(original_position)		
		if distance_to_player < detection_radius and distance_to_player > detection_radius_min:
			is_chasing = true
			is_returning = false
		elif is_chasing and distance_to_player > detection_radius:
			is_chasing = false
			is_returning = true
		elif distance_to_player < detection_radius and distance_to_player <= detection_radius_min:
			is_chasing = false
			is_returning = false
		elif GlobalData.hit_points <= 0:
			is_chasing = false
			is_returning = true
			threatened = false
			attacking = false
			$AnimationPlayer.stop()
		elif distance_from_home < 1 and distance_from_home > -1:
			home = true
			up = false
			down = false
			right = false
			left = false
			is_chasing = false
			is_returning = false
			$AnimationPlayer.play("idle_down")
			
		if is_chasing:
			chase_player(delta)
		elif is_returning:
			return_to_original_position(delta)
			
	if !threatened and !attacking and !hurting and !dying and !dead and !is_chasing and !is_returning:
		if down:
			$AnimationPlayer.play("idle_down")
		elif right:
			$AnimationPlayer.play("idle_right")
		elif left:
			$AnimationPlayer.play("idle_left")
		elif up:
			$AnimationPlayer.play("idle_up")
		else:
			$AnimationPlayer.play("idle_down")
			
	if GlobalData.hit_points <= 0 and !dead and !dying:
		if !is_returning:
			is_returning = true
			is_chasing = false
			threatened = false

func _on_hit_box_body_entered(body):
	if body is Player:
		threatened = true
		attack(GlobalData.Player)


func _on_hit_box_body_exited(body):
	if body is Player:
		threatened = false


func attack(body):
	if GlobalData.hit_points <= 0:
		# Stop attacking and go back home
		attacking = false
		threatened = false
		is_chasing = false
		is_returning = true
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
				await $AnimationPlayer.animation_finished
			else:
				down = false
				up = false
				right = false
				left = true
				$AnimationPlayer.play("attack_left")
				await $AnimationPlayer.animation_finished
		else:
			if direction.y > 0:
				down = true
				up = false
				right = false
				left = false
				$AnimationPlayer.play("attack_down")
				await $AnimationPlayer.animation_finished
			else:
				down = false
				up = true
				right = false
				left = false
				$AnimationPlayer.play("attack_up")
				await $AnimationPlayer.animation_finished
	else:
		$AnimationPlayer.stop()



func hurt(value):
	
	if !dying and !dead and !hurting:
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
			if down:
				$AnimationPlayer.play("hurt_down")
			if left:
				$AnimationPlayer.play("hurt_left")
			if right:
				$AnimationPlayer.play("hurt_right")
			if up:
				$AnimationPlayer.play("hurt_up")
		hit_points = newHP
		return newHP


func die():
	if !dying:
		#GlobalData.Player.gain_exp(xp)
		dying = true
		$DeathTimer.start()
		$DyingTimer.start()
		if down:
			$AnimationPlayer.play("hurt_down")
		if left:
			$AnimationPlayer.play("hurt_left")
		if right:
			$AnimationPlayer.play("hurt_right")
		if up:
			$AnimationPlayer.play("hurt_up")


func chase_player(_delta):
	if GlobalData.hit_points > 0:
		if move_speed == 0:
			threatened = true
			
		if !hurting and !attacking and !dying and !dead:
			var direction = (GlobalData.Player.global_position - global_position).normalized()
			velocity = direction * move_speed
			move_and_slide()
			var upDown = abs(velocity.y) > abs(velocity.x)
			var leftRight = abs(velocity.x) > abs(velocity.y)
			if upDown:
				if velocity.y > 0 and !down:
					down = true
					up = false
					right = false
					left = false
					$AnimationPlayer.play("walk_down");
				elif velocity.y < 0 and !up:
					down = false
					up = true
					right = false
					left = false
					$AnimationPlayer.play("walk_up");
			elif leftRight:
				if velocity.x > 0 and !right:
					down = false
					up = false
					right = true
					left = false
					$AnimationPlayer.play("walk_right");
				elif velocity.x < 0 and !left:
					down = false
					up = false
					right = false
					left = true
					$AnimationPlayer.play("walk_left");


func return_to_original_position(_delta):
	threatened = false
	
	if !hurting and !attacking and !dying and !dead:
		var direction = (original_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()		
		var upDown = abs(velocity.y) > abs(velocity.x)
		var leftRight = abs(velocity.x) > abs(velocity.y)
		if upDown:
			if velocity.y > 0 and !down:
				down = true
				up = false
				right = false
				left = false
				$AnimationPlayer.play("walk_down");
			elif velocity.y < 0 and !up:
				down = false
				up = true
				right = false
				left = false
				$AnimationPlayer.play("walk_up");
		elif leftRight:
			if velocity.x > 0 and !right:
				down = false
				up = false
				right = true
				left = false
				$AnimationPlayer.play("walk_right");
			elif velocity.x < 0 and !left:
				down = false
				up = false
				right = false
				left = true
				$AnimationPlayer.play("walk_left");


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
	$AnimationPlayer.play("idle_down")


# TIMER TIMEOUTS -----------------------------------------------------------------------------------


func _on_hurt_timer_timeout():
	$AnimationPlayer.stop()
	$HurtTimer.stop()
	#hit_points -= pendingDamage
	hurting = false	
	up = false
	down = false
	right = false
	left = false


func _on_death_timer_timeout():
	dead = true
	$DeathTimer.stop()
	
	#if randf() <= gold_drop_chance:
		#var gold_scene = load("res://scenes/pickups/gold.tscn")
		#var gold_instance = gold_scene.instantiate()
		#gold_instance.position = position  # Place it where the enemy died
		#get_parent().add_child(gold_instance)
		
	#queue_free()
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
	up = false
	down = false
	right = false
	left = false


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
