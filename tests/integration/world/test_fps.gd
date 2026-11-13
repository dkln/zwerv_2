extends SceneTree
## Measures the frame rate of the city (vsync off, 1920x1080), after an 8 s
## warm-up, and prints the average FPS, the 1% low and draw calls/primitives. A measurement
## in a window on the clock, not a suite of tests/run_integration_tests.gd (that one runs
## headless with a fixed time step and has nothing to measure): it judges nothing and is
## started by hand, on its own.
## usage: tools/godot.sh --script tests/integration/world/test_fps.gd -- <seconds> <zoom|speler> [focus_x focus_z] [flags]
## "speler" = the game's own view (the camera following the player, standing still); a
## number = fixed iso view size (metres in view) with the free camera, optionally around
## focus_x/focus_z (world metres).
## flags (letters, combine freely): s = no shadows and no day cycle, o4/o8 = GridMap
## octant size, p = no Props, g = no Gebouwen, e = no SSAO/SSIL/glow, w = no SSR,
## 2 = two shadow splits, 1 = orthogonal shadows, d = no DetailNiveau (no LOD/merging).

const Common = preload("res://tools/tool_common.gd")
## Seconds at the start that are not measured (shader compilation, LOD copies).
const WARM_UP := 8.0

var _elapsed := 0.0
var _frames := 0
var _samples := []
var _duration := 20.0


func _init() -> void:
	Common.watchdog(self, Common.arg_float(0, 20.0) + 300.0)
	_duration = Common.arg_float(0, 20.0)
	var mode := Common.arg(1, "speler")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Common.render_size(self, Vector2i(1920, 1080))
	var scene := Common.instantiate(Common.CITY, false)
	if mode != "speler":
		scene.get_node("Volgcamera").free()
		var camera: Camera3D = scene.get_node("Camera")
		camera.set("iso_size", float(mode))
		if Common.arg_count() > 3:
			# free_camera.gd re-centres on the ground point it looks at in _ready
			var focus := Vector3(Common.arg_float(2), 0, Common.arg_float(3))
			camera.position = focus + Common.Iso.DIRECTION * 300.0
	_apply_flags(scene, Common.arg(4))
	get_root().add_child(scene)


## Applies the benchmark flags (see the header) to the not yet added scene `scene`.
## Nodes are removed at once (not queue_free): a queued node still gets added and runs
## a frame, so the day cycle would switch the shadows back on and DetailNiveau would
## set up a freed layer.
func _apply_flags(scene: Node, flags: String) -> void:
	if "s" in flags:
		scene.get_node("Zon").shadow_enabled = false
		_remove(scene, "Dagcyclus")
	for octant_size: int in [4, 8]:
		if ("o%d" % octant_size) in flags:
			for layer_name: String in Common.LAYERS:
				scene.get_node(layer_name).cell_octant_size = octant_size
	if "p" in flags:
		_remove(scene, "Props")
	if "g" in flags:
		_remove(scene, "Gebouwen")
	if "e" in flags:
		var environment: Environment = scene.get_node("Omgeving").environment
		environment.ssao_enabled = false
		environment.ssil_enabled = false
		environment.glow_enabled = false
	if "w" in flags:
		scene.get_node("Omgeving").environment.ssr_enabled = false
	if "2" in flags:
		scene.get_node("Zon").directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if "1" in flags:
		scene.get_node("Zon").directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	if "d" in flags:
		_remove(scene, "DetailNiveau")


## Frees the child `node_name` of `scene` immediately, if it is there.
func _remove(scene: Node, node_name: String) -> void:
	var node := scene.get_node_or_null(node_name)
	if node:
		scene.remove_child(node)
		node.free()


## Collects frame times after the warm-up and prints the result after `_duration` seconds.
func _process(delta: float) -> bool:
	if _frames == 0 and _elapsed == 0.0 and delta > 1.0:
		return false   # first frame after loading/merging does not count
	_elapsed += delta
	if _elapsed < WARM_UP:
		return false   # warm-up: compile shaders, create LOD copies
	_frames += 1
	_samples.append(delta)
	if _elapsed > _duration + WARM_UP:
		_samples.sort()
		var average := 0.0
		for frame_time: float in _samples:
			average += frame_time
		average /= _samples.size()
		var slowest_percent: float = _samples[int(_samples.size() * 0.99)]
		print("FPS average %.1f, 1%% low %.1f  | draw calls %d, primitives %d" % [1.0 / average, 1.0 / slowest_percent,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		quit()
	return false
