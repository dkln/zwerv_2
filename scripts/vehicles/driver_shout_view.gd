extends RefCounted
## What a shout in the street looks and sounds like (graphics; docs/CODE_LAGEN.md): the
## speech balloon over the speaker (SpeechBalloon, scripts/ui/widgets/speech_balloon.gd) on
## the CanvasLayer of the balloons (BALLOON_LAYER: under the HUD and its pause screen), the
## line typed in it and held HOLD_SECONDS, and the babble with it (Babble). It shows and
## plays what driver_shout.gd hands it and decides nothing.
##   const DriverShoutView = preload("res://scripts/vehicles/driver_shout_view.gd")

const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const Babble = preload("res://scripts/audio/babble.gd")

const HOLD_SECONDS := 2.2
const BALLOON_LAYER := 9
## The colour of a balloon in the street: the accent of the UI, as every balloon.
const DRIVER_ACCENT := UiStyle.ACCENT
const LAYER_NAME := "Toeterballonnen"
const BALLOON_NAME := "Toeterballon"


## A new layer for the balloons, under `parent`.
static func build_layer(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = BALLOON_LAYER
	parent.add_child(layer)
	return layer


## A new balloon on `layer` that stays `head_height` m over `speaker`, seen through
## `camera`; gone when it has faded and with the speaker.
static func build_balloon(layer: CanvasLayer, speaker: Node3D, camera: Camera3D, head_height: float) -> SpeechBalloon:
	var balloon := SpeechBalloon.new()
	balloon.name = BALLOON_NAME
	balloon.accent = DRIVER_ACCENT
	balloon.head_height = head_height
	layer.add_child(balloon)
	balloon.follow(speaker, camera)
	balloon.finished.connect(balloon.queue_free)
	# gone with the vehicle (the balloon would otherwise only hide itself)
	speaker.tree_exiting.connect(balloon.queue_free, CONNECT_ONE_SHOT)
	return balloon


## Types `line` in `balloon` and holds it HOLD_SECONDS.
static func show_line(balloon: SpeechBalloon, line: String) -> void:
	balloon.say(line, HOLD_SECONDS)


## The babble of `line` at `at` in the world, in `voice` and `babble_mood`.
static func play_babble(tree: SceneTree, at: Vector3, voice: String, babble_mood: String, line: String) -> void:
	Babble.play_at(tree, at, voice, babble_mood, line)
