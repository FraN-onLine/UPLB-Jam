extends Area2D

@export var sweep_speed = 1400
var direction = 1

@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("spin")

func _process(delta):
	position.x += sweep_speed * direction * delta
	
	if position.x > 1300 or position.x < -150:
		queue_free()

func _on_area_entered(area: Area2D):
	if area.name == "Player":
		area.take_damage()
		queue_free()
