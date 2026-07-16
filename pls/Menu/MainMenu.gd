## Main Menu — entry point for the game
##
## Handles the full story flow including minigame transitions.

extends CanvasLayer

@onready var dialogue_window = preload("res://Dialogue Windows/dialgoue.tscn").instantiate()
var fade_overlay: ColorRect
var minigame1_scene = preload("res://Minigame1/Scenes/main.tscn")
var minigame1_instance = null
var _in_minigame := false
var _transitioning := false


func _ready() -> void:
	add_child(dialogue_window)
	dialogue_window.hide()
	dialogue_window.dialogue_finished.connect(_on_dialogue_finished)

	$StartButton.pressed.connect(_on_start_pressed)
	$TestButton.pressed.connect(_on_test_pressed)
	
	# Create fade overlay in root viewport so it covers everything including minigame
	fade_overlay = ColorRect.new()
	fade_overlay.z_index = 9999
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 0)  # Start fully transparent
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(fade_overlay)


func _on_start_pressed() -> void:
	_hide_menu()
	dialogue_window.start("res://Dialogue Windows/base.txt", "day1")


func _on_test_pressed() -> void:
	_hide_menu()
	dialogue_window.start("res://Dialogue Windows/example.txt", "test")


func _hide_menu() -> void:
	$StartButton.hide()
	$OtherButton.hide()
	$Title.hide()
	$Subtitle.hide()


func _show_menu() -> void:
	$StartButton.show()
	$Title.show()
	$Subtitle.show()
	$OtherButton.show()
	$TextureRect.show()


func _fade_in(duration: float = 1.0) -> void:
	_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, duration)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_transitioning = false

func _fade_out(duration: float = 1.0) -> void:
	_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, duration)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_transitioning = false

func _launch_minigame1() -> void:
	if _transitioning:
		return
	
	# Fade to black
	await _fade_in(1.0)
	
	# Hide dialogue and stop any active input/typing state before minigame.
	dialogue_window.hide()
	_in_minigame = true
	
	# Hide main menu background but keep fade overlay visible
	$Title.hide()
	$Subtitle.hide()
	$StartButton.hide()
	$OtherButton.hide()
	$TestButton.hide()
	$TextureRect.hide()

	# Reset dialogue window state so we never resume mid-typing.
	if dialogue_window.has_method("start"):
		# no-op: keep loaded dialogue, start() will reset state anyway
		pass

	minigame1_instance = minigame1_scene.instantiate()
	minigame1_instance.visible = true
	# Add to root viewport so Camera2D works properly
	get_tree().root.add_child(minigame1_instance)

	
	await get_tree().process_frame
	
	# Make the minigame's camera the active camera
	var camera = minigame1_instance.find_child("Camera2D", true, false)
	if camera:
		camera.make_current()
	
	var hud = minigame1_instance.find_child("HUD", true, false)
	if hud:
		hud.game_was_won.connect(_on_minigame1_won)
		hud.game_was_lost.connect(_on_minigame1_lost)
	else:
		if minigame1_instance.has_signal("minigame_won"):
			minigame1_instance.minigame_won.connect(_on_minigame1_won)
		if minigame1_instance.has_signal("minigame_lost"):
			minigame1_instance.minigame_lost.connect(_on_minigame1_lost)
	
	# Fade from black
	await _fade_out(1.0)


func _on_minigame1_won() -> void:
	# When won, continue story - no retry option
	await _fade_in(1.0)
	_minigame_cleanup()
	# Show the dialogue window and main menu
	dialogue_window.show()
	show()
	await _fade_out(1.0)
	# Start the next story section
	dialogue_window.start("res://Dialogue Windows/base.txt", "after_fundraiser")


func _on_minigame1_lost() -> void:
	# When lost, allow retry
	await _fade_in(1.0)
	_minigame_cleanup()
	await _fade_out(1.0)
	print("Minigame lost — returning to menu")
	_show_menu()


func _minigame_cleanup() -> void:
	if minigame1_instance:
		minigame1_instance.queue_free()
		minigame1_instance = null
	_in_minigame = false
	get_tree().paused = false


func _on_dialogue_finished(return_key: String) -> void:
	# DialogueWindow emits the section header return_key (string after '#').
	# If empty, this is just end-of-dialogue.
	match return_key:
		"":
			_show_menu()
		"home_arrival":


			dialogue_window.start("res://Dialogue Windows/base.txt", "home")
		
		"walk_streets":
			dialogue_window.start("res://Dialogue Windows/base.txt", "walk_streets")
		
		"return_home":
			dialogue_window.start("res://Dialogue Windows/base.txt", "return_home")
		
		"start_fundraiser":
			_launch_minigame1()
		
		"djo_choice":
			dialogue_window.start("res://Dialogue Windows/base.txt", "djo_choice")
		
		"djo_decision":
			# 0 = Give Up, 1 = Fight
			if dialogue_window.last_chosen_option_index == 0:
				dialogue_window.start("res://Dialogue Windows/base.txt", "gave_up")
			else:
				dialogue_window.start("res://Dialogue Windows/base.txt", "stayed_to_fight")
		
		"gave_up":
			dialogue_window.start("res://Dialogue Windows/base.txt", "gave_up")
		
		"stayed_to_fight":
			dialogue_window.start("res://Dialogue Windows/base.txt", "stayed_to_fight")
		
		"bad_ending":
			print("Bad ending reached. Donto fell.")
			_show_menu()
		
		"start_minigame2":
			dialogue_window.start("res://Dialogue Windows/base.txt", "minigame2_narrative")
		
		"start_minigame3":
			dialogue_window.start("res://Dialogue Windows/base.txt", "minigame3_narrative")
		
		"start_minigame4":
			dialogue_window.start("res://Dialogue Windows/base.txt", "minigame4_narrative")
		
		"celebration":
			dialogue_window.start("res://Dialogue Windows/base.txt", "celebration")
		
		"day1_complete":
			print("Day 1 complete! 🎉")
			_show_menu()
		
		"test_complete":
			print("Test complete")
			_show_menu()
		
		_:
			_show_menu()
