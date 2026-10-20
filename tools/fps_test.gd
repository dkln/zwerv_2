extends SceneTree
## Measures the frame rate of the example map (vsync off, 1920x1080), after an 8 s
## warm-up, and prints the average FPS, the 1% low and draw calls/primitives.
## usage: Godot --script tools/fps_test.gd -- <seconds> <zoom|tour> [focus_x focus_z] [flags]
## "tour" = run the automatic tour; a number = fixed iso view size (metres in
## view) with the free camera, optionally around focus_x/focus_z (world metres), in the
## map part around the focus (default: the first part, where the tour opens; the tour
## then loads the other parts itself).
## flags (letters, combine freely): s = no shadows and no day cycle, o4/o8 = GridMap
## octant size, p = no Props, g = no Gebouwen, e = no SSAO/SSIL/glow, w = no SSR,
## 2 = two shadow splits, 1 = orthogonal shadows, d = no DetailNiveau (no LOD/merging).

const Common = preload("res://tools/tool_common.gd")
## Seconds at the start that are not measured (shader compilation, LOD copies).
const WARM_UP := 8.0

var _t := 0.0
var _frames := 0
var _samples := []
var _duration := 20.0


func _init() -> void:
	Common.watchdog(self, Common.arg_float(0, 20.0) + 300.0)
	_duration = Common.arg_float(0, 20.0)
	var mode := Common.arg(1, "tour")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Common.render_size(self, Vector2i(1920, 1080))
	var sc := Common.instantiate(Common.WORLD, false)
	if mode != "tour":
		sc.get_node("Rondleiding").set("active", false)
		var cam: Camera3D = sc.get_node("Camera")
		cam.set("iso_size", float(mode))
		if Common.arg_count() > 3:
			# free_camera.gd re-centres on the ground point it looks at in _ready
			var focus := Vector3(Common.arg_float(2), 0, Common.arg_float(3))
			cam.position = focus + Common.Iso.DIRECTION * 300.0
			Common.load_part_at(sc, focus.z)
	if not sc.has_node("Grond"):
		Common.load_part_at(sc, 0.0)   # the first part (also where the tour opens)
	_apply_flags(sc, Common.arg(4))
	get_root().add_child(sc)


## Applies the benchmark flags (see the header) to the not yet added scene `sc`.
## Nodes are removed at once (not queue_free): a queued node still gets added and runs
## a frame, so the day cycle would switch the shadows back on and DetailNiveau would
## set up a freed layer.
func _apply_flags(sc: Node, flags: String) -> void:
	if "s" in flags:
		sc.get_node("Zon").shadow_enabled = false
		_remove(sc, "Dagcyclus")
	for o in [4, 8]:
		if ("o%d" % o) in flags:
			for n in Common.LAYERS:
				sc.get_node(n).cell_octant_size = o
	if "p" in flags:
		_remove(sc, "Props")
	if "g" in flags:
		_remove(sc, "Gebouwen")
	if "e" in flags:
		var env: Environment = sc.get_node("Omgeving").environment
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
	if "w" in flags:
		sc.get_node("Omgeving").environment.ssr_enabled = false
	if "2" in flags:
		sc.get_node("Zon").directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if "1" in flags:
		sc.get_node("Zon").directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	if "d" in flags:
		_remove(sc, "DetailNiveau")


## Frees the child `node_name` of `sc` immediately, if it is there.
func _remove(sc: Node, node_name: String) -> void:
	var n := sc.get_node_or_null(node_name)
	if n:
		sc.remove_child(n)
		n.free()


## Collects frame times after the warm-up and prints the result after `_duration` seconds.
func _process(delta: float) -> bool:
	if _frames == 0 and _t == 0.0 and delta > 1.0:
		return false   # first frame after loading/merging does not count
	_t += delta
	if _t < WARM_UP:
		return false   # warm-up: compile shaders, create LOD copies
	_frames += 1
	_samples.append(delta)
	if _t > _duration + WARM_UP:
		_samples.sort()
		var avg := 0.0
		for d in _samples:
			avg += d
		avg /= _samples.size()
		var p99: float = _samples[int(_samples.size() * 0.99)]
		print("FPS average %.1f, 1%% low %.1f  | draw calls %d, primitives %d" % [1.0 / avg, 1.0 / p99,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		quit()
	return false
