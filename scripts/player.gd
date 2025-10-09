extends CharacterBody2D

@export var speed: float = 60.0
@onready var anim: AnimationPlayer = $AnimationPlayer

@export var attack_duration: float = 0.4
var attacking: bool = false

# Track which direction we last moved in
var last_direction: String = "down"

func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO

	# Get movement input
	input_vector.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_vector.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	
	input_vector = input_vector.normalized()

	# Move the character


	# Determine direction (for choosing the right animation)
	var current_direction = last_direction

	if !attacking:
		velocity = input_vector * speed
		move_and_slide()
	
		if input_vector != Vector2.ZERO:
			if abs(input_vector.x) > abs(input_vector.y):
				current_direction = "right" if input_vector.x > 0 else "left"
			else:
				current_direction = "down" if input_vector.y > 0 else "up"

			last_direction = current_direction  # remember the last direction moved
			anim.play("walk_" + current_direction)
		else:
			anim.play("idle_" + last_direction)
		
		
			# Handle attack input
	if Input.is_action_just_pressed("attack"):
		attack()

func attack() -> void:
	attacking = true
	anim.play("attack_" + last_direction)
	
	# You can call this from the animation end instead if you prefer
	await get_tree().create_timer(attack_duration).timeout
	attacking = false
