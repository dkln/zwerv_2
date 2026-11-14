extends Control
## A speech balloon: a short spoken line or a shout of someone, over their head, typed out
## like the story box (Typewriter: word by word), but without its cursor and silent: the
## shout itself is what you hear, the words come without blips.
## It pops up, types, holds `hold` seconds once it is all there, then fades; `finished`
## fires when it is gone.
## Where: the node's position is the tip of the tail (the balloon stands above it).
## - In the UI (the character creation screen): set `position` yourself.
## - In the world (shouts on the street): follow(node, camera) keeps the tip over a Node3D
##   (`head_height` m above its origin), hidden while that point is behind the camera; put
##   the balloon on a CanvasLayer (the HUD).
## Behaviour (docs/CODE_LAGEN.md): it keeps the line under way, the hold and whom it
## follows; its picture is speech_balloon_view.gd, its sizes speech_balloon_layout.gd.
##   const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
##   var balloon := SpeechBalloon.new()
##   hud_layer.add_child(balloon)
##   balloon.follow(passer_by, camera)
##   balloon.say("Hé, zwerver!")

signal finished

const SpeechBalloonLayout = preload("res://scripts/ui/widgets/speech_balloon_layout.gd")
const SpeechBalloonView = preload("res://scripts/ui/widgets/speech_balloon_view.gd")
const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")

## Seconds a line stays once it is all there when nothing else is asked, the pop and the fade.
const HOLD_SECONDS := 1.6
const POP_SECONDS := 0.14
const FADE_SECONDS := 0.3
## Metres over the origin of the one it follows the tip of the tail stands.
const HEAD_HEIGHT := 2.4

## The colour of the border and the tail (whose balloon it is).
var accent: Color
var head_height := HEAD_HEIGHT
## Its picture.
var view: SpeechBalloonView

var _typewriter: Typewriter
var _hold_left := 0.0
var _hold := HOLD_SECONDS
var _fading := false
var _follow_node: Node3D
var _camera: Camera3D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# also while the game stands still (a conversation: someone of the place warns you while
	# you talk): else its pop, its place over the speaker and its typing stop halfway
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = SpeechBalloonView.new()
	add_child(view)
	accent = view.accent()
	_typewriter = Typewriter.new(view.text_label(), self)
	# the shout itself is heard; the words come silently and without a cursor
	_typewriter.sound = false
	_typewriter.show_cursor = false


## Types `line` out and keeps it `hold` seconds once it is all there; a new line replaces the
## one under way.
func say(line: String, hold := HOLD_SECONDS) -> void:
	_hold = hold
	_hold_left = hold
	_fading = false
	view.show_line(line, accent)
	_typewriter.start(line)
	view.settle()
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE * SpeechBalloonLayout.POP_FROM
	pivot_offset = Vector2.ZERO
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, POP_SECONDS)
	_place()


## Keeps the balloon over `node` (head_height m up), seen through `camera`.
func follow(node: Node3D, camera: Camera3D) -> void:
	_follow_node = node
	_camera = camera


func is_talking() -> bool:
	return visible and not _fading


func _process(delta: float) -> void:
	if not visible:
		return
	_typewriter.update(delta)
	_place()
	if _fading:
		return
	if _typewriter.is_done():
		_hold_left -= delta
		if _hold_left <= 0.0:
			_fading = true
			var fade := create_tween()
			fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
			fade.tween_callback(func() -> void:
				visible = false
				finished.emit())


## The panel above the tip, in the middle; in the world the tip over the followed node.
func _place() -> void:
	if _follow_node and _camera:
		if not is_instance_valid(_follow_node):
			_follow_node = null
			visible = false
			return
		var head := _follow_node.global_position + Vector3.UP * head_height
		if _camera.is_position_behind(head):
			modulate.a = 0.0
			return
		position = _camera.unproject_position(head).round()
	view.place_panel()
