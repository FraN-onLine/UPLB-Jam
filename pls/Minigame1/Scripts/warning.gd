extends Sprite2D

# The warning blinks and then destroys itself after a short time
func _ready():
	# Blink 3 times to warn the player
	for i in 3:
		visible = false
		await get_tree().create_timer(0.15).timeout
		visible = true
		await get_tree().create_timer(0.15).timeout
	queue_free()
