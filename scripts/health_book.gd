extends Node


func _ready():
	$AnimationPlayer.play("idle")


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player and GlobalData.hit_points < GlobalData.max_health:
		$AnimationPlayer.play("open")
		$Timer.start()


func _on_timer_timeout() -> void:
	if GlobalData.hit_points < GlobalData.max_health:
		GlobalData.hit_points += 1
	queue_free()
