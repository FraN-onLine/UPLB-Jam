extends Area2D

@export var slide_speed = 400
var direction_name = "ui_up"
var was_hit = false

func _process(delta):
	position.x -= slide_speed * delta
	
	# If it flies off the screen, you missed it!
	if position.x < -200:
		if not was_hit:
			var main = get_parent()
			if main.has_method("on_arrow_miss"):
				main.on_arrow_miss()
		queue_free()

func hit():
	was_hit = true
	queue_free()
