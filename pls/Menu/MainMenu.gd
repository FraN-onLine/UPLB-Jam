## Main Menu — entry point for the game
##
## Attach this script to MainMenu.tscn (CanvasLayer).
## The Start button begins the story, Test opens the example dialogue.

extends CanvasLayer

@onready var dialogue_window = preload("res://Dialogue Windows/dialgoue.tscn").instantiate()


func _ready() -> void:
	add_child(dialogue_window)
	dialogue_window.hide()
	dialogue_window.dialogue_finished.connect(_on_dialogue_finished)

	$StartButton.pressed.connect(_on_start_pressed)
	$TestButton.pressed.connect(_on_test_pressed)


func _on_start_pressed() -> void:
	# Hide the menu buttons while dialogue plays
	$StartButton.hide()
	$TestButton.hide()
	$Title.hide()
	$Subtitle.hide()

	# Begin the story
	dialogue_window.start("res://Dialogue Windows/base.dialogue", "day1")


func _on_test_pressed() -> void:
	$StartButton.hide()
	$TestButton.hide()
	$Title.hide()
	$Subtitle.hide()

	dialogue_window.start("res://Dialogue Windows/example.dialogue", "test")


func _on_dialogue_finished(return_key: String) -> void:
	match return_key:
		"home_arrival":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "home")

		"walk_streets":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "walk_streets")

		"return_home":
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "return_home")

		"day1_end":
			print("Day 1 complete! 🎉")

		"test_complete":
			print("Test complete")

		_:
			# If the return_key doesn't match anything known,
			# show the menu again
			$StartButton.show()
			$TestButton.show()
			$Title.show()
			$Subtitle.show()