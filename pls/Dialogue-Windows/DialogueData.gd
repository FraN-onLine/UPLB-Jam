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
