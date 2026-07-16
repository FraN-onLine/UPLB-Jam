extends Area2D

@export var walk_speed = 40

@onready var anim = $AnimatedSprite2D

func _process(delta):
	if Input.is_action_pressed("ui_right"):
		position.x += walk_speed * delta
		anim.flip_h = false
		anim.play("walk")
	else:
		anim.play("idle")
