extends RefCounted
class_name DialogueToken

enum Type {
	CHARACTER,
	PORTRAIT,

	SECTION_START,
	SECTION_END,

	SPEAKER,

	TEXT,

	CHOICE,

	COMMAND,

	EXHAUSTED
}

var type : Type

var value = null

var line : int
