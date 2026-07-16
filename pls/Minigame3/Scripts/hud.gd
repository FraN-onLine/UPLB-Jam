extends CanvasLayer

@onready var heart1 = $Hearts/Heart1
@onready var heart2 = $Hearts/Heart2
@onready var heart3 = $Hearts/Heart3
@onready var timer_label = $TimerLabel
@onready var game_over_screen = $GameOverScreen
@onready var win_screen = $WinScreen
@onready var pause_screen = $PauseScreen

@export var full_heart_image: Texture2D
@export var empty_heart_image: Texture2D

var score_goal = 1000
var time_left = 90.0
var game_ended = false

func _ready():
	$GameOverScreen/RestartButton.pressed.connect(_on_restart)
	$WinScreen/RestartButton.pressed.connect(_on_restart)
	$PauseScreen/ContinueButton.pressed.connect(_on_continue)
	$PauseScreen/QuitButton.pressed.connect(_on_restart)

func _process(delta):
	if game_ended:
		return
		
	if time_left > 0:
		time_left -= delta
		timer_label.text = str(int(time_left))
	else:
		timer_label.text = "0"
		show_game_over()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if game_ended:
			return
		if pause_screen.visible:
			_on_continue()
		else:
			pause_screen.visible = true
			get_tree().paused = true

func update_hearts(current_health):
	var hearts = [heart1, heart2, heart3]
	for i in 3:
		if i < current_health:
			hearts[i].texture = full_heart_image
		else:
			hearts[i].texture = empty_heart_image


func show_game_over():
	game_ended = true
	game_over_screen.visible = true
	get_tree().paused = true

func show_win():
	game_ended = true
	win_screen.visible = true
	get_tree().paused = true

func _on_restart():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_continue():
	pause_screen.visible = false
	get_tree().paused = false
