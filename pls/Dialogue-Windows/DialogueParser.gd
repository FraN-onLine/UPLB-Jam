extends RefCounted
class_name DialogueParser

## Loads and parses a dialogue file into [DialogueData].
##
## File format (see example.dialogue in this folder):
##   - Top-of-file definitions: character names, portrait/texture paths
##   - [section_name] ... [end] blocks
##   - > choice lines (indented children, max 2 siblings per level)
##   - when exhausted + #return_key for repeat visits
##   - #background key_or_path and #clearcharacters as runtime scene commands
##   - #thought hides name tag + portraits for narration/internal monologue
static func load_dialogue(path: String) -> DialogueData:
	var data := DialogueData.new()
	var tokens := _tokenize(path)
	_parse(tokens, data, path)
	return data


static func _tokenize(path: String) -> Array[DialogueToken]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueParser: couldn't open %s" % path)
		return []

	var tokens: Array[DialogueToken] = []
	var line_number := 0

	while not file.eof_reached():
		line_number += 1
		var raw := file.get_line()
		var line := raw.strip_edges()

		if line == "" or line.begins_with("//"):
			continue

		var token := DialogueToken.new()
		token.line = line_number

		if line.begins_with("[") and line != "[end]":
			token.type = DialogueToken.Type.SECTION_START
			token.value = line.substr(1, line.length() - 2)
			tokens.append(token)
			continue

		if line == "[end]":
			token.type = DialogueToken.Type.SECTION_END
			tokens.append(token)
			continue

		if line.to_lower() == "when exhausted":
			token.type = DialogueToken.Type.EXHAUSTED
			tokens.append(token)
			continue

		if line.begins_with("<") and line.ends_with(">"):
			token.type = DialogueToken.Type.SPEAKER
			token.value = {
				"tag": line,
				"indent": raw.length() - raw.lstrip(" \t").length()
			}
			tokens.append(token)
			continue

		if line.begins_with(">"):
			token.type = DialogueToken.Type.CHOICE
			token.value = {
				"text": line.substr(1).strip_edges(),
				"indent": raw.length() - raw.lstrip(" \t").length()
			}
			tokens.append(token)
			continue

		if line.to_lower().begins_with("#merge "):
			token.type = DialogueToken.Type.MERGE
			token.value = line
			tokens.append(token)
			continue

		if line.to_lower().begins_with("#set_flag "):
			token.type = DialogueToken.Type.SET_FLAG
			token.value = line
			tokens.append(token)
			continue

		if line.to_lower().begins_with("#require_flag "):
			token.type = DialogueToken.Type.REQUIRE_FLAG
			token.value = line
			tokens.append(token)
			continue

		if line.to_lower() == "#end_require":
			token.type = DialogueToken.Type.END_REQUIRE
			token.value = line
			tokens.append(token)
			continue

		if line.begins_with("#"):
			token.type = DialogueToken.Type.COMMAND
			token.value = line
			tokens.append(token)
			continue

		if line.contains("="):
			var split := line.split("=", false, 1)
			if split.size() != 2:
				push_error("%s:%d invalid definition" % [path, line_number])
				continue

			var left := split[0].strip_edges()
			var right := split[1].strip_edges()
			token.type = DialogueToken.Type.PORTRAIT
			token.value = { "left": left, "right": right }
			tokens.append(token)
			continue

		token.type = DialogueToken.Type.TEXT
		token.value = {
			"text": line,
			"indent": raw.length() - raw.lstrip(" \t").length()
		}
		tokens.append(token)

	file.close()
	return tokens


static func _parse(tokens: Array[DialogueToken], data: DialogueData, path: String) -> void:
	var i := 0
	while i < tokens.size():
		var token := tokens[i]
		match token.type:
			DialogueToken.Type.PORTRAIT:
				_register_definition(data, token.value.left, token.value.right)
				i += 1
			DialogueToken.Type.SECTION_START:
				var section_name: String = token.value
				i += 1
				var section := DialogueSection.new()
				var main_block := _parse_instruction_block(tokens, i, 0, path, true)
				section.dialogue = main_block.instructions
				section.return_key = main_block.return_key
				i = main_block.next_index

				if i < tokens.size() and tokens[i].type == DialogueToken.Type.EXHAUSTED:
					i += 1
					var exhaust_block := _parse_instruction_block(tokens, i, 0, path)
					section.exhausted_dialogue = exhaust_block.instructions
					if exhaust_block.return_key != "":
						section.return_key = exhaust_block.return_key
					i = exhaust_block.next_index

				if i < tokens.size() and tokens[i].type == DialogueToken.Type.SECTION_END:
					i += 1
				elif i < tokens.size():
					push_error("%s:%d expected [end] for section '%s'" % [path, tokens[i].line, section_name])

				data.sections[section_name] = section
			_:
				push_error("%s:%d unexpected token outside a section" % [path, token.line])
				i += 1


static func _register_definition(data: DialogueData, left: String, right: String) -> void:
	var is_asset_path := right.begins_with("res://") or right.contains("/") or right.contains("\\")

	if left.contains(".") and is_asset_path:
		# Dot notation: character.emotion = path
		var parts := left.split(".", false, 1)
		var char_id := parts[0]
		var emotion := parts[1]
		if not data.portraits.has(char_id):
			data.portraits[char_id] = {}
		data.portraits[char_id][emotion] = right
	elif is_asset_path:
		# Asset path definition - could be a texture key or character portrait
		data.textures[left] = right
		# Also register as a portrait for the character with the same ID
		if not data.portraits.has(left):
			data.portraits[left] = {}
		data.portraits[left]["default"] = right
	else:
		# Character name definition
		data.characters[left] = right


static func _parse_instruction_block(
	tokens: Array[DialogueToken],
	start: int,
	min_indent: int,
	path: String,
	stop_before_exhausted: bool = false
) -> Dictionary:
	var instructions: Array[DialogueInstruction] = []
	var return_key := ""
	var i := start
	var require_flag_active := false  # Track if we're inside a #require_flag block

	while i < tokens.size():
		var token := tokens[i]

		if token.type == DialogueToken.Type.SECTION_END:
			# If we're inside a require block without #end_require, treat it as end
			require_flag_active = false
			break

		if stop_before_exhausted and token.type == DialogueToken.Type.EXHAUSTED:
			break

		if token.type == DialogueToken.Type.COMMAND:
			var parsed_cmd := _parse_command(token.value)
			if parsed_cmd.kind == "runtime":
				instructions.append(_make_command_instruction(parsed_cmd))
			else:
				return_key = parsed_cmd.value
			i += 1
			continue

		if token.type == DialogueToken.Type.CHOICE:
			var indent: int = token.value.indent
			if indent < min_indent:
				break

			var parsed_choices := _parse_choice_group(tokens, i, indent, path)
			instructions.append(parsed_choices.instruction)
			i = parsed_choices.next_index
			continue

		if token.type == DialogueToken.Type.SPEAKER:
			instructions.append(_make_speaker_instruction(token.value.tag, token.line))
			i += 1
			continue

		if token.type == DialogueToken.Type.TEXT:
			var text_indent: int = token.value.indent
			if text_indent < min_indent:
				break
			instructions.append_array(_make_text_instructions(token.value.text, token.line))
			i += 1
			continue

		if token.type == DialogueToken.Type.SECTION_START:
			push_error("%s:%d nested sections are not supported" % [path, token.line])
			break

		if token.type == DialogueToken.Type.MERGE:
			# #merge section_name — creates a jump instruction
			var merge_instr := DialogueInstruction.new()
			merge_instr.type = DialogueInstruction.Type.MERGE
			# Extract section name from "#merge section_name"
			var body: String = token.value.substr(1).strip_edges()  # Remove #
			var parts: PackedStringArray = body.split(" ", false, 1)
			if parts.size() >= 2:
				merge_instr.merge_section = parts[1].strip_edges()
			merge_instr.line = token.line
			instructions.append(merge_instr)
			i += 1
			continue

		if token.type == DialogueToken.Type.SET_FLAG:
			# #set_flag flag_name — creates a set_flag instruction
			var flag_instr := DialogueInstruction.new()
			flag_instr.type = DialogueInstruction.Type.SET_FLAG
			var body: String = token.value.substr(1).strip_edges()  # Remove #
			var parts: PackedStringArray = body.split(" ", false, 1)
			if parts.size() >= 2:
				flag_instr.flag_key = parts[1].strip_edges()
			flag_instr.line = token.line
			instructions.append(flag_instr)
			i += 1
			continue

		if token.type == DialogueToken.Type.REQUIRE_FLAG:
			# Start of a conditional block.
			# We create a special instruction marking the start of a require block,
			# then parse all instructions inside until #end_require.
			require_flag_active = true
			var require_instr := DialogueInstruction.new()
			require_instr.type = DialogueInstruction.Type.REQUIRE_FLAG
			var body: String = token.value.substr(1).strip_edges()
			var parts: PackedStringArray = body.split(" ", false, 1)
			if parts.size() >= 2:
				require_instr.flag_key = parts[1].strip_edges()
			require_instr.command_value = "require"
			require_instr.line = token.line
			instructions.append(require_instr)
			i += 1

			# Now parse the block contents as instructions until #end_require or section end
			var block_instructions: Array[DialogueInstruction] = []
			while i < tokens.size():
				var bt := tokens[i]
				if bt.type == DialogueToken.Type.END_REQUIRE:
					require_flag_active = false
					i += 1
					break
				if bt.type == DialogueToken.Type.SECTION_END:
					require_flag_active = false
					break
				if bt.type == DialogueToken.Type.SPEAKER:
					block_instructions.append(_make_speaker_instruction(bt.value.tag, bt.line))
					i += 1
					continue
				if bt.type == DialogueToken.Type.TEXT:
					block_instructions.append_array(_make_text_instructions(bt.value.text, bt.line))
					i += 1
					continue
				if bt.type == DialogueToken.Type.COMMAND:
					var parsed_cmd := _parse_command(bt.value)
					if parsed_cmd.kind == "runtime":
						block_instructions.append(_make_command_instruction(parsed_cmd))
					else:
						# Return key inside a require block — this would be unusual
						return_key = parsed_cmd.value
					i += 1
					continue
				if bt.type == DialogueToken.Type.CHOICE:
					var nested_indent: int = bt.value.indent
					var parsed_choices := _parse_choice_group(tokens, i, nested_indent, path)
					block_instructions.append(parsed_choices.instruction)
					i = parsed_choices.next_index
					continue
				if bt.type == DialogueToken.Type.MERGE:
					var merge_instr2 := DialogueInstruction.new()
					merge_instr2.type = DialogueInstruction.Type.MERGE
					var body2: String = bt.value.substr(1).strip_edges()
					var parts2: PackedStringArray = body2.split(" ", false, 1)
					if parts2.size() >= 2:
						merge_instr2.merge_section = parts2[1].strip_edges()
					merge_instr2.line = bt.line
					block_instructions.append(merge_instr2)
					i += 1
					continue
				if bt.type == DialogueToken.Type.SET_FLAG:
					var flag_instr2 := DialogueInstruction.new()
					flag_instr2.type = DialogueInstruction.Type.SET_FLAG
					var body2: String = bt.value.substr(1).strip_edges()
					var parts2: PackedStringArray = body2.split(" ", false, 1)
					if parts2.size() >= 2:
						flag_instr2.flag_key = parts2[1].strip_edges()
					flag_instr2.line = bt.line
					block_instructions.append(flag_instr2)
					i += 1
					continue
				i += 1

			# Add all block instructions to the require_instr as text (we'll use choice_data-like storage)
			# Store the conditional block content on the require instruction itself.
			# The runtime will skip these if the flag isn't set.
			# We use command_value "require" + flag_key, and store block instructions in a special way.
			# To avoid adding new fields, we reuse choice as a storage container.
			# Actually, let's use a simpler approach: store block instructions in flag_key
			# by encoding them. No — let's just add a field.
			# Actually, the cleanest approach: store them in an array on the instruction itself.
			# We'll add a `conditional_block` field. But for backward compat, let's use
			# the existing `choices` array to store conditional block instructions.
			# Wrap them in DialogueChoice objects.
			var wrapper_choice := DialogueChoice.new()
			wrapper_choice.text = ""  # Not used
			wrapper_choice.dialogue = block_instructions
			require_instr.choices = [wrapper_choice]
			# Also include the end_require marker info
			# We're done processing this block
			continue

		i += 1

	return {
		"instructions": instructions,
		"next_index": i,
		"return_key": return_key
	}


static func _parse_choice_group(
	tokens: Array[DialogueToken],
	start: int,
	choice_indent: int,
	path: String
) -> Dictionary:
	var choice_instr := DialogueInstruction.new()
	choice_instr.type = DialogueInstruction.Type.CHOICE
	var choices: Array[DialogueChoice] = []
	var i := start

	while i < tokens.size() and tokens[i].type == DialogueToken.Type.CHOICE:
		var choice_token := tokens[i]
		if choice_token.value.indent != choice_indent:
			break
		if choices.size() >= 2:
			push_error("%s:%d max 2 choices allowed at one level" % [path, choice_token.line])
			break

		choice_instr.line = choice_token.line
		var choice := DialogueChoice.new()
		choice.text = choice_token.value.text
		i += 1

		var branch: Array[DialogueInstruction] = []
		while i < tokens.size():
			var next := tokens[i]

			if next.type == DialogueToken.Type.SECTION_END:
				break
			if next.type == DialogueToken.Type.EXHAUSTED:
				break
			if next.type == DialogueToken.Type.CHOICE and next.value.indent <= choice_indent:
				break
			if next.type in [DialogueToken.Type.TEXT, DialogueToken.Type.SPEAKER]:
				var next_indent := _token_indent(next)
				if next_indent < choice_indent:
					break

			if next.type == DialogueToken.Type.CHOICE and next.value.indent > choice_indent:
				var nested := _parse_choice_group(tokens, i, next.value.indent, path)
				branch.append(nested.instruction)
				i = nested.next_index
				continue

			if next.type == DialogueToken.Type.SPEAKER:
				branch.append(_make_speaker_instruction(next.value.tag, next.line))
				i += 1
				continue

			if next.type == DialogueToken.Type.TEXT:
				branch.append_array(_make_text_instructions(next.value.text, next.line))
				i += 1
				continue

			if next.type == DialogueToken.Type.COMMAND:
				var parsed_cmd := _parse_command(next.value)
				if parsed_cmd.kind == "runtime":
					branch.append(_make_command_instruction(parsed_cmd))
					i += 1
					continue

				# Return keys terminate the whole section, even when they directly
				# follow the final choice branch. Leave the token for the enclosing
				# instruction block so it becomes DialogueSection.return_key.
				break

			break

		choice.dialogue = branch
		choices.append(choice)

	choice_instr.choices = choices
	return {
		"instruction": choice_instr,
		"next_index": i
	}


static func _make_text_instructions(raw_text: String, line_number: int) -> Array[DialogueInstruction]:
	var result: Array[DialogueInstruction] = []
	var text := raw_text
	var speaker_tag := ""

	var tag_start := text.rfind("<")
	if tag_start != -1 and text.ends_with(">"):
		var maybe_tag := text.substr(tag_start)
		if _parse_speaker_tag(maybe_tag).size() > 0:
			speaker_tag = maybe_tag
			text = text.substr(0, tag_start).strip_edges()

	if text != "":
		var text_instr := DialogueInstruction.new()
		text_instr.type = DialogueInstruction.Type.TEXT
		text_instr.text = text
		text_instr.line = line_number
		result.append(text_instr)

	if speaker_tag != "":
		result.append(_make_speaker_instruction(speaker_tag, line_number))

	return result


static func _make_speaker_instruction(tag: String, line_number: int) -> DialogueInstruction:
	var parsed := _parse_speaker_tag(tag)
	var instr := DialogueInstruction.new()
	instr.type = DialogueInstruction.Type.SPEAKER
	instr.character_id = parsed.get("character_id", "")
	instr.speaker_slot = parsed.get("slot", 0)
	instr.emotion = parsed.get("emotion", "default")
	instr.line = line_number
	return instr


## Parses tags like <grandma-1>, <player.happy-2>, <emman-1>.
static func _parse_speaker_tag(tag: String) -> Dictionary:
	if not tag.begins_with("<") or not tag.ends_with(">"):
		return {}

	var inner := tag.substr(1, tag.length() - 2)
	var dash_idx := inner.rfind("-")
	if dash_idx == -1:
		return {}

	var slot_str := inner.substr(dash_idx + 1)
	if not slot_str.is_valid_int():
		return {}

	var char_part := inner.substr(0, dash_idx)
	var character_id := char_part
	var emotion := "default"

	# Check for dot notation: <character.emotion-slot>
	if char_part.contains("."):
		var parts := char_part.split(".", false, 1)
		character_id = parts[0]
		emotion = parts[1]
	# Check for underscore notation: <character_emotion-slot>
	# This treats the whole thing as a character ID with default emotion
	else:
		character_id = char_part
		emotion = "default"

	return {
		"character_id": character_id,
		"slot": slot_str.to_int(),
		"emotion": emotion
	}


static func _token_indent(token: DialogueToken) -> int:
	if token.value is Dictionary and token.value.has("indent"):
		return token.value.indent
	return 0


## Parses a #command line. Returns:
##   { "kind": "runtime", "command": "...", "value": "..." } for runtime commands
##   { "kind": "return_key", "value": "..." } for section return keys
static func _parse_command(line: String) -> Dictionary:
	var body := line.substr(1).strip_edges()
	var lower := body.to_lower()

	if lower == "clearcharacters":
		return { "kind": "runtime", "command": "clearcharacters" }

	if lower == "thought":
		return { "kind": "runtime", "command": "thought" }

	if lower.begins_with("background"):
		var value := ""
		if body.contains("="):
			value = body.split("=", false, 1)[1].strip_edges()
		else:
			var parts := body.split(" ", false)
			if parts.size() >= 2:
				value = parts[1].strip_edges()
		return { "kind": "runtime", "command": "background", "value": value }

	return { "kind": "return_key", "value": body }


static func _make_command_instruction(parsed: Dictionary) -> DialogueInstruction:
	var instr := DialogueInstruction.new()
	instr.type = DialogueInstruction.Type.COMMAND
	instr.command = parsed.command
	instr.command_value = parsed.get("value", "")
	return instr
