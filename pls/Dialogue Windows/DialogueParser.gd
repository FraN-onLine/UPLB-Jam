extends RefCounted
class_name DialogueParser


static func load_dialogue(path:String)->DialogueData:

	var data := DialogueData.new()

	var tokens := _tokenize(path)

	_parse(tokens,data,path)

	return data

static func _tokenize(path:String)->Array[DialogueToken]:

	var file := FileAccess.open(path,FileAccess.READ)

	if file == null:

		push_error("Couldn't open %s"%path)

		return []

	var tokens:Array[DialogueToken]=[]

	var line_number:=0

	while !file.eof_reached():

		line_number+=1

		var raw:=file.get_line()

		var line:=raw.strip_edges()

		if line=="":
			continue

		if line.begins_with("//"):
			continue

		var token:=DialogueToken.new()

		token.line=line_number

		#
		# SECTION START
		#

		if line.begins_with("[") and line!="[end]":

			token.type=DialogueToken.Type.SECTION_START

			token.value=line.substr(1,line.length()-2)

			tokens.append(token)

			continue

		#
		# SECTION END
		#

		if line=="[end]":

			token.type=DialogueToken.Type.SECTION_END

			tokens.append(token)

			continue

		#
		# EXHAUSTED
		#

		if line.to_lower()=="when exhausted":

			token.type=DialogueToken.Type.EXHAUSTED

			tokens.append(token)

			continue

		#
		# SPEAKER
		#

		if line.begins_with("<"):

			token.type=DialogueToken.Type.SPEAKER

			token.value=line

			tokens.append(token)

			continue

		#
		# CHOICE
		#

		if line.begins_with(">"):

			token.type=DialogueToken.Type.CHOICE

			token.value={
				"text":line.substr(1).strip_edges(),
				"indent":raw.length()-raw.lstrip(" \t").length()
			}

			tokens.append(token)

			continue

		#
		# COMMAND
		#

		if line.begins_with("#"):

			token.type=DialogueToken.Type.COMMAND

			token.value=line

			tokens.append(token)

			continue

		#
		# DEFINITIONS
		#

		if line.contains("="):

			var split=line.split("=")

			if split.size()!=2:

				push_error("%s:%d Invalid definition"%[path,line_number])

				continue

			var left=split[0].strip_edges()

			var right=split[1].strip_edges()

			if left.contains("."):

				token.type=DialogueToken.Type.PORTRAIT

				token.value={
					"left":left,
					"right":right
				}

			else:

				token.type=DialogueToken.Type.CHARACTER

				token.value={
					"left":left,
					"right":right
				}

			tokens.append(token)

			continue

		#
		# TEXT
		#

		token.type=DialogueToken.Type.TEXT

		token.value={
			"text":line,
			"indent":raw.length()-raw.lstrip(" \t").length()
		}

		tokens.append(token)

	file.close()

	return tokens