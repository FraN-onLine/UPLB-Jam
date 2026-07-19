extends RefCounted
class_name DialogueData

## Display names keyed by character id.
## Example: { "grandma": "Lola", "player": "You" }
var characters : Dictionary = {}

## Nested portrait paths: portraits["grandma"]["happy"] = "res://..."
var portraits : Dictionary = {}

## Flat texture paths for $(key)$ references and underscore definitions.
## Example: { "grandma_happy": "res://Assets/grandma_happy.png" }
var textures : Dictionary = {}

## Parsed dialogue sections keyed by section name (e.g. "day1").
var sections : Dictionary = {}

## Story flags that track which story events/choices have been made.
## Set via #set_flag flag_name in dialogue files.
## Checked via #require_flag flag_name ... #end_require for conditional dialogue.
## Example: { "met_basilio": true, "asked_about_crispin": true }
var story_flags : Dictionary = {}
