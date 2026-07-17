extends RefCounted
class_name DialogueSection

## Lines played the first time this section runs.
var dialogue : Array[DialogueInstruction] = []

## Lines played on repeat visits (after "when exhausted" in the file).
var exhausted_dialogue : Array[DialogueInstruction] = []

## Emitted through [DialogueWindow.dialogue_finished] after the exhausted block.
## Example: #gain_insight
var return_key : String = ""
