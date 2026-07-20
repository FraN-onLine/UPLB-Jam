extends RefCounted
class_name DialogueInstruction

enum Type {
	TEXT,
	SPEAKER,
	CHOICE,
	COMMAND,
	MERGE,       ## Instruction to merge to another section mid-story
	SET_FLAG,    ## Set a story flag
	REQUIRE_FLAG ## Conditional: only show next lines if flag is set (used as wrapper)
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

# MERGE — jump to another section mid-story (#merge section_name)
var merge_section : String = ""

# SET_FLAG — story flag key to set (#set_flag flag_name)
var flag_key : String = ""

# REQUIRE_FLAG — conditional block guard (#require_flag flag_name / #end_require)
# Stored as `flag_key` for the flag name, and `command_value` "require" or "end_require"
var flag_require_active : bool = false

var line : int = 0