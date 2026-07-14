extends RefCounted
class_name DialogueChoice

## Text shown on the button.
var text : String = ""

## Instructions played if selected.
var dialogue : Array[DialogueInstruction] = []

## Future use.
var condition : String = ""
var enabled : bool = true
