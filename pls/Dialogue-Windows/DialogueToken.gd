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

	EXHAUSTED,
	
	MERGE,       ## #merge section_name — mid-section jump
	SET_FLAG,    ## #set_flag flag_name
	REQUIRE_FLAG,## #require_flag flag_name
	END_REQUIRE  ## #end_require
}

var type : Type

var value = null

var line : int