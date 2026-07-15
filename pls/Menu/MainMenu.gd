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
	dialogue_window.start("res://Dialogue Windows/base.txt", "day1")


func _on_test_pressed() -> void:
	_hide_menu()
	dialogue_window.start("res://Dialogue Windows/example.txt", "test")


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
	dialogue_window.hide()
	_in_minigame = true
	
	minigame1_instance = minigame1_scene.instantiate()
	add_child(minigame1_instance)
	
	await get_tree().process_frame
	
	var hud = minigame1_instance.find_child("HUD", true, false)
	if hud:
		hud.game_was_won.connect(_on_minigame1_won)
		hud.game_was_lost.connect(_on_minigame1_lost)
	else:
		if minigame1_instance.has_signal("minigame_won"):
			minigame1_instance.minigame_won.connect(_on_minigame1_won)
		if minigame1_instance.has_signal("minigame_lost"):
			minigame1_instance.minigame_lost.connect(_on_minigame1_lost)


func _on_minigame1_won() -> void:
	_minigame_cleanup()
	dialogue_window.start("res://Dialogue Windows/base.txt", "after_fundraiser")


func _on_minigame1_lost() -> void:
	_minigame_cleanup()
	print("Minigame lost — returning to menu")
	_show_menu()


func _minigame_cleanup() -> void:
	if minigame1_instance:
		minigame1_instance.queue_free()
		minigame1_instance = null
	_in_minigame = false
	get_tree().paused = false


func _on_dialogue_finished(return_key: String) -> void:
	match return_key:
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