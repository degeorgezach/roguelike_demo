extends StaticBody2D
class_name Breakable

var can_break = false
var is_broken = false

@export var drop_chance: float = 0.5
@export var loot_spawn_delay: float = 0.5


func break_object():
	$AnimationPlayer.play("break")
	$CollisionShape2D.disabled = true
	can_break = false
	is_broken = true
	spawn_loot()


func _process(delta):
	if can_break and !is_broken and Input.is_action_just_pressed("attack") and GlobalData.Player.threatened == false:
		if is_player_facing_object():
			break_object()


func is_player_facing_object() -> bool:
	var player = GlobalData.Player
	if player == null:
		return false

	var to_object = (global_position - player.global_position).normalized()
	var facing = player.direction.normalized()
	var alignment = facing.dot(to_object)
	return alignment > 0.7


func spawn_loot() -> void:
	# Start a short delay before spawning the loot
	await get_tree().create_timer(loot_spawn_delay).timeout

	# Find all loot items in this crate’s scene that belong to the "loot_items" group
	var loot_items = get_tree().get_nodes_in_group("loot_items")
	if loot_items.is_empty():
		return

	# Only pick loot nodes that are children of THIS breakable object
	var local_loot: Array = []
	for node in loot_items:
		if node.is_inside_tree() and is_ancestor_of(node):
			local_loot.append(node)

	if local_loot.is_empty():
		return

	# Pick one random loot item from the crate’s local loot group
	var item = local_loot[randi() % local_loot.size()]

	if randf() <= drop_chance:
		item.visible = true
		item.global_position = global_position
		item.reparent(get_tree().current_scene)  # move out of the crate so it can persist
	else:
		item.queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player and !is_broken:
		can_break = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player and !is_broken:
		can_break = false
