extends RefCounted
class_name DialogueInstruction

enum Type {
	TEXT,
	SPEAKER,
	CHOICE,
	COMMAND
}

var type : Type

# TEXT
var text : String = ""

# SPEAKER — parsed from tags like <grandma-1> or <grandma.happy-2>
var character_id : String = ""
var speaker_slot : int = 0
var emotion : String = "default"

# CHOICE — up to two options; each may contain nested choices.
var choices : Array[DialogueChoice] = []

# COMMAND — runtime scene commands (#background, #clearcharacters)
var command : String = ""
var command_value : String = ""

var line : int = 0
