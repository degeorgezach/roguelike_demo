extends CharacterBody2D
class_name Player

@export var tile_size: int = 16
@export var move_speed: float = 128.0  # pixels/sec
@export var attack_duration: float = 0.4

@onready var anim: AnimationPlayer = $AnimationPlayer

var moving = false
var target_position: Vector2
var direction = Vector2.ZERO

var attacking = false
var idling = true
var enemies = []
var threatened = false
var attack_power = 1

# Direction flags
var up = false
var down = true
var left = false
var right = false

var dead = false

func _ready():
	anim.play("idle_down")
	target_position = global_position

func _physics_process(delta):
	if GlobalData.hit_points <= 0:
		die()
	
	if not moving and not attacking and not dead:
		handle_input()

	if moving:
		move_towards_target(delta)
	else:
		update_idle_animation()

func handle_input():
	# Only act on new key presses (turn-based)
	var input_vector = Vector2(
		int(Input.is_action_just_pressed("right")) - int(Input.is_action_just_pressed("left")),
		int(Input.is_action_just_pressed("down")) - int(Input.is_action_just_pressed("up"))
	)
	
	if input_vector != Vector2.ZERO:
		direction = input_vector
		try_move_tile(direction)
	
	if Input.is_action_just_pressed("attack") and not attacking:
		attack_action()

func try_move_tile(dir: Vector2):
	var next_pos = global_position + dir * tile_size

	# Godot 4 ray collision
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
		# Free to move
		target_position = next_pos
		moving = true
		update_walk_animation()
	else:
		# Blocked by wall
		moving = false

func move_towards_target(delta):
	var distance = target_position - global_position
	if distance.length() < 0.1:
		global_position = target_position
		moving = false
		return

	var step = distance.normalized() * move_speed * delta
	if step.length() > distance.length():
		step = distance
	global_position += step

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
				right = false
				left = true
				up = false
				down = false
				anim.play("attack_left")
		else:
			if diff.y > 0:
				right = false
				left = false
				up = false
				down = true
				anim.play("attack_down")
			else:
				right = false
				left = false
				up = true
				down = false
				anim.play("attack_up")
		body.hurt(attack_power)

func _on_attack_timer_timeout():
	$AttackTimer.stop()
	attacking = false
	idling = true

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
