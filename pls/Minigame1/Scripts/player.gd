extends Area2D

@export var speed = 400
@export var jump_force = -800
@export var fall_gravity = 2400
@export var acceleration = 2000
@export var catch_zone_width = 120  # Width of the catch zone
@export var catch_zone_height = 80  # Height of the catch zone

var velocity_x = 0.0
var velocity_y = 0.0
var floor_y = 0.0
var is_hurt = false
var health = 3
var was_on_floor = true
var money = 0
var is_ducking = false

@onready var anim = $AnimatedSprite2D
@onready var catch_zone = $CatchZone

func _ready():
	floor_y = position.y
	# Player doesn't need to monitor - items detect the player instead
	monitoring = false
	monitorable = true
	collision_layer = 1
	collision_mask = 1
	# Add player to "player" group for items to detect
	add_to_group("player")
	# Create catch zone visual
	create_catch_zone()
	print("Player ready - position: ", position)

func _process(delta):
	var direction = 0
	
	# Check if game is paused
	if get_tree().paused:
		return
	
	if not is_hurt:
		if Input.is_action_pressed("ui_left"):
			direction = -1
			anim.flip_h = true  
		elif Input.is_action_pressed("ui_right"):
			direction = 1
			anim.flip_h = false 
		
		# Debug movement
		if direction != 0:
			print("Moving: ", direction, " position: ", position.x)
		if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) and position.y >= floor_y:
			velocity_y = jump_force 
			play_sound($JumpSound)
			squash_stretch(Vector2(0.7, 1.3))
		if Input.is_action_pressed("ui_down") and position.y >= floor_y:
			is_ducking = true
			$StandingHitbox.disabled = true
			$DuckingHitbox.disabled = false
		else:
			is_ducking = false
			$StandingHitbox.disabled = false
			$DuckingHitbox.disabled = true
			
		# ismooth movement weight yoinked from a yt channel
		var target_speed = direction * speed
		velocity_x = move_toward(velocity_x, target_speed, acceleration * delta)
		position.x += velocity_x * delta
		position.x = clamp(position.x, 0, 1152) 
	
	# Gravity (always runs even when hurt)
	velocity_y += fall_gravity * delta     
	position.y += velocity_y * delta
	
	# Landing detection
	if position.y >= floor_y:
		position.y = floor_y
		# squish on landing same with line 45
		if not was_on_floor:
			squash_stretch(Vector2(1.3, 0.7))
		velocity_y = 0
		was_on_floor = true
	else:
		was_on_floor = false
		
	# Update catch zone position to follow player
	update_catch_zone()
	
	# animations
	if is_hurt:
		anim.play("hit")
	elif is_ducking:
		anim.play("duck")
	elif position.y < floor_y:
		anim.play("jump")
	elif direction != 0:
		anim.play("walk")
	else:
		anim.play("idle")

# squash & stretch function
func create_catch_zone():
	# Create a visual indicator for the catch zone
	var zone_shape = RectangleShape2D.new()
	zone_shape.size = Vector2(catch_zone_width, catch_zone_height)
	
	catch_zone.position = Vector2(0, -catch_zone_height / 2)
	
func update_catch_zone():
	# Keep catch zone centered on player
	catch_zone.position.x = 0
	if is_ducking:
		catch_zone.position.y = 10  # Lower when ducking
		catch_zone.scale = Vector2(1.2, 0.6)  # Wider but shorter
	else:
		catch_zone.position.y = -catch_zone_height / 2
		catch_zone.scale = Vector2(1.0, 1.0)

func squash_stretch(target_scale: Vector2):
	anim.scale = target_scale
	var t = create_tween()
	t.tween_property(anim, "scale", Vector2(2.1,1.9), 0.9).set_trans(Tween.TRANS_ELASTIC)

# randomize pitch sfx sounds para di boring
func play_sound(sound_player):
	sound_player.pitch_scale = randf_range(0.9, 1.1)
	sound_player.play()

func play_coin_sound():
	play_sound($CoinSound)
	
func play_gem_sound():
	play_sound($GemSound)

func take_damage():
	health -= 1
	$HurtSound.play()
	var hud = get_parent().get_node("HUD")
	hud.update_hearts(health)
	print("Ouch! Health is now: ", health)
	screen_shake(10.0, 0.3)
	
	if health <= 0:
		hud = get_parent().get_node("HUD")
		hud.update_hearts(health)
		hud.show_game_over()
		return

	is_hurt = true
	$StandingHitbox.set_deferred("disabled", true)
	
	for i in 5:
		anim.visible = false
		await get_tree().create_timer(0.1).timeout
		anim.visible = true
		await get_tree().create_timer(0.1).timeout
		
	$StandingHitbox.set_deferred("disabled", false)
	is_hurt = false

func heal_damage():
	if health < 3:
		health += 1
		$HealSound.play()
		var hud = get_parent().get_node("HUD")
		hud.update_hearts(health)
		print("Healed! Health is now: ", health)

func screen_shake(intensity: float, duration: float):
	var cam = get_viewport().get_camera_2d()
	if cam:
		var t = create_tween()
		for i in 6:
			t.tween_property(cam, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration / 6.0)
		t.tween_property(cam, "offset", Vector2.ZERO, 0.05)

func collect_money(amount):
	money += amount
	play_coin_sound()
	var hud = get_parent().get_node("HUD")
	hud.update_score(money)
	
	# Visual feedback - flash the catch zone

	
	if money >= 67000:
		hud.show_win()
