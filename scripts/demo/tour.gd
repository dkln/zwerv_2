extends Node
## Automatic tour (the "Rondleiding" node of the world scene): a continuously moving demo.
## It opens with the day and night cycle (tour_data.gd DAY_NIGHT: one full day, from the
## afternoon through the night and the morning back to the afternoon), then shows how the shaders work (tour_data.gd SHADERS: each effect off, then on),
## then flies over every area and kind of housing without ever standing still: the iso
## camera glides from area to area, pushing in and out (far away and close up), with low
## flights through the canal and the streets in between (tour_data.gd FLIGHTS), and starts
## over after the last shot. Meanwhile the day goes on, from the afternoon into the evening.
##
## Every shot (tour_data.gd shots()) has a camera path; the camera follows it each frame,
## and at the start of a shot it blends from where it was in BLEND seconds, so the
## movement never stops. A caption shows the title and explanation of the shot.
##
## The map is stored in parts (scripts/world/world_parts.gd) and the tour scene holds none of
## them: the tour shows one part at a time, plays the shots in that part, then loads the
## next part (behind DetailNiveau's loading screen), so only one part is ever in memory.
## `part` limits the tour to a single part.
##
## Every part ends with the test figure (scripts/demo/walker.gd, node "Wandelaar") walking
## its routes over the bridges, tunnels, stairs, ... of that part: shots of kind "walk",
## with the camera following the figure; such a shot lasts until the figure arrives.
##
## Keys: right arrow = next shot, left arrow = previous shot, space = pause / play,
## V = follow the figure from behind or in the iso view.
##
## It takes over the camera (disables free_camera.gd's processing). Turn off `active` to
## look around yourself with the free camera (in part `part`, or the first part).

const Data = preload("res://scripts/demo/tour_data.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const Caption = preload("res://scripts/demo/caption.gd")
const WorldParts = preload("res://scripts/world/world_parts.gd")
## Seconds to blend from the previous shot into the next.
const BLEND := 1.6
## Field of view (degrees) and near plane of the low flights.
const FLY_FOV := 55.0
const FLY_NEAR := 0.2
## How far (metres) a flight looks ahead, and how much it looks down on the way.
const LOOK_AHEAD := 30.0
const LOOK_DOWN := 0.28
## Walk shots: the longest a shot waits for the figure (seconds), the camera behind and
## above the figure (metres), and the view size of the iso view (V).
const WALK_MAX := 120.0
## Expected length of a walk shot (seconds), for the clock (the real one is known later).
const WALK_ESTIMATE := 35.0
const CHASE_BACK := 4.5
const CHASE_UP := 2.2
const WALK_ISO_SIZE := 18.0
## Day and night demo: the clock as [fraction of the shot, hours after day_start], so
## the afternoon, sunset and sunrise take their time and the dark night goes quickly.
const DAY_KEYS := [[0.0, 0.0], [0.1, 1.0], [0.36, 5.0], [0.56, 15.0], [0.82, 19.5], [1.0, 24.0]]

## Run the tour; off = free camera.
@export var active := true
## Only the highlights (tour_data.gd HIGHLIGHTS) instead of every area of the map.
@export var highlights_only := false
## Map part to show (scripts/world/world_parts.gd): 0 = all parts one after the other,
## n = only part n.
@export var part := 0
@export var camera_path := NodePath("../Camera")
@export var day_cycle_path := NodePath("../Dagcyclus")
## The day and night demo starts and ends at `day_start`; the rest of the tour then runs
## the clock `day_hours` further per round, from the afternoon into the evening.
@export var day_start := 14.0
@export var day_hours := 6.0
## Speed factor on all shots (2 = twice as fast).
@export var speed := 1.0
## The tour starts at the first shot whose slug contains this (empty = at the beginning).
@export var start_at := ""
## Path to the test figure; its routes end every part ("" or missing = no walk shots).
@export var walker_path := NodePath("../Wandelaar")

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
## Seconds of one round (for the clock) and the time played in this round, both
## without the day and night demo (which runs its own clock).
var _round := 1.0
var _played := 0.0
## Busy loading a map part: the camera waits.
var _loading := false
## The "aan" title of a shader shot is shown.
var _effects_on := false
## Paused with the space bar: the time of the shot stands still.
var _paused := false
## Counter text of the current shot (without the pause note).
var _counter := ""
var _walker: Node
## Walk shots: camera position (smoothed) and the iso view instead of following (V).
var _chase := Vector3.INF
var _walk_iso := false


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
	_walker = get_node_or_null(walker_path)
	if _walker:
		_walker.set("auto", false)
	var shots := Data.shots(_root)
	if highlights_only:
		var keep: Array = Data.HIGHLIGHTS
		shots = shots.filter(func(s): return s["slug"] in keep or s.has("toggle") or s.has("day") or s["kind"] == "fly")
	_shots = _by_part(shots)
	_day = get_node_or_null(day_cycle_path)
	_caption = Caption.new(self, true)
	_caption.panel.modulate.a = 0.0
	if _shots.is_empty():
		set_process(false)
		return
	_round = 0.0
	for s in _shots:
		if not s.has("day"):
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
		if _walker:
			# the figure's routes are picked when the part is loaded; missing ones are skipped
			for k in _walker.route_slots():
				list.append({"slug": "wandelaar_%d_%d" % [p, k + 1], "title": "Wandelaar", "text": "",
					"kind": "walk", "route": k, "seconds": WALK_ESTIMATE, "part": p, "x": 0.0, "z": 0.0})
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
	if s["kind"] == "walk":
		await _start_walk(s)
	_caption.show_stop(s)
	if s.has("toggle"):
		_caption.title.text = "%s · uit" % s["title"]
	_counter = "%d / %d" % [(_i % _shots.size()) + 1, _shots.size()]
	if s["part"] > 0:
		_counter += " · deel %d van %d" % [s["part"], WorldParts.part_count(_root)]
	_show_counter()
	var t := create_tween()
	t.tween_property(_caption.panel, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	if _loading or _shots.is_empty():
		return
	var s: Dictionary = _shots[_i % _shots.size()]
	var dt := 0.0 if _paused else delta * speed
	_time += dt
	if not s.has("day"):
		_played += dt
	if s["kind"] == "walk" and _walker:
		_walker.set("paused", _paused)
		# the shot ends shortly after the figure has arrived
		if _walker.is_done() and s["seconds"] >= WALK_MAX:
			s["seconds"] = _time + 0.8
	var seconds: float = s["seconds"]
	var t := clampf(_time / seconds, 0.0, 1.0)
	var pose := _pose(s, t) if s["kind"] != "walk" else _walk_pose(delta)
	var blend := smoothstep(0.0, 1.0, _time / BLEND)
	if blend < 1.0:
		pose = _mix(_from, pose, blend)
	_apply(pose)
	if s.has("toggle") and not _effects_on and t >= 0.5:
		_effects_on = true
		_effects(s, true)
	# the clock: one full day in the day and night demo, else from day_start over
	# day_hours per round
	if s.has("day"):
		var hour := day_start + _day_hours(t)
		if _day:
			_day.set_time(hour)
		_caption.title.text = "%s · %s" % [s["title"], _clock_text(hour)]
	elif _day:
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


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_RIGHT:
			_jump(1)
		KEY_LEFT:
			_jump(-1)
		KEY_SPACE:
			_paused = not _paused
			_show_counter()
		KEY_V:
			_walk_iso = not _walk_iso
		_:
			return
	get_viewport().set_input_as_handled()


## Jumps `step` shots ahead (or back): the camera blends over from where it is now (or,
## when paused, goes straight to the start of the shot), and the clock follows.
func _jump(step: int) -> void:
	if _loading or _shots.is_empty() or not is_processing():
		return
	var s: Dictionary = _shots[_i % _shots.size()]
	if s.has("toggle"):
		_effects(s, true)
	if s["kind"] == "walk" and _walker:
		_walker.stop()
	_i = posmod(_i + step, _shots.size())
	_played = 0.0
	for k in _i:
		if not _shots[k].has("day"):
			_played += _shots[k]["seconds"]
	if _paused and _shots[_i]["kind"] != "walk":
		_from = _pose(_shots[_i], 0.0)
		_apply(_from)
	else:
		_from = [_cam.global_transform, _cam.fov, _cam.near]
	_start_shot()


func _show_counter() -> void:
	_caption.counter.text = _counter + (" · pauze" if _paused else "")


## Hours after day_start in the day and night demo at t (0..1), from DAY_KEYS (eased
## within each step, so the clock never jumps in speed).
func _day_hours(t: float) -> float:
	for k in range(1, DAY_KEYS.size()):
		var a: Array = DAY_KEYS[k - 1]
		var b: Array = DAY_KEYS[k]
		if t <= b[0] or k == DAY_KEYS.size() - 1:
			var f := clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return lerpf(a[1], b[1], lerpf(f, smoothstep(0.0, 1.0, f), 0.5))
	return 0.0


## "16:30 · middag": the time of `hour` (wrapped to 0..24) and the part of the day.
func _clock_text(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	var minutes := int(h * 60.0) / 10 * 10   # in steps of 10 minutes, so it reads calmly
	var part := "nacht"
	if h >= 6.0 and h < 12.0:
		part = "ochtend"
	elif h >= 12.0 and h < 18.0:
		part = "middag"
	elif h >= 18.0:
		part = "avond"
	return "%02d:%02d %s" % [minutes / 60, minutes % 60, part]


## Camera pose [Transform3D, fov, near] of shot `s` at t (0..1); for a walk shot (which
## follows the figure, _walk_pose) where the camera is now.
func _pose(s: Dictionary, t: float) -> Array:
	if s["kind"] == "walk":
		return [_cam.global_transform, _cam.fov, _cam.near]
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


## Starts walk shot `s`: the figure walks route s.route of the part, with its name and
## explanation in the caption. Without that route the shot is skipped (ends at once).
func _start_walk(s: Dictionary) -> void:
	s["seconds"] = WALK_MAX
	_chase = Vector3.INF
	if _walker and _walker.preparing:
		# the demo routes come after all navigation is baked: wait for them
		_loading = true
		await _walker.routes_ready
		_loading = false
	var info: Dictionary = _walker.route_info(s["route"]) if _walker else {}
	if info.is_empty() or not _walker.walk(s["route"]):
		s["seconds"] = 0.0
		s["title"] = "Wandelaar"
		s["text"] = ""
		return
	s["title"] = "Wandelaar: %s" % info["category"]
	s["text"] = info["text"]


## Camera pose of a walk shot: behind and above the figure, looking at it (smoothed), or
## the iso view around it (key V).
func _walk_pose(delta: float) -> Array:
	var body: Node3D = _walker.get("body")
	var feet := body.global_position
	if _walk_iso:
		var basis := Basis.from_euler(Iso.ROTATION * (PI / 180.0))
		return [Transform3D(basis, Iso.position(feet, WALK_ISO_SIZE)), Iso.FOV, 2.0]
	var facing: Vector3 = _walker.get("facing")
	var want := feet - facing * CHASE_BACK + Vector3.UP * CHASE_UP
	_chase = want if _chase == Vector3.INF else _chase.lerp(want, 1.0 - exp(-2.5 * delta))
	var look := feet + Vector3.UP * 1.2
	return [Transform3D(Basis.looking_at(look - _chase, Vector3.UP), _chase), FLY_FOV, 0.1]


## Pose between a and b (0..1): position and fov linear, rotation slerped.
func _mix(a: Array, b: Array, k: float) -> Array:
	var ta: Transform3D = a[0]
	var tb: Transform3D = b[0]
	var q := ta.basis.get_rotation_quaternion().slerp(tb.basis.get_rotation_quaternion(), k)
	return [Transform3D(Basis(q), ta.origin.lerp(tb.origin, k)), lerpf(a[1], b[1], k), minf(a[2], b[2])]


## Puts the camera in pose [Transform3D, fov, near].
func _apply(pose: Array) -> void:
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.global_transform = pose[0]
	_cam.fov = pose[1]
	_cam.near = pose[2]


## Shows map part `p` (unless it is shown already) and waits until DetailNiveau has
## merged it (scripts/world/level_of_detail.gd), behind its loading screen. Await it.
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
