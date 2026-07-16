extends Control

## Signal emitted when the puzzle is solved — for MainMenu integration
signal minigame_won

# IMAGE, currently using 375 x 500, if i didn't mess up it should adjust to any res
var puzzle_image: Texture2D = preload("res://Assets/Background/rebuilt.png")

const ROWS: int = 3
const COLS: int = 4
# How much the image is shuffled, more means harder
const SHUFFLE: int = 25

var tile_size: Vector2
# Last item in arr is the blank space
var empty_tile_index: int = (ROWS * COLS) - 1
var board_state: Array = []   # Tracks the current order of tiles on the board
var moves_count: int = 0       # Tracks total moves made by the player
var is_game_over: bool = false # Prevents moves after winning

@onready var paper_container: Panel = $PaperContainer
@onready var puzzle_grid: GridContainer = $PaperContainer/HBoxContainer/LeftPanel/PuzzleGrid
@onready var reset_button: Button = $PaperContainer/HBoxContainer/PanelContainer/ResetButton
@onready var move_label: Label = $PaperContainer/HBoxContainer/PanelContainer/MoveLabel

func _ready() -> void:
	if not puzzle_image:
		print("Please assign a Puzzle Image in the Inspector!")
		return
	# Calculate how large each tile needs to be based on the image size
	tile_size = Vector2(puzzle_image.get_width() / COLS, puzzle_image.get_height() / ROWS)
	# Set up the GridContainer's layout constraints
	puzzle_grid.columns = COLS
	# Force size settings here instead of inspector
	reset_button.custom_minimum_size = Vector2(150, 50)
	
	# Safely clear old connections and bind it directly
	if reset_button.pressed.is_connected(_on_reset_button_pressed):
		reset_button.pressed.disconnect(_on_reset_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)

	start_new_game()
	
func start_new_game() -> void:
	for child in puzzle_grid.get_children():
		child.free()
	board_state.clear()
	
	moves_count = 0
	is_game_over = false
	move_label.text = "Moves: 0"
	
	create_puzzle_tiles()
	shuffle_board_safely()
	update_grid_visuals()


func _on_reset_button_pressed() -> void:
	start_new_game()
	

func create_puzzle_tiles() -> void:		
	for i in range(COLS * ROWS):
		board_state.append(i)
		
		var tile = TextureButton.new()
		tile.custom_minimum_size = tile_size
		tile.size = tile_size
		tile.ignore_texture_size = true
		tile.stretch_mode = TextureButton.STRETCH_SCALE
		tile.name = "Tile_" + str(i)
		
		# Connect button click and pass its grid slot position index
		tile.pressed.connect(_on_tile_pressed.bind(i))
		
		puzzle_grid.add_child(tile)


func update_grid_visuals() -> void:
	for slot_index in range(COLS * ROWS):
		var tile_id = board_state[slot_index]
		var tile_button = puzzle_grid.get_child(slot_index) as TextureButton
		
		# Map the correct texture frame based on its real ID number identity
		var r = tile_id / COLS
		var c = tile_id % COLS
		var atlas = AtlasTexture.new()
		atlas.atlas = puzzle_image
		atlas.region = Rect2(c * tile_size.x, r * tile_size.y, tile_size.x, tile_size.y)
		tile_button.texture_normal = atlas
		
		# IF THIS SLOT HOLDS THE BLANK ID, WIPE ITS TEXTURE IMMEDIATELY
		if tile_id == empty_tile_index:
			tile_button.texture_normal = null

# Handle player clicks
func _on_tile_pressed(clicked_pos: int) -> void:
	# Find where the blank tile currently is
	var blank_pos = board_state.find(empty_tile_index)
	
	# Convert 1D array positions into 2D Grid positions (Row and Column)
	var clicked_r = clicked_pos / COLS
	var clicked_c = clicked_pos % COLS
	var blank_r = blank_pos / COLS
	var blank_c = blank_pos % COLS
	
	# If clicked tile is 1 distance / right next to blank space then:
	var distance = abs(clicked_r - blank_r) + abs(clicked_c - blank_c)
	if distance == 1:
		# Swap them in our data array
		var temp = board_state[clicked_pos]
		board_state[clicked_pos] = board_state[blank_pos]
		board_state[blank_pos] = temp
		
		# Update the moves counter and refresh UI text
		moves_count += 1
		move_label.text = "Moves: " + str(moves_count)
		
		# Refresh the screen
		update_grid_visuals()
		check_win_condition()

# Shuffle by random moves
func shuffle_board_safely() -> void:
	for step in range(SHUFFLE):
		var blank_pos = board_state.find(empty_tile_index)
		var valid_moves = []
		
		var r = blank_pos / COLS
		var c = blank_pos % COLS
		
		# Check up, down, left, right boundaries
		if r > 0: valid_moves.append(blank_pos - COLS)
		if r < ROWS - 1: valid_moves.append(blank_pos + COLS)
		if c > 0: valid_moves.append(blank_pos - 1)
		if c < COLS - 1: valid_moves.append(blank_pos + 1)
		
		# Pick a random valid neighboring tile and swap with it
		var random_pos = valid_moves[randi() % valid_moves.size()]
		var temp = board_state[blank_pos]
		board_state[blank_pos] = board_state[random_pos]
		board_state[random_pos] = temp

# Check if the arrays are 0 == 0, 1 == 1, ect for win
func check_win_condition() -> void:
	var is_win = true
	for i in range(board_state.size()):
		if board_state[i] != i:
			is_win = false
			break
			
	if is_win:
		for child in puzzle_grid.get_children():
			child.pressed.disconnect(_on_tile_pressed)
			
		print("You Won!")
		# Bring back the missing piece texture to complete the picture
		var blank_pos = board_state.find(empty_tile_index)
		var tile_button = puzzle_grid.get_child(blank_pos) as TextureButton
		var r = empty_tile_index / COLS
		var c = empty_tile_index % COLS
		var atlas = AtlasTexture.new()
		atlas.atlas = puzzle_image
		atlas.region = Rect2(c * tile_size.x, r * tile_size.y, tile_size.x, tile_size.y)
		tile_button.texture_normal = atlas
		
		await get_tree().create_timer(1.0).timeout
		var fade = create_tween()
		fade.tween_property(paper_container, "modulate", Color(1, 1, 1, 0), 0.4)
		await fade.finished
		paper_container.queue_free()
		# Emit signal so MainMenu can continue story
		minigame_won.emit()
