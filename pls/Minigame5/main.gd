extends Node2D

signal minigame_finished

@export var custom_font: Font

var triggered = []
var music_stopped = false # Track if the music has been faded out yet

@onready var player = $Player
@onready var camera = $Camera2D

var fade_rect: ColorRect
var ending_label: Label 

var thoughts = [
	{"x": 100, "text": "..."},
	{"x": 250, "text": "It's been a while since I walked these streets."},
	{"x": 500, "text": "Everything looks... different now."},
	{"x": 750, "text": "But the memories are still here."},
	{"x": 1000, "text": "The laughter of the children..."},
	{"x": 1250, "text": "The smell of Lola's cooking..."},
	{"x": 1500, "text": "We almost lost all of this."},
	{"x": 1750, "text": "But we didn't."},
	{"x": 2000, "text": "Because the people of Donto refused to give up."},
	{"x": 2250, "text": "Sisa... she lost so much."},
	{"x": 2500, "text": "But she kept fighting. For everyone."},
	{"x": 2750, "text": "Hiraya finally has a window to see the stars."},
	{"x": 3000, "text": "Pedro won't stop fixing things that aren't even broken."},
	{"x": 3250, "text": "Marie Tess... still as loud as ever."},
	{"x": 3500, "text": "And Lola... she can finally rest easy."},
	{"x": 3750, "text": "This place isn't perfect."},
	{"x": 4000, "text": "It never was."},
	{"x": 4250, "text": "But it's ours."},
	{"x": 4500, "text": "And that's enough."},
	{"x": 4750, "text": "Padayon, Lupang Sinilangan."},
	{"x": 5000, "text": "THE END"},
]

func _ready():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10 
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color.WHITE
	fade_rect.size = Vector2(1152, 648) 
	fade_rect.modulate.a = 0.0 
	canvas_layer.add_child(fade_rect)
	
	ending_label = Label.new()
	ending_label.text = "THANKS FOR PLAYING!"
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_label.size = Vector2(1152, 648)
	ending_label.add_theme_color_override("font_color", Color.BLACK)
	ending_label.add_theme_font_size_override("font_size", 50)
	ending_label.modulate.a = 0.0 
	if custom_font:
		ending_label.add_theme_font_override("font", custom_font)
	canvas_layer.add_child(ending_label)
	
	add_child(canvas_layer)

func _process(_delta):
	camera.position.x = player.position.x + 350
	camera.position.y = 324
	
	# --- ENDING SEQUENCE ---
	if player.position.x > 5200:
		var fade_progress = (player.position.x - 5200) / 600.0
		fade_rect.modulate.a = clamp(fade_progress, 0.0, 1.0)
		
		# When we reach 5900, fade in text AND stop music
		if player.position.x > 5900:
			var ending_progress = (player.position.x - 5900) / 300.0
			ending_label.modulate.a = clamp(ending_progress, 0.0, 1.0)
			
			# SMOOTH MUSIC FADE OUT!
			if not music_stopped and has_node("AudioStreamPlayer"):
				music_stopped = true
				var audio = $AudioStreamPlayer
				var audio_tween = create_tween()
				audio_tween.tween_property(audio, "volume_db", -60.0, 3.0) # Fade volume to -60 (silent) over 3 seconds
				audio_tween.tween_callback(audio.stop) # Then stop it completely
				# Emit signal to return to main menu after fade out
				audio_tween.tween_callback(func(): minigame_finished.emit())
	# -----------------------
	
	for i in range(thoughts.size()):
		if i not in triggered:
			if player.position.x >= thoughts[i]["x"]:
				triggered.append(i)
				show_thought(thoughts[i]["text"])

func show_thought(text: String):
	var label = Label.new()
	label.text = text
	
	label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1.0))
	label.add_theme_font_size_override("font_size", 28)
	
	if custom_font:
		label.add_theme_font_override("font", custom_font)
	
	label.position = Vector2(player.position.x - 50, player.position.y - 120)
	label.modulate.a = 0.0 
	add_child(label)
	
	# --- SLOWER TEXT ANIMATION (12 seconds total!) ---
	var float_tween = create_tween()
	float_tween.tween_property(label, "position:y", label.position.y - 80, 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var alpha_tween = create_tween()
	alpha_tween.tween_property(label, "modulate:a", 1.0, 3.0) # Fade in over 3 seconds
	alpha_tween.tween_interval(6.0) # Stay fully visible for 6 full seconds
	alpha_tween.tween_property(label, "modulate:a", 0.0, 3.0) # Fade out over 3 seconds
	alpha_tween.tween_callback(label.queue_free)
