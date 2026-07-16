extends Node2D

@export var note_scene: PackedScene
@onready var hit_zone: Area2D = $"../HitZone"
@onready var notes_container: Node2D = $"../NotesContainer"

func spawn_note() -> void:
	var note_instance = note_scene.instantiate()
	
	# 1. Spawn the note exactly where this spawner node is placed
	note_instance.global_position = global_position
	
	# 2. Calculate the direction pointing straight up to the center
	var direction_to_center = (hit_zone.global_position - global_position).normalized()
	
	# 3. Inject the direction into the note
	note_instance.direction = direction_to_center
	
	# 4. Add the note to the scene
	notes_container.add_child(note_instance)
