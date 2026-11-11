extends Node
## Debug: straight into the game as Martin, without the intro, the menu and the character
## choice, with the stutter meter on (frame_meter.gd), to measure quickly. Run
## scenes/snel_starten.tscn (F6 in the editor), or start the game with `-- --snel`
## (scripts/ui/intro.gd hands over to this scene then).

const CITY_SCENE := "res://scenes/stad.tscn"
const CHARACTER := "martin"
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const FrameMeter = preload("res://scripts/debug/frame_meter.gd")


func _ready() -> void:
	PlayerCharacter.choose(CHARACTER)
	# the meter on the root, so it stays when the scene changes (it finds the town itself)
	var meter := FrameMeter.new()
	meter.name = "Hapermeter"
	get_tree().root.add_child.call_deferred(meter)
	get_tree().change_scene_to_file.call_deferred(CITY_SCENE)
