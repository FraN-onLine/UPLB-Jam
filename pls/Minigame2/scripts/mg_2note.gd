extends Area2D

@export var note_type: String = "hit_left"
@export var target_beat: float = 0.0

const SPRITE_LEFT = preload("res://Minigame2/assets/mg2_hit_left.png")
const SPRITE_RIGHT = preload("res://Minigame2/assets/mg2_hit_right.png")

@onready var conductor = $".."
@onready var sprite: Sprite2D = $Sprite2D

var receptor_x: float = 340.0  # Hit zone center
var spawn_x: float =  1900.0  # Spawning point on the right
var static_y: float = 530.0     # Center line


func _ready() -> void:
	position.y = static_y
	
	if note_type == "hit_left":
		sprite.texture = SPRITE_LEFT
	elif note_type == "hit_right":
		sprite.texture = SPRITE_RIGHT


func _process(_delta: float) -> void:
	var beats_remaining = target_beat - conductor.song_beat
	
	# Calculate visual progress based on beat lifetime
	var total_travel_beats = conductor.spawn_offset_beats
	var progress = 1.0 - (beats_remaining / total_travel_beats)
	
	# Lerp position horizontally along the X-axis
	position.x = lerp(spawn_x, receptor_x, progress)
		
