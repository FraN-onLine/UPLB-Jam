extends Area2D

@export var fall_speed = 300

func _process(delta):
	position.y += fall_speed * delta
	# Clean up when off-screen
	if position.y > 700:
		queue_free()

func _on_area_entered(area: Area2D):
	if area.name == "Player":
		area.take_damage() 
		queue_free()
