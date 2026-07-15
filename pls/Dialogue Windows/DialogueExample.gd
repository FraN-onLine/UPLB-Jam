## Example script — runs the full Day 1 story from base.dialogue
##
## 1. Attach this script to any Node (e.g. your main scene's root).
## 2. The dialogue will start automatically.
## 3. Sections chain together via dialogue_finished signal.
##
## To make your own story:
##   - Edit the sections in base.dialogue (or create a new .dialogue file)
##   - Change the path in dialogue_window.start() calls below
##   - Add more match cases for new return_keys

extends Node

@onready var dialogue_window = preload("res://Dialogue Windows/dialgoue.tscn").instantiate()


func _ready() -> void:
	# Add the dialogue window to the scene tree
	add_child(dialogue_window)

	# Connect signal to know when a section ends
	dialogue_window.dialogue_finished.connect(_on_dialogue_finished)

	# Start the story!
	dialogue_window.start("res://Dialogue Windows/base.dialogue", "day1")


## Called automatically when a section finishes.
## return_key comes from #something inside the dialogue file.
func _on_dialogue_finished(return_key: String) -> void:
	match return_key:
		"home_arrival":
			# Emilio met Sisa & Crispin → now he goes home
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "home")

		"walk_streets":
			# Emilio left home to find Mama → he walks the streets
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "walk_streets")

		"return_home":
			# Emilio returns home → finds Mama and Hiraya
			dialogue_window.start("res://Dialogue Windows/base.dialogue", "return_home")

		"day1_end":
			# Day 1 finished!
			print("Day 1 complete! 🎉 Coming next: Day 2...")

		"test_complete":
			print("Test complete")
