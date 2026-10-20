extends Node
## Automatic tour (the "Rondleiding" node of the world scene): a continuously moving demo.
## It first shows how the shaders work (tour_data.gd SHADERS: each effect off, then on),
## then flies over every area and kind of housing without ever standing still: the iso
## camera glides from area to area, pushing in and out (far away and close up), with low
## flights through the canal and the streets in between (tour_data.gd FLIGHTS), and starts
## over after the last shot. Meanwhile the day goes by, from morning to night.
##
## Every shot (tour_data.gd shots()) has a camera path; the camera follows it each frame,
## and at the start of a shot it blends from where it was in BLEND seconds, so the
## movement never stops. A caption shows the title and explanation of the shot.
##
## The map is stored in parts (scripts/world_parts.gd) and the tour scene holds none of
## them: the tour shows one part at a time, plays the shots in that part, then loads the
## next part (behind DetailNiveau's loading screen), so only one part is ever in memory.
## `part` limits the tour to a single part.
##
## It takes over the camera (disables free_camera.gd's processing). Turn off `active` to
## look around yourself with the free camera (in part `part`, or the first part).

const Data = preload("res://scripts/tour_data.gd")
const Iso = preload("res://scripts/iso_camera.gd")
const Caption = preload("res://scripts/caption.gd")
const WorldParts = preload("res://scripts/world_parts.gd")
## Seconds to blend from the previous shot into the next.
const BLEND := 1.6
## Field of view (degrees) and near plane of the low flights.
const FLY_FOV := 55.0
const FLY_NEAR := 0.2
## How far (metres) a flight looks ahead, and how much it looks down on the way.
const LOOK_AHEAD := 30.0
const LOOK_DOWN := 0.28

## Run the tour; off = free camera.
@export var active := true
## Only the highlights (tour_data.gd HIGHLIGHTS) instead of every area of the map.
@export var highlights_only := false
## Map part to show (scripts/world_parts.gd): 0 = all parts one after the other,
## n = only part n.
@export var part := 0
@export var camera_path := NodePath("../Camera")
@export var day_cycle_path := NodePath("../Dagcyclus")
## Hours the clock runs during one round of the tour, from `day_start`: so the day goes
## from morning into the night towards the end.
@export var day_start := 8.0
@export var day_hours := 15.0
## Speed factor on all shots (2 = twice as fast).
@export var speed := 1.0
## The tour starts at the first shot whose slug contains this (empty = at the beginning).
@export var start_at := ""

var _cam: Camera3D
var _root: Node
var _day: Node
var _caption: Caption
## Map part currently shown (0 = none yet, or a map without parts).
var _shown := 0
## Shots in tour order, grouped per map part; each has a "part" key (0 = no parts).
var _shots := []
## Index of the current shot (keeps counting up, use % _shots.size()) and its time.
var _i := 0
var _time := 0.0
## Camera pose at the start of the current shot: [Transform3D, fov, near].
var _from: Array = []
## Seconds of one round (for the clock) and the time played in this round.
var _round := 1.0
var _played := 0.0
## Busy loading a map part: the camera waits.
var _loading := false
## The "aan" title of a shader shot is shown.
var _effects_on := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_root = owner if owner else get_parent()
	if not active:
		set_process(false)
		# free camera: show one part (unless a tool loaded one already)
		if WorldParts.part_count(_root) > 0 and not _root.has_node("Grond"):
			await get_tree().process_frame
			WorldParts.show_part(_root, clampi(part, 1, WorldParts.part_count(_root)))
		return
	_cam = get_node_or_null(camera_path)
	if _cam == null:
		set_process(false)
		return
	# the free camera must not fight the tour over the camera
	_cam.set_process(false)
	_cam.set_process_unhandled_input(false)
	_shown = WorldParts.shown_part(_root)   # a tool may have loaded one already
	var shots := Data.shots(_root)
	if highlights_only:
		var keep: Array = Data.HIGHLIGHTS
		shots = shots.filter(func(s): return s["slug"] in keep or s.has("toggle") or s["kind"] == "fly")
	_shots = _by_part(shots)
	_day = get_node_or_null(day_cycle_path)
	_caption = Caption.new(self, true)
	_caption.panel.modulate.a = 0.0
	if _shots.is_empty():
		set_process(false)
		return
	_round = 0.0
	for s in _shots:
		_round += s["seconds"]
	if start_at != "":
		for k in _shots.size():
			if start_at in str(_shots[k]["slug"]):
				_i = k
				break
	_from = _pose(_shots[_i], 0.0)
	_apply(_from)
	set_process(false)
	# loading a part has to wait until the scene has finished setting up
	await get_tree().process_frame
	await _start_shot()
	set_process(true)


## The shots of the parts to show (all, or only `part`), each with its "part", ordered
## by part and within a part in tour order.
func _by_part(shots: Array) -> Array:
	var count := WorldParts.part_count(_root)
	if count == 0:
		for s in shots:
			s["part"] = 0
		return shots
	var list := []
	for p in range(1, count + 1):
		if part > 0 and p != part:
			continue
		for s in shots:
			if WorldParts.part_at(_root, s["z"]) == p:
				s["part"] = p
				list.append(s)
	return list


## Starts shot _i: loads its map part if needed (the camera jumps there, behind the
## loading screen), shows its caption and switches the effects of a shader shot off.
func _start_shot() -> void:
	var s: Dictionary = _shots[_i % _shots.size()]
	_time = 0.0
	if s["part"] != _shown:
		_loading = true
		_from = _pose(s, 0.0)
		_apply(_from)
		await _show_part(s["part"])
		_loading = false
	_effects_on = false
	if s.has("toggle"):
		_effects(s, false)
	_caption.show_stop(s)
	if s.has("toggle"):
		_caption.title.text = "%s · uit" % s["title"]
	_caption.counter.text = "%d / %d" % [(_i % _shots.size()) + 1, _shots.size()]
	if s["part"] > 0:
		_caption.counter.text += " · deel %d van %d" % [s["part"], WorldParts.part_count(_root)]
	var t := create_tween()
	t.tween_property(_caption.panel, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	if _loading or _shots.is_empty():
		return
	var s: Dictionary = _shots[_i % _shots.size()]
	var dt := delta * speed
	_time += dt
	_played += dt
	var seconds: float = s["seconds"]
	var t := clampf(_time / seconds, 0.0, 1.0)
	var pose := _pose(s, t)
	var blend := smoothstep(0.0, 1.0, _time / BLEND)
	if blend < 1.0:
		pose = _mix(_from, pose, blend)
	_apply(pose)
	if s.has("toggle") and not _effects_on and t >= 0.5:
		_effects_on = true
		_effects(s, true)
	# the clock: from day_start over day_hours per round
	if _day:
		_day.set_time(day_start + day_hours * fposmod(_played / maxf(_round, 0.001), 1.0))
	# the caption fades out shortly before the shot ends
	if _time > seconds - 0.4 and _caption.panel.modulate.a > 0.99:
		create_tween().tween_property(_caption.panel, "modulate:a", 0.0, 0.35)
	if _time >= seconds:
		if s.has("toggle"):
			_effects(s, true)
		_from = _pose(s, 1.0)
		_i += 1
		if _i % _shots.size() == 0:
			_played = 0.0
		_start_shot()


## Camera pose [Transform3D, fov, near] of shot `s` at t (0..1).
func _pose(s: Dictionary, t: float) -> Array:
	if s["kind"] == "fly":
		var from: Vector3 = s["from"]
		var to: Vector3 = s["to"]
		var pos := from.lerp(to, t)
		var dir := (to - from).normalized()
		var look := pos + dir * LOOK_AHEAD + Vector3.DOWN * LOOK_AHEAD * LOOK_DOWN
		return [Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos), FLY_FOV, FLY_NEAR]
	var e := smoothstep(0.0, 1.0, t) * 0.3 + t * 0.7   # glide, a little eased
	var focus: Vector3 = (s["a"] as Vector3).lerp(s["b"], e)
	var size: float = lerpf(s["size_a"], s["size_b"], e)
	var basis := Basis.from_euler(Iso.ROTATION * (PI / 180.0))
	return [Transform3D(basis, Iso.position(focus, size)), Iso.FOV, 2.0]


## Pose between a and b (0..1): position and fov linear, rotation slerped.
func _mix(a: Array, b: Array, k: float) -> Array:
	var ta: Transform3D = a[0]
	var tb: Transform3D = b[0]
	var q := ta.basis.get_rotation_quaternion().slerp(tb.basis.get_rotation_quaternion(), k)
	return [Transform3D(Basis(q), ta.origin.lerp(tb.origin, k)), lerpf(a[1], b[1], k), minf(a[2], b[2])]


## Puts the camera in pose [Transform3D, fov, near]. A low pose (the flights) gets no
## tilt-shift blur close by, only a little far away (DetailNiveau scales the iso one).
func _apply(pose: Array) -> void:
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.global_transform = pose[0]
	_cam.fov = pose[1]
	_cam.near = pose[2]
	var low: bool = pose[1] > Iso.FOV + 1.0
	var dn := get_node_or_null("../DetailNiveau")
	if dn:
		dn.set("depth_of_field", not low)
	var attr := _cam.attributes as CameraAttributesPractical
	if attr:
		attr.dof_blur_near_enabled = not low
		if low:
			attr.dof_blur_far_distance = 70.0
			attr.dof_blur_far_transition = 90.0


## Shows map part `p` (unless it is shown already) and waits until DetailNiveau has
## merged it (scripts/level_of_detail.gd), behind its loading screen. Await it.
func _show_part(p: int) -> void:
	var dn := get_node_or_null("../DetailNiveau")
	if p > 0 and p != _shown:
		_shown = p
		if dn:
			dn.set("loading_text", "Deel %d van %d laden…" % [p, WorldParts.part_count(_root)])
		WorldParts.show_part(_root, p)
	if dn and dn.has_method("is_merging") and dn.is_merging():
		await dn.merge_finished


## Switches the shader globals of a shader shot (tour_data.gd SHADERS) off, or back to
## their project setting, and says so in the title.
func _effects(s: Dictionary, on: bool) -> void:
	for g in s["toggle"]:
		if str(g).begins_with("node:"):
			# a node of the tour scene (e.g. the grass blades) with an "enabled" switch
			var n := _root.get_node_or_null(NodePath(str(g).trim_prefix("node:")))
			if n:
				n.set("enabled", on)
			continue
		var setting = ProjectSettings.get_setting("shader_globals/" + g, {})
		var value: float = setting.get("value", 1.0) if setting is Dictionary else 1.0
		RenderingServer.global_shader_parameter_set(g, value if on else 0.0)
	if _caption:
		_caption.title.text = "%s · %s" % [s["title"], "aan" if on else "uit"]
