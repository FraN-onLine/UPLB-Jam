extends Area2D

var health = 3
@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("idle")

func _process(delta):
	if not anim.is_playing():
		anim.play("idle")

func play_sound(sound_player):
	sound_player.pitch_scale = randf_range(0.9, 1.1)
	sound_player.play()

func play_hit_reaction():
	play_sound($CoinSound)
	anim.scale = Vector2(1.2, 0.8)
	var t = create_tween()
	t.tween_property(anim, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)

func play_miss_reaction():
	# 1. Shake the screen
	screen_shake(8.0, 0.2) 
	
	# 2. Play the miss sound! 
	if has_node("HurtSound"):
		$HurtSound.play()
		
	# 3. Squish flat and flash RED!
	anim.scale = Vector2(1.3, 0.6) # Squish wide and short
	anim.modulate = Color.RED # Tint red
	
	# 4. Smoothly bounce back to normal shape and color
	var t = create_tween()
	t.parallel().tween_property(anim, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE)
	t.parallel().tween_property(anim, "modulate", Color.WHITE, 0.3)
	
	
func screen_shake(intensity: float, duration: float):
	var cam = get_viewport().get_camera_2d()
	if cam:
		var t = create_tween()
		for i in 6:
			t.tween_property(cam, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration / 6.0)
		t.tween_property(cam, "offset", Vector2.ZERO, 0.05)
