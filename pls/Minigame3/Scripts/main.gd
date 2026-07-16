extends Node2D

var arrow_scene = preload("res://Scenes/arrow.tscn")

@export var custom_font: Font
@export var arrow_left_img: Texture2D
@export var arrow_down_img: Texture2D
@export var arrow_up_img: Texture2D
@export var arrow_right_img: Texture2D

var lane_positions = {
	"ui_left": 100,
	"ui_down": 170,
	"ui_up": 240,
	"ui_right": 310
}

var arrow_images = {}
var bpm = 82.0
var sec_per_beat = 60.0 / bpm
var last_beat = 0

# --- PURE CEMENT & COMBO VARIABLES ---
var progress = 0.0
var combo = 0

@onready var audio_player = $AudioStreamPlayer

func _ready():
	arrow_images = {
		"ui_left": arrow_left_img,
		"ui_down": arrow_down_img,
		"ui_up": arrow_up_img,
		"ui_right": arrow_right_img
	}
	update_hud()

func _process(_delta):
	if audio_player.playing:
		var time = audio_player.get_playback_position()
		var current_beat = int(time / (sec_per_beat )) 
		
		if current_beat < last_beat:
			last_beat = -1
			
		if current_beat > last_beat:
			last_beat = current_beat
			spawn_arrow()
	
	check_input()

func spawn_arrow():
	var directions = ["ui_left", "ui_down", "ui_up", "ui_right"]
	
	var num_arrows = 1
	var roll = randf()
	if roll < 0.01:
		num_arrows = 3 
	elif roll < 0.05:
		num_arrows = 2 
		
	directions.shuffle()
	
	for i in range(num_arrows):
		var chosen = directions[i]
		var new_arrow = arrow_scene.instantiate()
		new_arrow.direction_name = chosen
		new_arrow.position.x = 1200
		new_arrow.position.y = lane_positions[chosen]
		new_arrow.get_node("Sprite2D").texture = arrow_images[chosen]
		add_child(new_arrow)

func check_input():
	var directions = ["ui_left", "ui_down", "ui_up", "ui_right"]
	
	for dir in directions:
		if Input.is_action_just_pressed(dir):
			var closest_arrow = null
			var closest_distance = 999
			var hit_diff = 0 
			
			for child in get_children():
				if child.has_method("hit") and "direction_name" in child and child.direction_name == dir and not child.was_hit:
					var diff = child.position.x - 200 
					var distance = abs(diff)
					if distance < closest_distance:
						closest_distance = distance
						closest_arrow = child
						hit_diff = diff
			
			if closest_arrow and closest_distance < 80:
				closest_arrow.hit()
				
				if closest_distance <= 25:
					on_arrow_hit("Perfect!", Color.GOLD)
				else:
					if hit_diff > 0:
						on_arrow_hit("Early", Color.CYAN)
					else:
						on_arrow_hit("Late", Color.ORANGE)
			else:
				on_arrow_miss()

func on_arrow_hit(judgment: String, color: Color):
	combo += 1
	
	# --- FILL CEMENT (Fills faster with Combos & Perfects!) ---
	var cement_gained = 1.0
	if judgment == "Perfect!":
		cement_gained += 0.5 
		
	if combo >= 20:
		cement_gained += 3.0 
	elif combo >= 10:
		cement_gained += 1.5 
	elif combo >= 5:
		cement_gained += 0.5 
		
	progress += cement_gained 
	# --------------------------------------------------------
	
	if progress > 100:
		progress = 100
		
	$Player.play_hit_reaction()
	update_foundation()
	show_floating_text(judgment, color)
	update_hud()
	
	if progress == 100:
		if $HUD.has_method("show_win"):
			$HUD.show_win()
		audio_player.stop()

func on_arrow_miss():
	progress -= 25
	if progress < 0:
		progress = 0
		
	combo = 0 # Misses break your combo!
	
	if $Player.has_method("play_miss_reaction"):
		$Player.play_miss_reaction()
		
	update_foundation()
	show_floating_text("Miss!", Color.RED)
	update_hud()

func show_floating_text(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 45)
	
	# --- ADD THESE TWO LINES ---
	if custom_font != null:
		label.add_theme_font_override("font", custom_font)
	# ---------------------------
	
	label.position = Vector2(180, 200) 
	add_child(label)
	
	var t = create_tween()
	t.tween_property(label, "position:y", label.position.y - 100, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(label.queue_free)

func update_hud():
	if $HUD.has_node("ProgressBar"):
		$HUD.get_node("ProgressBar").value = progress
	if $HUD.has_node("ComboLabel"):
		if combo >= 5:
			$HUD.get_node("ComboLabel").text = "Combo x" + str(combo)
		else:
			$HUD.get_node("ComboLabel").text = "" 

func update_foundation():
	if has_node("CementFill"):
		var cement = $CementFill
		var gap_bottom = 639
		var gap_top = 384
		var max_height = gap_bottom - gap_top 
		var fill_height = (progress / 100.0) * max_height
		cement.size.y = fill_height
		cement.position.y = gap_bottom - fill_height
