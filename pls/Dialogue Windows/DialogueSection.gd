extends RefCounted
class_name DialogueSection

## Main dialogue
var dialogue : Array[DialogueInstruction] = []

## Dialogue after this section has already been completed
var exhausted_dialogue : Array[DialogueInstruction] = []

## Returned when dialogue finishes.
##
## Examples:
## gain_insight
## quest_finished
## shop
## cutscene_2
var return_key : String = ""