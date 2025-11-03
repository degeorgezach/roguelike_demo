extends StaticBody2D

var can_open = false
var can_close = false

var is_closed = true
var is_open = false



func _process(delta):
	if can_open and Input.is_action_just_pressed("attack") and GlobalData.Player.threatened == false:
		open()
	elif can_close and Input.is_action_just_pressed("attack") and GlobalData.Player.threatened == false:
		close()


func open():
	$AnimationPlayer.play("open")
	$CollisionShape2D.disabled = true
	is_open = true
	is_closed = false
	can_close = true
	can_open = false
	
func close():
	$AnimationPlayer.play("close")
	$CollisionShape2D.disabled = false
	is_open = false
	is_closed = true
	can_close = false
	can_open = true


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		if is_closed:
			can_open = true
			can_close = false
		elif is_open:
			can_open = false
			can_close = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		if is_closed:
			can_open = false
			can_close = false
		elif is_open:
			can_open = false
			can_close = false
