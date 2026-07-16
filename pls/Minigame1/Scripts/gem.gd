extends Area2D

@export var fall_speed = 300

func _process(delta):
	position.y += fall_speed * delta



func _on_area_entered(area: Area2D):
	if area.name == "Player":
		area.play_gem_sound()
		area.collect_money(5000) # value naman ng gems
		queue_free()
