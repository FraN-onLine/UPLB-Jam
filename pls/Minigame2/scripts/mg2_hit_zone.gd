extends Area2D

@onready var accuracy_label: Label = $"../CanvasLayer/HUD/VBoxContainer/AccuracyLabel"
@onready var combo_label: Label = $"../CanvasLayer/HUD/VBoxContainer/ComboLabel"
@onready var ui_container: VBoxContainer = $"../CanvasLayer/HUD/VBoxContainer"
@onready var score_label: Label = $"../CanvasLayer/HUD/Corner/ScoreLabel"
@onready var score_container: VBoxContainer = $"../CanvasLayer/HUD/Corner"
@onready var conductor = $".."
@onready var health_bar: ProgressBar = $"../CanvasLayer/HUD/Corner/HealthBar"
@onready var deletion_zone: Area2D = $"../DELETIONRAH"

const damage: float = 1.0
const regen: float = 5.0
const normal_health_color = Color.WHITE
const flash_red_color = Color.CRIMSON

var notes_in_zone: Array[Area2D] = []
var current_combo: int = 0
var current_score: int = 0
var ui_tween: Tween
var score_tween: Tween

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	deletion_zone.area_entered.connect(_on_deletion_zone_entered)
	
	# Clear out the placeholder text on startup
	accuracy_label.text = ""
	combo_label.text = ""


func _on_area_entered(area: Area2D) -> void:
	if "target_beat" in area and "note_type" in area:
		notes_in_zone.append(area)

func _on_area_exited(area: Area2D) -> void:
	if area in notes_in_zone:
		notes_in_zone.erase(area)

func _on_deletion_zone_entered(area: Area2D) -> void:
	# Make sure the thing entering is actually a note we track
	if "target_beat" in area and "note_type" in area:
		# Safely clean it out of the active hit zone array if it hasn't left yet
		if area in notes_in_zone:
			notes_in_zone.erase(area)
		
		# Prevent double-triggering misses if the game is already reloading
		if not conductor.is_restarting:
			apply_damage(damage) # Make sure this variable name matches your damage var
			current_combo = 0
			update_ui("MISS", Color.DARK_RED)
		
		# Destroy the note cleanly
		area.queue_free()

func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("hit_left"):
			check_hit("hit_left")
			conductor.play_hitsound("hit_left")
		elif event.is_action_pressed("hit_right"):
			check_hit("hit_right")
			conductor.play_hitsound("hit_right")

func apply_damage(damage: float) -> void:
	health_bar.value -= damage
	# Flash red
	var fill_style = health_bar.get_theme_stylebox("fill").duplicate()
	health_bar.add_theme_stylebox_override("fill", fill_style)
	# To red
	fill_style.bg_color = flash_red_color
	# Back to normal
	var flash_tween = create_tween()
	flash_tween.tween_property(fill_style, "bg_color", normal_health_color, 0.2).set_trans(Tween.TRANS_LINEAR)
	# Gameover
	if health_bar.value <= 0.0 and not conductor.is_restarting:
		conductor.restart_game()
	

func check_hit(pressed_input: String) -> void:
	if notes_in_zone.is_empty():
		return
		
	var target_note = notes_in_zone[0]
	
	# Validate matching lane type
	if target_note.note_type != pressed_input:
		apply_damage(damage)
		current_combo = 0
		update_ui("WRONG KEY", Color.CRIMSON)
		notes_in_zone.remove_at(0)
		target_note.queue_free()
		return

	# Calculate absolute timing error in fractions of a beat
	var beat_error = abs(target_note.target_beat - conductor.song_beat)
		
	notes_in_zone.remove_at(0)
	target_note.queue_free()
	
	# Evaluate thresholds based on beats (assuming 120 BPM, 0.05 beats is ~25ms)
	if beat_error <= 0.10:
		health_bar.value += regen
		current_combo += 1
		current_score += 500
		update_ui("PERFECT!!!", Color.GOLD)
	elif beat_error <= 0.20:
		current_combo += 1
		current_score += 300
		update_ui("GREAT!", Color.CYAN)
	elif beat_error <= 0.40:
		current_combo += 1
		current_score += 100
		update_ui("GOOD", Color.SPRING_GREEN)
	else:
		apply_damage(damage)
		current_combo = 0
		update_ui("BAD", Color.ORANGE_RED)


# Helper function to change texts, colors, and handle pop animations cleanly
func update_ui(rating_text: String, text_color: Color) -> void:
	# Update text values
	accuracy_label.text = rating_text
	accuracy_label.modulate = text_color
	
	if current_combo > 0:
		combo_label.text = "Combo: " + str(current_combo)
	else:
		combo_label.text = "" # Hide combo text entirely if combo breaks
	
	score_label.text = "Score: " + str(current_score)
		
	# -Animation text
	if ui_tween and ui_tween.is_valid():
		ui_tween.kill()
		
	ui_tween = create_tween()
	ui_container.scale = Vector2(1.2, 1.2)
	ui_tween.tween_property(ui_container, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
