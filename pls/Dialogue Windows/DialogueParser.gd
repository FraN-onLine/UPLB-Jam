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
		var parts := left.split(".", false, 1)
		var char_id := parts[0]
		var emotion := parts[1]
		if not data.portraits.has(char_id):
			data.portraits[char_id] = {}
		data.portraits[char_id][emotion] = right
	elif is_asset_path:
		data.textures[left] = right
		if left.contains("_"):
			var split_at := left.rfind("_")
			var char_id := left.substr(0, split_at)
			var emotion := left.substr(split_at + 1)
			if not data.portraits.has(char_id):
				data.portraits[char_id] = {}
			data.portraits[char_id][emotion] = right
	else:
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

	while i < tokens.size():
		var token := tokens[i]

		if token.type == DialogueToken.Type.SECTION_END:
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

	if char_part.contains("."):
		var parts := char_part.split(".", false, 1)
		character_id = parts[0]
		emotion = parts[1]

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
