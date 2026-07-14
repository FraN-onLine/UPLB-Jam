extends RefCounted
class_name DialogueInstruction

enum Type {
	TEXT,
	SPEAKER,
	CHOICE
}

## What kind of instruction this is
var type : Type

## ---------- TEXT ----------
var text : String = ""

## ---------- SPEAKER ----------
var character_id : String = ""
var speaker_slot : int = 0
var portrait : Texture2D = null

## ---------- CHOICE ----------
## [
##     {"text":"Yes", "dialogue":[DialogueInstruction,...]},
##     {"text":"No", "dialogue":[DialogueInstruction,...]}
## ]
var choices : Array = []

## Debugging
var line : int = 0
