extends Area2D

@export var fall_speed = 300
@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("default")

func _process(delta):
	position.y += fall_speed * delta


func _on_area_entered(area: Area2D):
	if area.name == "Player":
		area.play_coin_sound()
		area.collect_money(2000) # value ng coins
		queue_free()
