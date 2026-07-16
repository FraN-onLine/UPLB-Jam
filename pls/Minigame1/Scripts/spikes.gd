extends Area2D

@export var fall_speed = 300

func _ready():
	# Enable collision detection
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = false
	# Connect collision signal
	area_entered.connect(_on_area_entered)

func _process(delta):
	position.y += fall_speed * delta

func _on_area_entered(area: Area2D):
	# Traverse up from whatever we hit to find Player
	var current = area
	while current:
		if current.name == "Player":
			print("✓ Player hit by spike!")
			current.take_damage()
			queue_free()
			return
		current = current.get_parent()
