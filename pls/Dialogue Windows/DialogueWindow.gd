extends Node2D
class_name DialogueWindow

## Runtime controller for the dialogue scene.
##
## Usage:
##   var window := preload("res://Dialogue Windows/dialgoue.tscn").instantiate()
##   add_child(window)
##   window.start("res://Dialogue Windows/example.dialogue", "test")
##   window.dialogue_finished.connect(func(key): print(key))
##
## Scene commands inside dialogue files:
##   #background farm_sky              (uses a top-of-file texture key)
##   #background = res://path/bg.png  (direct path)
##   #clearcharacters                  (hides all portrait slots + name tag)

signal dialogue_finished(return_key: String)
signal line_shown(text: String)
signal speaker_changed(character_id: String, slot: int, display_name: String)

@export var inactive_modulate : Color = Color(0.45, 0.45, 0.45, 1.0)
@export var active_modulate : Color = Color(1, 1, 1, 1)
@export var autostart : bool = false
@export var test_dialogue_path : String = "res://Dialogue Windows/example.txt"
@export var test_section : String = "test"
@export var typing_speed : float = 0.03  ## Seconds per character when typing

@onready var _name_tag: Node2D = $NameTag
@onready var _name_label: Label = $NameTag/Name
@onready var _text_label: Label = $Text
@onready var _background: Sprite2D = $Background
@onready var _speaker_icons: Array[Sprite2D] = [$SpeakerIcon1, $SpeakerIcon2]
@onready var _option_buttons: Array[Button] = [$Option1, $Option2]

var _data : DialogueData
var _current_section := ""
var _instructions : Array[DialogueInstruction] = []
var _index := 0
var _waiting_for_input := false
var _in_choice := false
var _completed_sections : Dictionary = {}

var _slot_characters : Dictionary = {}
var _active_slot := 0
var _last_speaker_id := ""

# When speaker tags don’t specify a slot, we auto-assign to keep 2 portraits alternating.
# Slot 1/2 only.
var _auto_next_slot := 1


var _texture_regex := RegEx.new()

# Typing effect
var _is_typing := false
var _full_text := ""
var _typing_tween: Tween

# Thought mode — blocks the name tag from showing
var _thought_active := false

# Tracks the last chosen option index (0-based) for branching
var last_chosen_option_index := -1


func _ready() -> void:
	_texture_regex.compile("\\$\\(([^)]+)\\)\\$")
	_hide_choices()
	for button in _option_buttons:
		button.pressed.connect(_on_choice_pressed.bind(button))

	if autostart:
		dialogue_finished.connect(func(key: String) -> void:
			print("Dialogue finished, return key: ", key)
		)
		call_deferred("start", test_dialogue_path, test_section)


func start(dialogue_path: String, section_name: String) -> void:
	_data = DialogueParser.load_dialogue(dialogue_path)
	if not _data.sections.has(section_name):
		push_error("DialogueWindow: section '%s' not found in %s" % [section_name, dialogue_path])
		return

	var section: DialogueSection = _data.sections[section_name]
	_current_section = section_name
	if _completed_sections.has(section_name):
		_instructions = section.exhausted_dialogue
	else:
		_instructions = section.dialogue

	_index = 0
	_waiting_for_input = false
	_in_choice = false
	_slot_characters.clear()
	_active_slot = 0
	_last_speaker_id = ""
	_auto_next_slot = 1
	_text_label.text = ""
	_waiting_for_input = false
	_in_choice = false


	_name_label.text = ""
	_is_typing = false
	if _typing_tween and _typing_tween.is_running():
		_typing_tween.kill()
	_reset_speakers()
	_hide_choices()
	show()
	_advance()


func mark_section_completed(section_name: String) -> void:
	_completed_sections[section_name] = true


func get_current_speaker() -> String:
	return _last_speaker_id


func get_display_name(character_id: String) -> String:
	if _data == null:
		return character_id
	return _data.characters.get(character_id, character_id.capitalize())


func _input(event: InputEvent) -> void:
	if not visible or _in_choice:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if _is_typing:
			# First tap: complete the typing effect instantly
			_skip_typing()
			get_viewport().set_input_as_handled()
		elif _waiting_for_input:
			# Second tap: advance to next line
			_advance()
			get_viewport().set_input_as_handled()


func _skip_typing() -> void:
	if _typing_tween and _typing_tween.is_running():
		_typing_tween.kill()
	_is_typing = false
	_text_label.text = _full_text
	_waiting_for_input = true
	line_shown.emit(_full_text)


func _advance() -> void:
	_waiting_for_input = false
	_is_typing = false
	if _typing_tween and _typing_tween.is_running():
		_typing_tween.kill()

	while _index < _instructions.size():
		var instr := _instructions[_index]
		_index += 1

		match instr.type:
			DialogueInstruction.Type.SPEAKER:
				_apply_speaker(instr)
			DialogueInstruction.Type.COMMAND:
				_apply_command(instr)
			DialogueInstruction.Type.TEXT:
				_show_text(instr.text)
				return
			DialogueInstruction.Type.CHOICE:
				_show_choices(instr.choices)
				return

	_finish_section()


func _apply_command(instr: DialogueInstruction) -> void:
	match instr.command:
		"background":
			_apply_background(instr.command_value)
		"clearcharacters":
			_clear_characters()
		"thought":
			_show_thought()


func _apply_background(key_or_path: String) -> void:
	if key_or_path == "":
		push_error("DialogueWindow: #background requires a texture key or path")
		return

	var path := _resolve_asset_path(key_or_path)
	if path == "":
		push_error("DialogueWindow: unknown background '%s'" % key_or_path)
		return

	var tex := load(path) as Texture2D
	if tex == null:
		push_error("DialogueWindow: failed to load background '%s'" % path)
		return

	_background.texture = tex
	_background.visible = true


func _clear_characters() -> void:
	_slot_characters.clear()
	_active_slot = 0
	_last_speaker_id = ""
	_name_label.text = ""
	_sync_name_tag_visibility()

	for sprite in _speaker_icons:
		sprite.visible = false
		sprite.modulate = active_modulate


## Dims portraits and hides the name tag for internal thoughts / narration.
## Portraits stay visible but darkened so the scene still feels alive.
## The next <character-slot> tag restores everything.
func _show_thought() -> void:
	_thought_active = true
	_name_label.text = ""
	# Thought should NOT hide portraits — only darken them.
	_name_tag.visible = false
	for sprite in _speaker_icons:
		# Keep visibility as-is, just dim.
		sprite.modulate = inactive_modulate



## Fully clears everything — name tag + all portraits hidden.
## Use sparingly for scene breaks.
func _clear_all() -> void:
	_clear_characters()
	_slot_characters.clear()
	_active_slot = 0
	_last_speaker_id = ""


func _show_text(raw_text: String) -> void:
	var display_text := raw_text
	var regex_match := _texture_regex.search(raw_text)
	while regex_match:
		var texture_key: String = regex_match.get_string(1)
		_apply_texture_tag(texture_key)
		display_text = display_text.replace(regex_match.get_string(0), "")
		regex_match = _texture_regex.search(display_text)

	display_text = display_text.strip_edges()

	# Start typing effect
	_full_text = display_text
	_text_label.text = ""
	_is_typing = true
	_waiting_for_input = false

	if display_text.length() == 0:
		# Empty text, just emit and wait
		_is_typing = false
		_waiting_for_input = true
		line_shown.emit("")
	else:
		_typing_tween = create_tween()
		_typing_tween.set_ease(Tween.EASE_IN)
		_typing_tween.tween_method(_update_typing, 0.0, float(_full_text.length()), _full_text.length() * typing_speed)
		_typing_tween.tween_callback(_finish_typing)


func _update_typing(progress: float) -> void:
	var count := mini(int(progress), _full_text.length())
	_text_label.text = _full_text.substr(0, count)


func _finish_typing() -> void:
	_is_typing = false
	_text_label.text = _full_text
	_waiting_for_input = true
	line_shown.emit(_full_text)


func _apply_texture_tag(texture_key: String) -> void:
	var path := _resolve_asset_path(texture_key)
	if path == "":
		return

	var tex := load(path) as Texture2D
	if tex and _active_slot > 0 and _active_slot <= _speaker_icons.size():
		var sprite := _speaker_icons[_active_slot - 1]
		sprite.texture = tex
		sprite.visible = true


func _apply_speaker(instr: DialogueInstruction) -> void:
	# A speaker tag exits thought mode — show everything again
	_thought_active = false
	var slot := instr.speaker_slot
	# Auto-assign slots when speaker tags omit it (or set 0).
	if slot == 0:
		slot = _auto_next_slot
		_auto_next_slot = 2 if _auto_next_slot == 1 else 1

	if slot < 1 or slot > _speaker_icons.size():
		push_error("DialogueWindow: invalid speaker slot %d" % slot)
		return


	var sprite := _speaker_icons[slot - 1]
	var portrait := _resolve_portrait(instr.character_id, instr.emotion)

	if _slot_characters.get(slot, "") != instr.character_id:
		if portrait:
			sprite.texture = portrait
		_slot_characters[slot] = instr.character_id

	sprite.visible = true
	_active_slot = slot
	_last_speaker_id = instr.character_id
	_name_label.text = get_display_name(instr.character_id)
	_sync_name_tag_visibility()
	_refresh_speaker_highlights()
	speaker_changed.emit(instr.character_id, slot, _name_label.text)


func _sync_name_tag_visibility() -> void:
	_name_tag.visible = not _thought_active and _name_label.text != ""


func _resolve_portrait(character_id: String, emotion: String) -> Texture2D:
	var flat_key := "%s_%s" % [character_id, emotion]
	var path := _resolve_asset_path(flat_key)
	if path != "":
		return load(path) as Texture2D

	if _data.portraits.has(character_id):
		var moods: Dictionary = _data.portraits[character_id]
		if moods.has(emotion):
			return load(moods[emotion]) as Texture2D
		if moods.has("default"):
			return load(moods["default"]) as Texture2D
		for key in moods:
			return load(moods[key]) as Texture2D

	return null


func _resolve_asset_path(key_or_path: String) -> String:
	if key_or_path.begins_with("res://"):
		return key_or_path
	if _data != null and _data.textures.has(key_or_path):
		return _data.textures[key_or_path]
	return ""


func _refresh_speaker_highlights() -> void:
	for i in _speaker_icons.size():
		var slot := i + 1
		if not _slot_characters.has(slot):
			continue
		_speaker_icons[i].modulate = active_modulate if slot == _active_slot else inactive_modulate


func _reset_speakers() -> void:
	for sprite in _speaker_icons:
		sprite.visible = false
		sprite.modulate = active_modulate
	_sync_name_tag_visibility()


func _show_choices(choices: Array[DialogueChoice]) -> void:
	_in_choice = true
	_hide_choices()

	for i in mini(choices.size(), _option_buttons.size()):
		_option_buttons[i].text = choices[i].text
		_option_buttons[i].visible = true
		_option_buttons[i].disabled = not choices[i].enabled
		_option_buttons[i].set_meta("choice_index", i)
		_option_buttons[i].set_meta("choice_data", choices[i])


func _hide_choices() -> void:
	_in_choice = false
	for button in _option_buttons:
		button.visible = false
		if button.has_meta("choice_index"):
			button.remove_meta("choice_index")
		if button.has_meta("choice_data"):
			button.remove_meta("choice_data")


func _on_choice_pressed(button: Button) -> void:
	if not button.has_meta("choice_data"):
		return

	var choice: DialogueChoice = button.get_meta("choice_data")
	last_chosen_option_index = button.get_meta("choice_index", -1)
	_hide_choices()

	var resume: Array[DialogueInstruction] = _instructions.slice(_index)
	_instructions = choice.dialogue + resume
	_index = 0
	_advance()


func _finish_section() -> void:
	# section_return_key comes from the section header block (a '#... ' token).
	# If the section has no '#return_key', emit an empty string.
	var section_return_key := ""
	if _data.sections.has(_current_section):
		var section: DialogueSection = _data.sections[_current_section]
		section_return_key = section.return_key
		if section_return_key != "":
			mark_section_completed(_current_section)

	hide()
	dialogue_finished.emit(section_return_key)
