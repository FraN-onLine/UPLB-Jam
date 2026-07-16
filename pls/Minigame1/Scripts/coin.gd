extends Area2D

@export var fall_speed = 300
@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("default")
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
			print("✓ Coin collected!")
			current.play_coin_sound()
			current.collect_money(2000)
			queue_free()
			return
		current = current.get_parent()
