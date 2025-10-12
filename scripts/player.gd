extends CharacterBody2D

class_name Player

@export var speed: float = 60.0
@onready var anim: AnimationPlayer = $AnimationPlayer
@export var attack_duration: float = 0.4
var attacking: bool = false
var last_direction: String = "down"

var up = false
var down = false
var left = false
var right = false
var attacking2 = false
var hurting = false
var dying = false
var dead = false
var input = Vector2.ZERO
var move_speed = 48
var inputting_movement = false


func _ready():
	$AnimationPlayer.play("idle_down")
	down = true
	

func _physics_process(delta):
	if GlobalData.hit_points <= 0:
		die()
	if !attacking and !attacking2 and !dying and !dead:
		player_movement(delta)

		if !hurting:
			if velocity.length() > 0:
				# Set direction flags based on velocity
				if abs(velocity.x) > abs(velocity.y):
					if velocity.x > 0:
						$AnimationPlayer.play("walk_right")
						right = true
						left = false
						up = false
						down = false
					else:
						$AnimationPlayer.play("walk_left")
						left = true
						right = false
						up = false
						down = false
				else:
					if velocity.y > 0:
						$AnimationPlayer.play("walk_down")
						down = true
						up = false
						left = false
						right = false
					else:
						$AnimationPlayer.play("walk_up")
						up = true
						down = false
						left = false
						right = false
			else:
				if down:
					$AnimationPlayer.play("idle_down")
				elif right:
					$AnimationPlayer.play("idle_right")
				elif left:
					$AnimationPlayer.play("idle_left")
				elif up:
					$AnimationPlayer.play("idle_up")

	#var autoAttack = false
	#if GlobalData.AutoRetaliate and enemies != null and enemies.size() > 0 and !inputting_movement:
		#var first_enemy = enemies[0]
		#if first_enemy != null and first_enemy.hit_points != null and first_enemy.hit_points > 0:
			#autoAttack = true


	#if Input.is_action_just_released("attack") or autoAttack:
		#if stamina_points >= 1:
			#if !attacking and !attacking2:
				##destination = global_position
				#stamina_points -= 1
				#$StaminaTimer.start()
				#idling = false
				#if enemies == null or enemies.size() == 0:
					#attacking = true
					#$Attack1Timer.start()
					#if down:
						#$AnimationPlayer.play("attack_down")
					#if left:
						#$AnimationPlayer.play("attack_left")
					#if right:
						#$AnimationPlayer.play("attack_right")
					#if up:
						#$AnimationPlayer.play("attack_up")
				#else:
					#attack(enemies[0])
		#else:
			#Hud.StaminaFlashRed()
	#
	#if Input.is_action_just_released("attack_2"):
		#if stamina_points >= 2 and !attacking and !attacking2:
			#stamina_points -= 2
			##destination = global_position
			#$StaminaTimer.start()
			#idling = false
			#if enemies == null or enemies.size() == 0:
				#attacking2 = true
				#$Attack2Timer.start()
			#else:
				#for en in enemies:
					#attack_2(en)
			#if down:
				#$AnimationPlayer.play("attack_down_2")
			#if left:
				#$AnimationPlayer.play("attack_left_2")
			#if right:
				#$AnimationPlayer.play("attack_right_2")
			#if up:
				#$AnimationPlayer.play("attack_up_2")
		#else:
			#Hud.StaminaFlashRed()
#
	#if !stamina_ticking and idling and stamina_points < max_stamina_points:
		#stamina_ticking = true
		#$StaminaTickTimer.start()

func attack() -> void:
	attacking = true
	anim.play("attack_" + last_direction)
	
	# You can call this from the animation end instead if you prefer
	await get_tree().create_timer(attack_duration).timeout
	attacking = false







func player_movement(_delta):
	#if moving_to_click:
		#var direction = (destination - global_position).normalized()
		#velocity = direction * move_speed
#
		## Stop moving if close enough
		#if global_position.distance_to(destination) < 4:
			#velocity = Vector2.ZERO
			#moving_to_click = false
	#else:
	input = get_input()
	velocity = input * move_speed
	move_and_slide()

func get_input():
	input.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	input.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	inputting_movement = input != Vector2.ZERO
	return input.normalized()



func hurt(value):
	if !attacking and !attacking2 and !hurting and !dying and !dead:
		hurting = true
		$HurtTimer.start()
		if down:
			$AnimationPlayer.play("hurt_down")
		if left:
			$AnimationPlayer.play("hurt_left")
		if right:
			$AnimationPlayer.play("hurt_right")
		if up:
			$AnimationPlayer.play("hurt_up")
	GlobalData.hit_points -= value


func die():
	if !dying and !dead:
		$AnimationPlayer.stop()
		dying = true
		$DeathTimer.start()
		if down:
			$AnimationPlayer.play("death_down")
		if left:
			$AnimationPlayer.play("death_left")
		if right:
			$AnimationPlayer.play("death_right")
		if up:
			$AnimationPlayer.play("death_up")


func _on_hurt_timer_timeout():
	$HurtTimer.stop()
	hurting = false


func _on_death_timer_timeout():
	dead = true
	$DeathTimer.stop()
	GlobalData.hit_points = GlobalData.max_health
	queue_free()
	get_tree().change_scene_to_file("res://scenes/test.tscn")
