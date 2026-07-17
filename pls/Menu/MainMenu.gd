## Main Menu — entry point for the game
##
## Handles the full story flow including minigame transitions and audio.

extends CanvasLayer

@onready var dialogue_window = preload("res://Dialogue-Windows/dialgoue.tscn").instantiate()
var fade_overlay: ColorRect
var minigame1_scene = preload("res://Minigame1/Scenes/main.tscn")
var minigame2_scene = preload("res://Minigame2/scenes/minigame2.tscn")
var minigame3_scene = preload("res://Minigame3/Scenes/main.tscn")
var minigame4_scene = preload("res://Minigame4/scenes/minigame4.tscn")
var minigame5_scene = preload("res://Minigame5/main.tscn")
var minigame_instance = null
var _in_minigame := false
var _transitioning := false

# Audio
var main_theme: AudioStreamPlayer
var end_theme: AudioStreamPlayer
var _using_end_theme := false


func _ready() -> void:
	get_tree().root.add_child.call_deferred(dialogue_window)
	dialogue_window.hide()
	dialogue_window.dialogue_finished.connect(_on_dialogue_finished)

	$StartButton.pressed.connect(_on_start_pressed)
	$TestButton.pressed.connect(_on_test_pressed)
	
	# Create fade overlay in root viewport so it covers everything including minigame
	fade_overlay = ColorRect.new()
	fade_overlay.z_index = 4096
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 0)  # Start fully transparent
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child.call_deferred(fade_overlay)
	
	# Setup audio players
	main_theme = AudioStreamPlayer.new()
	main_theme.stream = preload("res://Audio/MainTheme.mp3")
	main_theme.volume_db = -5.0
	main_theme.bus = &"Master"
	main_theme.finished.connect(main_theme.play)  # Loop
	add_child(main_theme)
	
	end_theme = AudioStreamPlayer.new()
	end_theme.stream = preload("res://Audio/EndTheme.mp3")
	end_theme.volume_db = -5.0
	end_theme.bus = &"Master"
	end_theme.finished.connect(end_theme.play)  # Loop
	add_child(end_theme)
	
	# Start main theme on menu
	main_theme.play()


func _on_start_pressed() -> void:
	_hide_menu()
	# Reset to main theme for a fresh game
	end_theme.stop()
	_using_end_theme = false
	if not main_theme.playing:
		main_theme.play()
	dialogue_window.start("res://Dialogue-Windows/base.txt", "day1")


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

func _switch_to_end_theme() -> void:
	if _using_end_theme:
		return
	_using_end_theme = true
	main_theme.stop()
	end_theme.play()


func _launch_minigame1() -> void:
	if _transitioning:
		return
	
	# Fade to black
	await _fade_in(1.0)
	
	# Stop main theme during minigame (minigame has own audio)
	main_theme.stop()
	
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

	minigame_instance = minigame1_scene.instantiate()
	minigame_instance.visible = true
	get_tree().root.add_child(minigame_instance)
	
	await get_tree().process_frame
	
	# Make the minigame's camera the active camera
	var camera = minigame_instance.find_child("Camera2D", true, false)
	if camera:
		camera.make_current()
	
	# Connect signals via HUD (minigame1-specific: HUD has game_was_won/game_was_lost)
	var hud = minigame_instance.find_child("HUD", true, false)
	if hud:
		hud.game_was_won.connect(_on_minigame1_won)
		hud.game_was_lost.connect(_on_minigame1_lost)
	
	# Fade from black
	await _fade_out(1.0)


func _on_minigame1_won() -> void:
	# When won, continue story - no retry option
	await _fade_in(1.0)
	_minigame_cleanup()
	# Resume main theme for dialogue
	main_theme.play()
	# Show the dialogue window and main menu
	dialogue_window.show()
	show()
	await _fade_out(1.0)
	# Start the next story section
	dialogue_window.start("res://Dialogue-Windows/base.txt", "after_fundraiser")


func _on_minigame1_lost() -> void:
	# When lost, allow retry
	await _fade_in(1.0)
	_minigame_cleanup()
	# Resume main theme for menu
	main_theme.play()
	await _fade_out(1.0)
	print("Minigame lost — returning to menu")
	_show_menu()


func _launch_minigame2() -> void:
	if _transitioning:
		return

	await _fade_in(1.0)

	# Minigame 2 supplies its own rhythm track.
	main_theme.stop()
	dialogue_window.hide()
	_in_minigame = true

	$Title.hide()
	$Subtitle.hide()
	$StartButton.hide()
	$OtherButton.hide()
	$TestButton.hide()
	$TextureRect.hide()

	minigame_instance = minigame2_scene.instantiate()
	# Connect before adding the scene so even a very short/custom song cannot
	# finish before MainMenu starts listening.
	minigame_instance.minigame_won.connect(_on_minigame2_won)
	get_tree().root.add_child(minigame_instance)

	await get_tree().process_frame

	var camera = minigame_instance.find_child("Camera2D", true, false)
	if camera:
		camera.make_current()

	await _fade_out(1.0)


func _on_minigame2_won() -> void:
	if not _in_minigame:
		return
	await _fade_in(1.0)
	_minigame_cleanup()
	main_theme.play()
	dialogue_window.show()
	show()
	await _fade_out(1.0)
	dialogue_window.start("res://Dialogue-Windows/base.txt", "minigame2_narrative")


func _launch_minigame3() -> void:
	if _transitioning:
		return
	
	await _fade_in(1.0)
	
	# Stop main theme, switch to end theme for post-MG3 dialogue
	main_theme.stop()
	_switch_to_end_theme()
	
	dialogue_window.hide()
	_in_minigame = true
	
	$Title.hide()
	$Subtitle.hide()
	$StartButton.hide()
	$OtherButton.hide()
	$TestButton.hide()
	$TextureRect.hide()

	minigame_instance = minigame3_scene.instantiate()
	minigame_instance.visible = true
	get_tree().root.add_child(minigame_instance)
	
	await get_tree().process_frame
	
	# Make the minigame's camera the active camera
	var camera = minigame_instance.find_child("Camera2D", true, false)
	if camera:
		camera.make_current()
	
	# Connect HUD signals
	var hud = minigame_instance.find_child("HUD", true, false)
	if hud:
		hud.game_was_won.connect(_on_minigame3_won)
		hud.game_was_lost.connect(_on_minigame3_lost)
	
	await _fade_out(1.0)


func _on_minigame3_won() -> void:
	await _fade_in(1.0)
	_minigame_cleanup()
	# Resume end theme for dialogue
	end_theme.play()
	dialogue_window.show()
	show()
	await _fade_out(1.0)
	# Show the narrative bridge before minigame4
	dialogue_window.start("res://Dialogue-Windows/base.txt", "minigame3_narrative")


func _on_minigame3_lost() -> void:
	await _fade_in(1.0)
	_minigame_cleanup()
	# Resume end theme for menu
	end_theme.play()
	await _fade_out(1.0)
	print("Minigame 3 lost — returning to menu")
	_show_menu()


func _launch_minigame4() -> void:
	if _transitioning:
		return
	
	await _fade_in(1.0)
	
	# Stop end theme during minigame4 (silent puzzle)
	end_theme.stop()
	
	dialogue_window.hide()
	_in_minigame = true
	
	$Title.hide()
	$Subtitle.hide()
	$StartButton.hide()
	$OtherButton.hide()
	$TestButton.hide()
	$TextureRect.hide()

	minigame_instance = minigame4_scene.instantiate()
	minigame_instance.visible = true
	get_tree().root.add_child(minigame_instance)
	
	await get_tree().process_frame
	
	# Minigame4 is a Control node (no Camera2D needed)
	# Connect its win signal
	if minigame_instance.has_signal("minigame_won"):
		minigame_instance.minigame_won.connect(_on_minigame4_won)
	
	await _fade_out(1.0)


func _on_minigame4_won() -> void:
	await _fade_in(1.0)
	_minigame_cleanup()
	# Go directly to minigame5
	dialogue_window.start("res://Dialogue-Windows/base.txt", "minigame4_narrative")


func _launch_minigame5() -> void:
	if _transitioning:
		return
	
	await _fade_in(1.0)
	
	# Stop end theme during minigame5
	end_theme.stop()
	
	dialogue_window.hide()
	_in_minigame = true
	
	$Title.hide()
	$Subtitle.hide()
	$StartButton.hide()
	$OtherButton.hide()
	$TestButton.hide()
	$TextureRect.hide()

	minigame_instance = minigame5_scene.instantiate()
	minigame_instance.visible = true
	get_tree().root.add_child(minigame_instance)
	
	await get_tree().process_frame
	
	# Make the minigame's camera the active camera
	var camera = minigame_instance.find_child("Camera2D", true, false)
	if camera:
		camera.make_current()
	
	# Connect its finished signal
	if minigame_instance.has_signal("minigame_finished"):
		minigame_instance.minigame_finished.connect(_on_minigame5_finished)
	
	await _fade_out(1.0)


func _on_minigame5_finished() -> void:
	await _fade_in(1.0)
	_minigame_cleanup()
	# Return to main menu
	_show_menu()


func _minigame_cleanup() -> void:
	if minigame_instance:
		minigame_instance.queue_free()
		minigame_instance = null
	_in_minigame = false
	get_tree().paused = false


func _on_dialogue_finished(return_key: String) -> void:
	match return_key:
		"":
			_show_menu()
		"sisa_response":
			dialogue_window.start("res://Dialogue-Windows/base.txt", "sisa_response")

		"home_arrival":
			dialogue_window.start("res://Dialogue-Windows/base.txt", "home")
		
		"walk_streets":
			dialogue_window.start("res://Dialogue-Windows/base.txt", "walk_streets")
		
		"return_home":
			dialogue_window.start("res://Dialogue-Windows/base.txt", "return_home")
		
		"start_fundraiser":
			_launch_minigame1()
		
		"djo_choice":
			dialogue_window.start("res://Dialogue-Windows/base.txt", "djo_choice")
		
		"djo_decision":
			if dialogue_window.last_chosen_option_index == 0:
				dialogue_window.start("res://Dialogue-Windows/base.txt", "gave_up")
			else:
				dialogue_window.start("res://Dialogue-Windows/base.txt", "stayed_to_fight")
		
		"gave_up":
			dialogue_window.start("res://Dialogue-Windows/base.txt", "gave_up")
		
		"stayed_to_fight":
			dialogue_window.start("res://Dialogue-Windows/base.txt", "stayed_to_fight")
		
		"bad_ending":
			print("Bad ending reached. Donto fell.")
			_show_menu()
		
		"start_minigame2":
			_launch_minigame2()
		
		"start_minigame3":
			_launch_minigame3()
		
		"start_minigame4":
			_launch_minigame4()
		
		"start_minigame5":
			_launch_minigame5()
		
		"test_complete":
			print("Test complete")
			_show_menu()
		
		_:
			_show_menu()
