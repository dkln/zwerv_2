extends SubViewportContainer
## A player figure (PlayerModel) in a little 3D picture of its own.
## `zoom` runs from the whole figure (0) to its face (1, the face height per archetype,
## PlayerModel.face_height); tween it to zoom in. `face_view` is how many metres the face
## framing shows (the HUD portrait a little wider than the creation screen). Pixels are
## kept hard (nearest filter, rendered at PIXEL_SCALE of the size and scaled up), as the
## rest of the pixel UI.
## `townsfolk_look` (a TownsfolkFigure look; empty: the player figure) shows a townsperson
## instead: someone in the street you talk to (the story box), framed the same way.
## `source_figure` (the TownsfolkFigure of that person in the world) makes the close-up live:
## every frame it takes the pose of that figure (its limbs and body: sitting, standing behind
## the counter, the moves of its mood while it talks, Emote) and breathes a little. A
## townsperson has a mouth and eyelids (TownsfolkFigure.add_face): while `speaking` the mouth
## follows the letters of `speech` (wide on a, o, u, half on e, i, y, a little on the other
## letters, shut on spaces and signs), shut when it is not speaking; now and then it blinks.
## play_gesture() makes the figure do its own move (PlayerModel.play_gesture); `gesture_cue`
## fires at the moment for its shout. `silhouette` (a colour with alpha) draws only its outline.
## Behaviour (docs/CODE_LAGEN.md): it keeps who is shown and the clocks of the mouth, the
## eyes and the breath; the mouth and the blinks are player_portrait_rules.gd, the framing
## player_portrait_layout.gd, the picture (world, light, figures) player_portrait_view.gd.
##   const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")

signal gesture_cue

const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerPortraitRules = preload("res://scripts/ui/widgets/player_portrait_rules.gd")
const PlayerPortraitLayout = preload("res://scripts/ui/widgets/player_portrait_layout.gd")
const PlayerPortraitView = preload("res://scripts/ui/widgets/player_portrait_view.gd")

var archetype_id := "jos":
	set(value):
		archetype_id = value
		if view:
			view.show_archetype(value)
			_frame()
## 0 = the whole figure, 1 = the face.
var zoom := 0.0:
	set(value):
		zoom = clampf(value, 0.0, 1.0)
		_frame()
var face_view := PlayerPortraitLayout.FACE_VIEW:
	set(value):
		face_view = value
		_frame()
## Degrees a second the figure turns; 0 turns it back to face the front.
var spin := 0.0:
	set(value):
		spin = value
		if view:
			view.show_spin(value)

## With alpha: the figure only as an outline in this colour (PlayerModel.silhouette).
var silhouette := PlayerPortraitView.NO_SILHOUETTE:
	set(value):
		silhouette = value
		if view:
			view.show_silhouette(value)

## How much the figure walks (0 = stands, 1 = walks on the spot); tween it.
var walking := 0.0:
	set(value):
		walking = value
		if view:
			view.show_walking(value)

var townsfolk_look := {}:
	set(value):
		townsfolk_look = value
		_show_townsfolk()
## The figure in the world the close-up follows (its pose), or null: standing still.
var source_figure: Node3D = null:
	set(value):
		source_figure = value
		_source_rest = value.transform if value else Transform3D.IDENTITY
## While true the mouth moves with `speech` (set by the story box and the shop screen as a
## line types out).
var speaking := false
var speech := "":
	set(value):
		speech = value
		_speech_clock = 0.0
## Its picture.
var view: PlayerPortraitView

var _source_rest := Transform3D.IDENTITY   # the source's transform when it came (its mood moves it from there)
var _speech_clock := 0.0
var _blink_clock := 0.0
var _next_blink := PlayerPortraitRules.FIRST_BLINK
var _breath_clock := 0.0


func _init() -> void:
	stretch = true
	stretch_shrink = PlayerPortraitLayout.shrink()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = PlayerPortraitView.new()
	view.show_player(archetype_id, spin)
	# in the game: as the player is dressed now (a T-shirt until a coat is given)
	var player := get_tree().get_first_node_in_group("speler") if is_inside_tree() else null
	if player and player.has_method("wears_coat"):
		view.show_coat(player.wears_coat())
	view.gesture_cue.connect(func() -> void: gesture_cue.emit())
	add_child(view)
	resized.connect(_frame)


func _ready() -> void:
	_frame()


## The townsperson shown in place of the player figure, or null.
func townsfolk_figure() -> TownsfolkFigure:
	return view.townsfolk()


## Where the top of the figure's head is in this picture (local pixels), for a speech balloon.
func head_point() -> Vector2:
	if view == null:
		return PlayerPortraitLayout.top_centre(size.x)
	return view.head_point() * float(stretch_shrink)


## The figure does its own move; `gesture_cue` fires at the moment for its shout.
func play_gesture() -> void:
	if view:
		view.play_gesture()


## The townsperson of `townsfolk_look` in place of the player figure (or back to it), as
## big as a player figure is here.
func _show_townsfolk() -> void:
	if view == null:
		return
	view.show_townsfolk(townsfolk_look)
	_frame()


func _process(delta: float) -> void:
	if view.townsfolk() == null or not is_visible_in_tree():
		return
	# the pose of the one in the world, its mood's moves (from where it stood), a breath
	_breath_clock += delta
	var moved := Transform3D.IDENTITY
	if is_instance_valid(source_figure):
		if source_figure is TownsfolkFigure:
			view.show_pose(source_figure as TownsfolkFigure)
		moved = _source_rest.affine_inverse() * source_figure.transform
	view.show_stance(PlayerPortraitLayout.breathing_scale(PlayerPortraitRules.breath(_breath_clock), view.townsfolk_scale()), moved)
	# the mouth with the letters, the eyes now and then shut
	view.show_mouth(_mouth_for(delta))
	_blink_clock += delta
	if PlayerPortraitRules.is_blinking(_blink_clock, _next_blink):
		view.show_blink(true)
		if PlayerPortraitRules.is_blink_over(_blink_clock, _next_blink):
			view.show_blink(false)
			_blink_clock = 0.0
			_next_blink = randf_range(PlayerPortraitRules.BLINK_EVERY.x, PlayerPortraitRules.BLINK_EVERY.y)


## How open the mouth is now: the letter of `speech` it is at while speaking, else shut.
func _mouth_for(delta: float) -> float:
	if not PlayerPortraitRules.is_talking(speaking, speech):
		_speech_clock = 0.0
		return PlayerPortraitRules.MOUTH_SHUT
	_speech_clock += delta
	return PlayerPortraitRules.mouth_at(speech, _speech_clock)


## The camera between the whole figure (a little from above) and the face (straight on),
## orthogonal, by `zoom` (eased).
func _frame() -> void:
	if view == null:
		return
	var face := PlayerModel.face_height(archetype_id) if view.townsfolk() == null else view.townsfolk_face()
	view.show_frame(PlayerPortraitLayout.camera_size(PlayerPortraitLayout.aspect(size), face_view, zoom),
			PlayerPortraitLayout.camera_eye(face, zoom), PlayerPortraitLayout.camera_target(face, zoom))
