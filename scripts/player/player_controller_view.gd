extends Node
## What the player looks and sounds like in the town (graphics; docs/CODE_LAGEN.md): the
## figure (PlayerModel, the node "Figuur"), the soft light over it by night ("Nachtlicht",
## night_glow.gd) and the patch on the ground under it (GroundShadow), which it builds as
## children of the player itself (build), so they move with it; the poses and the moves of
## the figure (asleep, getting up, sinking, falling dead, lying on the knocked down body,
## standing up), the sounds (the jump, the splash, the thud, the cries), the splash and the
## shards, and the numbers that rise over it in the HUD. It is the child "Beeld" of
## player_controller.gd, shows what that hands it (show_..., play_...) and decides nothing;
## its sizes come from player_controller_layout.gd.
##   const PlayerControllerView = preload("res://scripts/player/player_controller_view.gd")

const PlayerModel = preload("res://scripts/player/player_model.gd")
const NightGlow = preload("res://scripts/player/night_glow.gd")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")
const WaterSplash = preload("res://scripts/effects/water_splash.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const Items = preload("res://scripts/player/items.gd")
const Layout = preload("res://scripts/player/player_controller_layout.gd")
const FIGURE_NAME := "Figuur"
const NIGHT_LIGHT_NAME := "Nachtlicht"
## The sounds (RuimtelijkGeluid, events: right by you): the thud of a body hit, the splash
## into the water, the blip of a jump, the kick out of a door; the chime of an item (UiSounds).
const SOUND_PLAYER := "/root/RuimtelijkGeluid"
const BODY_HIT_SOUND := "lichaam_klap"
const SPLASH_SOUND := "plons"
const JUMP_SOUND := "springen"
const KICK_SOUND := "schop"
const ITEM_SOUND := "item"
const ITEM_SOUND_SOFTER_DB := -3.0
## The colours of "+50 XP", of the health lost, of "Zakken vol", and of the shards when the
## player is hit (cloth and dirt); the sizes of the letters of what rises.
const XP_TEXT_COLOUR := Color("#47D6C2")
const DAMAGE_COLOUR := Color("#FF4D5E")
const FULL_COLOUR := Color("#FF5D73")
const HIT_SHARD_COLOUR := Color("#6B5844")
const XP_FONT_SIZE := 18
const DAMAGE_FONT_SIZE := 18
const FULL_FONT_SIZE := 14
const ITEM_FONT_SIZE := 15
## Seconds the fall backwards of the dying figure takes; the most it tilts while sinking (degrees).
const FALL_SECONDS := 0.45

## The figure; null until build.
var figure: PlayerModel


func _init() -> void:
	name = "Beeld"


## Builds the figure of `archetype_id` (with or without a coat), the night light and the
## ground shadow as children of `host` (the player).
func build(host: Node3D, archetype_id: String, wears_coat: bool) -> void:
	figure = PlayerModel.new()
	figure.name = FIGURE_NAME
	figure.archetype_id = archetype_id
	figure.simple = true   # seen from afar in the town: fewer details
	figure.xray = false    # (the see-through shape did not work well: the rim instead, show_rim)
	figure.figure_scale = Layout.FIGURE_SCALE
	figure.coat = wears_coat   # everyone starts in a T-shirt, until given a coat
	host.add_child(figure)
	# a soft light over the figure in the dark, so it can be made out (night_glow.gd)
	var night_light := OmniLight3D.new()
	night_light.name = NIGHT_LIGHT_NAME
	night_light.set_script(NightGlow)
	host.add_child(night_light)
	# a soft patch on the ground under it, so it stands apart from the street (ground_shadow.gd)
	host.add_child(GroundShadow.new())


## The box round all meshes of `model`, in its own space (feet at y = 0, facing +z);
## Layout.DEFAULT_FIGURE_BOX for one without meshes.
static func outer_box(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var to_figure := model.global_transform.affine_inverse()
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box := (to_figure * mesh_instance.global_transform) * mesh_instance.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return Layout.figure_box(bounds, not first)


## The box round the figure as it stands now (outer_box of it).
func figure_bounds() -> AABB:
	return outer_box(figure)


# ------------------------------------------------------------------ the figure

func show_coat(on: bool) -> void:
	if figure:
		figure.coat = on


## The rim round the figure where something hides it from the camera (PlayerModel.rim).
func show_rim(on: bool) -> void:
	if figure:
		figure.rim = on


## The figure there or not (blinking after a blow).
func show_figure(on: bool) -> void:
	figure.visible = on


## The figure `offset` metres above (or below) the player's feet: gliding after a step.
func show_glide(offset: float) -> void:
	figure.position.y = offset


## How hard the figure walks (PlayerModel.walking), and what it shows now.
func show_walking(amount: float) -> void:
	figure.walking = amount


func walking_shown() -> float:
	return figure.walking


## Standing still without its idle movement (dying, drowning, knocked down, asleep).
func show_still() -> void:
	figure.walking = 0.0
	figure.idle = false


## A pose (limb -> degrees, PlayerPoseRules): every limb in it is set.
func show_pose(pose: Dictionary) -> void:
	for limb: String in pose:
		figure.pose_limb(limb, pose[limb])


## Lying on its back (face up, head towards -z) at `lying_position` in the player's space.
func show_asleep(lying_position: Vector3) -> void:
	show_still()
	figure.rotation_degrees.x = -90.0
	figure.position = lying_position


## Gets up from lying asleep in `seconds`: sits up and stands. The tween is handed back, so
## the behaviour can turn the player with it and hear when it stands.
func play_getting_up(seconds: float) -> Tween:
	var rise := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(figure, "rotation_degrees:x", 0.0, seconds)
	rise.parallel().tween_property(figure, "position", Vector3.ZERO, seconds)
	return rise


## Standing again with its idle movement.
func show_standing() -> void:
	figure.idle = true


## Sinks to `depth` (the figure's own y) in `seconds`, tilting `tilt_degrees` sideways. The
## tween is handed back, so the behaviour hears when it is under.
func play_sinking(depth: float, tilt_degrees: float, seconds: float) -> Tween:
	var down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	down.tween_property(figure, "position:y", depth, seconds)
	down.parallel().tween_property(figure, "rotation_degrees:z", tilt_degrees, seconds)
	return down


## Falls over backwards where it stands (dead), coming `lift` metres up onto its back.
func play_falling_dead(lift: float) -> void:
	var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(figure, "rotation_degrees:x", -90.0, FALL_SECONDS)
	fall.parallel().tween_property(figure, "position:y", figure.position.y + lift, FALL_SECONDS)


## The figure goes with the knocked down `body` (it tumbles with it); in a `dive` it lies
## along the body from the start (head first, flat).
func show_on_body(body: Node3D, dive: bool) -> void:
	show_still()
	figure.position = Vector3.ZERO
	figure.reparent(body, not dive)
	if dive:
		figure.transform = Transform3D.IDENTITY


## The figure back on `host` (the player), standing straight, still.
func show_back_on(host: Node3D) -> void:
	figure.reparent(host, false)
	figure.transform = Transform3D.IDENTITY
	figure.idle = false
	figure.walking = 0.0


## How the figure lies in the world now (to stand up from: play_standing_up).
func lying_pose() -> Transform3D:
	return figure.global_transform


## Back on `host` and up again from how it lay (`lying`, in the world) in `seconds`: the
## figure turns and rises to standing (not in one frame), then idles again.
func play_standing_up(host: Node3D, lying: Transform3D, seconds: float) -> void:
	figure.reparent(host, false)
	figure.global_transform = lying
	var from := figure.transform
	figure.idle = false
	var rise := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_method(func(share: float) -> void: figure.transform = from.interpolate_with(Transform3D.IDENTITY, share),
			0.0, 1.0, seconds)
	rise.tween_callback(func() -> void:
		figure.transform = Transform3D.IDENTITY
		figure.idle = true)


# ------------------------------------------------------------------ sounds and effects

## Whether there is something to sound through (the game's RuimtelijkGeluid).
func has_sound() -> bool:
	return _sound_player() != null


func play_jump(at: Vector3) -> void:
	_play_event(at, JUMP_SOUND)


func play_splash(at: Vector3) -> void:
	_play_event(at, SPLASH_SOUND)


## The thud of a body hit.
func play_thud(at: Vector3) -> void:
	_play_event(at, BODY_HIT_SOUND)


## The kick out of a door.
func play_kick(at: Vector3) -> void:
	_play_event(at, KICK_SOUND)


## A cry, a groan (`voice_sound`: PlayerHitRules.cry_name and the like).
func play_voice(at: Vector3, voice_sound: String) -> void:
	_play_event(at, voice_sound)


## The chime of something got.
func play_item_chime() -> void:
	UiSounds.play(self, ITEM_SOUND, ITEM_SOUND_SOFTER_DB)


## The splash and the bubbles (for `bubble_seconds`) at `at`, under `world`.
func show_splash(world: Node, at: Vector3, bubble_seconds: float) -> void:
	var splash := WaterSplash.new()
	splash.bubble_seconds = bubble_seconds
	world.add_child(splash)
	splash.global_position = at


## The burst of shards and dust of a hit of `strength` at `at`, under `world`.
func show_hit_burst(world: Node, at: Vector3, strength: float) -> void:
	CrashBurst.spawn(world, at, HIT_SHARD_COLOUR, strength)


# ------------------------------------------------------------------ what rises over it (the HUD)

func show_xp_gain(hud: Node, at: Vector3, text: String) -> void:
	_float(hud, at, text, XP_TEXT_COLOUR, XP_FONT_SIZE)


func show_damage(hud: Node, at: Vector3, text: String) -> void:
	_float(hud, at, text, DAMAGE_COLOUR, DAMAGE_FONT_SIZE)


func show_pockets_full(hud: Node, at: Vector3, text: String) -> void:
	_float(hud, at, text, FULL_COLOUR, FULL_FONT_SIZE)


## Something got, in the colour of its rarity (over the story box too).
func show_item_got(hud: Node, at: Vector3, text: String, item_id: String) -> void:
	_float(hud, at, text, Items.rarity_colour(item_id), ITEM_FONT_SIZE, true)


func _float(hud: Node, at: Vector3, text: String, colour: Color, font_size: int, over_story := false) -> void:
	if hud == null or not hud.has_method("show_floating_number"):
		return
	if over_story:
		hud.show_floating_number(at, text, colour, font_size, true)
	else:
		hud.show_floating_number(at, text, colour, font_size)


func _sound_player() -> Node:
	return get_node_or_null(SOUND_PLAYER) if is_inside_tree() else null


func _play_event(at: Vector3, sound_name: String) -> void:
	var audio := _sound_player()
	if audio and audio.has_method("play_event"):
		audio.play_event(at, sound_name)
