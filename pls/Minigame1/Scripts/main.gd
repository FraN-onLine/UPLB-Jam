extends Node2D

var bricks_scene = preload("res://Minigame1/Scenes/bricks.tscn")
var coin_scene = preload("res://Minigame1/Scenes/coin.tscn")
var spikes_scene = preload("res://Minigame1/Scenes/spikes.tscn")
var heart_scene = preload("res://Minigame1/Scenes/heart.tscn")
var gem_scene = preload("res://Minigame1/Scenes/gem.tscn")
var warning_scene = preload("res://Minigame1/Scenes/warning.tscn")
var sweep_debris_scene = preload("res://Minigame1/Scenes/sweep_debris.tscn")

# Our rhythm variables
var bpm = 96.0
var sec_per_beat = 60.0 / bpm
var last_beat = 0

@onready var audio_player = $AudioStreamPlayer

func _process(_delta):
	
	if audio_player.playing:
		var time = audio_player.get_playback_position()
		
		var current_beat = int(time / sec_per_beat)
		
		if current_beat < last_beat:
			last_beat = -1
		
		if current_beat > last_beat:
			last_beat = current_beat
			spawn_items()

func spawn_items():
	var new_item
	
	if last_beat % 8 == 0:
		spawn_sweep()
		return
	
	# Roll a number between 0.00 and 1.00 (chance of items to fall) imagine mo nalang na pie yung percent nag stastack
	var roll = randf()
	
	if roll < 0.30:
		# 30% chance for bricks 
		new_item = bricks_scene.instantiate()
	elif roll < 0.60:
		# 30% chance for spikes nag add silas ha
		new_item = spikes_scene.instantiate()
	elif roll <0.65:
		new_item = heart_scene.instantiate()
	elif roll < 0.75:
		new_item = gem_scene.instantiate()
	else:
		# so 0.25 = 25% lang ang coins na mag drodrop
		new_item = coin_scene.instantiate()
		
	new_item.position.x = randf_range(50, 1100)
	new_item.position.y = -50 
	
	add_child(new_item)
	
func spawn_sweep():
	var from_left = randf() > 0.5
	var is_high = randf() > 0.5
	
	# warning sign ALWAYS at ground level
	var warning = warning_scene.instantiate()
	if from_left:
		warning.position = Vector2(50, 480)
	else:
		warning.position = Vector2(1100, 480)
	add_child(warning)
	
	# wait ng isang beat since 8 beats yung sung mag spaspawn ang warning ng 7th beat
	await get_tree().create_timer(sec_per_beat).timeout
	
	# kupal to eh kung saan mag spaspawn yung saw natin 
	var sweep_y = 480  # low jump over it
	if is_high:
		sweep_y = 390  # high duck under it
	
	var debris = sweep_debris_scene.instantiate()
	if from_left:
		debris.position = Vector2(-100, sweep_y)
		debris.direction = 1
	else:
		debris.position = Vector2(1250, sweep_y)
		debris.direction = -1
	add_child(debris)
