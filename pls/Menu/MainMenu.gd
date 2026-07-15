## Main Menu — entry point for the game
##
## Handles the full story flow including minigame transitions.

extends CanvasLayer

@onready var dialogue_window = preload("res://Dialogue Windows/dialgoue.tscn").instantiate()

var minigame1_scene = preload("res://Minigame1/Scenes/main.tscn")
var minigame1_instance = null
var _in_minigame := false


func _ready() -> void:
	add_child(dialogue_window)
	dialogue_window.hide()
	dialogue_window.dialogue_finished.connect(_on_dialogue_finished)

	$StartButton.pressed.connect(_on_start_pressed)
	$TestButton.pressed.connect(_on_test_pressed)


func _on_start_pressed() -> void:
	_hide_menu()
	dialogue_window.start("res://Dialogue Windows/base.dialogue", "day1")


func _on_test_pressed() -> void:
	_hide_menu()
	dialogue_window.start("res://Dialogue Windows/example.dialogue", "test")


func _hide_menu() -> void:
	$StartButton.hide()
	$TestButton.hide()
	$Title.hide()
	$Subtitle.hide()


func _show_menu() -> void:
	$StartButton.show()
	$TestButton.show()
	$Title.show()
	$Subtitle.show()


func _launch_minigame1() -> void:
	# Hide dialogue, launch the fundraiser minigame
	dialogue_window.hide()
	_in_minigame = true
	
	minigame1_instance = minigame1_scene.instantiate()
	add_child(minigame1_instance)
	
	# Connect to minigame signals
	# The HUD has game_was_won / game_was_lost signals
	# Wait a frame for HUD to initialize, then connect
	await get_tree().process_frame
	
	# Find HUD in the minigame
	var hud = minigame1_instance.find_child("HUD", true, false)
	if hud:
		hud.game_was_won.connect(_on_minigame1_won)
		hud.game_was_lost.connect(_on_minigame1_lost)
	else:
		# Fallback: connect to main script signals
		if minigame1_instance.has_signal("minigame_won"):
			minigame1_instance.minigame_won.connect(_on_minigame1_won)
		if minigame1_instance.has_signal("minigame_lost"):
			minigame1_instance.minigame_lost.connect(_on_minigame1_lost)


func _on_minigame1_won() -> void:
	_minigame_cleanup()
	dialogue_window.start("res://Dialogue Windows/base.dialogue", "after_fundraiser")


func _on_minigame1_lost() -> void:
	_minigame_cleanup()
	# Player lost the fundraiser — show a shorter path back to menu
	print("Minigame lost — returning to menu")
	_show_menu()


func _minigame_cleanup() -> void:
	if minigame1_instance:
		minigame1_instance.queue_free()
		minigame1_instance = null
	_in_minigame = false
	# Unpause if the minigame paused the tree
	get_tree().paused = false


func _on_dialogue_finished(return_key: String) -> void:
	match return_key:
		# Day 1 scene chain
		"home_arrival":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "home")
		
		"walk_streets":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "walk_streets")
		
		"return_home":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "return_home")
		
		"start_fundraiser":
			# Transition to Minigame 1!
			_launch_minigame1()
		
		# After minigame 1 — Djo confrontation
		"choice_fight":
			# Player chose "But this is our home" or "True but..."
			# Show the Give Up / Fight choice
			# Flow handled by the dialogue choices inside after_fundraiser
			pass
		
		"gave_up":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "gave_up")
		
		"stayed_to_fight":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "stayed_to_fight")
		
		"bad_ending":
			print("Bad ending reached. Donto fell.")
			_show_menu()
		
		# Minigame 2-5 narrative chain (mg2-5 are out, so direct flow)
		"start_minigame2":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "minigame2_narrative")
		
		"start_minigame3":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "minigame3_narrative")
		
		"start_minigame4":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "minigame4_narrative")
		
		"celebration":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "celebration")
		
		"day1_complete":
			print("Day 1 complete! 🎉")
			_show_menu()
		
		"test_complete":
			print("Test complete")
			_show_menu()
		
		_:
			# Unknown return key — show menu again
			_show_menu()
