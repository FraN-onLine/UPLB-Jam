extends Node

# Emitted when the beatmap song finishes successfully. MainMenu listens for
# this signal and resumes the story at the post-cleanup narrative.
signal minigame_won

# Everything else
@export var bpm: float = 128
@export var spawn_offset_beats: float = 5
@export var song_path: String
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var note_scene = preload("res://Minigame2/scenes/mg2_note.tscn")
@onready var health_bar: ProgressBar = $CanvasLayer/HUD/Corner/HealthBar
@onready var black_overlay: ColorRect = $CanvasLayer/BlackOverlay

# Hitsounds only
@export var hitsound_left_stream: AudioStream = preload("res://Minigame2/audio/mg2_hit_left.mp3")
@export var hitsound_right_stream: AudioStream = preload("res://Minigame2/audio/mg2_hit_right.mp3")
@export var pool_size: int = 6
var pool_left: Array[AudioStreamPlayer] = []
var pool_right: Array[AudioStreamPlayer] = []
var index_left: int = 0
var index_right: int = 0

# Cannot change
var song_position_seconds: float = 0.0
var song_beat: float = 0.0
var last_spawned_index: int = 0
var map_data: Dictionary
var is_playing: bool = false
var is_restarting: bool = false
var offset: float
var total_notes_in_map: int = 0
var song_time_when_paused: float = 0.0
var has_finished: bool = false


# Proper funcs
func _ready() -> void:
	# Build left_hit pool
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.stream = hitsound_left_stream
		add_child(player)
		pool_left.append(player)
		
	# Build right_hit pool
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.stream = hitsound_right_stream
		add_child(player)
		pool_right.append(player)

	load_map("res://Minigame2/assets/mg2_beatmap.json")
	health_bar.value = 100
	audio_player.finished.connect(_on_song_finished)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	play_song()


func restart_game() -> void:
	if is_restarting:
		return
	# Reset
	is_restarting = true
	is_playing = false
	audio_player.stop()
	
	var black = create_tween()
	black.tween_property(black_overlay, "self_modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR)
	await black.finished
	
	# Value genocide
	song_position_seconds = 0.0
	song_beat = 0.0
	last_spawned_index = 0
	song_time_when_paused = 0.0
	has_finished = false
	health_bar.value = 100
	
	# Note genocide
	var active_notes = get_tree().get_nodes_in_group("notes")
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
			
	# Tracking genocide
	var hit_zone = $HitZone
	if hit_zone:
		hit_zone.notes_in_zone.clear()
		hit_zone.current_combo = 0
		hit_zone.current_score = 0
		hit_zone.update_ui("", Color.WHITE)
	
	# Restart
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	play_song()
	var reveal_tween = create_tween()
	reveal_tween.tween_property(black_overlay, "self_modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_LINEAR)
	is_restarting = false
	print("Game Restarted")


func load_map(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		map_data = json.get_data()
		audio_player.stream = load(map_data["song_path"])
		bpm = map_data["bpm"]
		offset = map_data["offset"]
		
		if map_data.has("notes"):
			total_notes_in_map = map_data["notes"].size()
	else:
		print("JSON Error: ", json.get_error_message())
		

func play_song() -> void:
	has_finished = false
	audio_player.play()
	is_playing = true
	
func _on_song_finished() -> void:
	if is_restarting or has_finished:
		return
	is_playing = false
	has_finished = true
	minigame_won.emit()


func _process(delta: float) -> void:
	if not is_playing:
		return
	# 1. Get exact audio position in seconds
	song_position_seconds = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - offset

	# 2. Convert seconds to current song beat
	song_beat = song_position_seconds * (bpm / 60.0)

	# 3. Check for notes to spawn
	if map_data.has("notes"):
		while last_spawned_index < map_data["notes"].size():
			var next_note = map_data["notes"][last_spawned_index]
			
			# Spawn early based on beat offset
			if song_beat >= (next_note["beat"] - spawn_offset_beats):
				spawn_note(next_note["type"], next_note["beat"])
				last_spawned_index += 1
			else:
				break

func spawn_note(note_type: String, target_beat: float) -> void:
	var new_note = note_scene.instantiate()
	new_note.note_type = note_type
	new_note.target_beat = target_beat
	add_child(new_note)

func play_hitsound(input_type: String) -> void:
	if input_type == "hit_left":
		var player = pool_left[index_left]
		player.play()
		index_left = (index_left + 1) % pool_size
	elif input_type == "hit_right":
		var player = pool_right[index_right]
		player.play()
		index_right = (index_right + 1) % pool_size
