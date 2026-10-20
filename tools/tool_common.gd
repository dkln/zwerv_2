extends RefCounted
## Shared helpers for the command-line tools in tools/ (SceneTree scripts started with
## `Godot --script tools/<tool>.gd -- <args>`): argument parsing, loading a scene with a
## still camera, waiting frames and saving screenshots.

const Iso = preload("res://scripts/iso_camera.gd")
## The example map.
const WORLD := "res://scenes/wereld.tscn"
## The GridMap layers of the world scene (node names under the root).
const LAYERS := ["Grond", "Gebouwen", "Details", "Props"]


## Quits the tool after `seconds`, whatever happens: a script error stops a tool before
## its quit(), which would leave Godot running forever. Call it first in _init.
static func watchdog(tree: SceneTree, seconds := 600.0) -> void:
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		push_error("watchdog: tool still running after %d s, quitting" % seconds)
		tree.quit(1))


## User argument `i` (after "--") as a string, or `default` if missing.
static func arg(i: int, default := "") -> String:
	var a := OS.get_cmdline_user_args()
	return a[i] if a.size() > i else default


## User argument `i` as a float, or `default` if missing.
static func arg_float(i: int, default := 0.0) -> float:
	return float(arg(i)) if arg_count() > i else default


## Number of user arguments (after "--").
static func arg_count() -> int:
	return OS.get_cmdline_user_args().size()


## Instantiates the scene at `path` without adding it to the tree. still_camera: the
## camera ("Camera") loses its free-camera script and the tour ("Rondleiding", if any)
## is turned off, so the tool positions the camera itself.
static func instantiate(path: String, still_camera := true) -> Node:
	var sc: Node = load(path).instantiate()
	if still_camera:
		(sc.get_node("Camera") as Camera3D).set_script(null)
		if sc.has_node("Rondleiding"):
			sc.get_node("Rondleiding").set("active", false)
	return sc


## Places the (still) camera of scene `sc` in the iso view around `focus` (world metres)
## with `view_size` metres in view (see scripts/iso_camera.gd).
static func place_iso(sc: Node, focus: Vector3, view_size: float) -> void:
	Iso.place(sc.get_node("Camera"), focus, view_size)


## Waits until the DetailNiveau node of the (added) scene `sc` has finished merging and
## its loading screen has faded out (0.6 s fade). Returns at once without DetailNiveau.
static func wait_for_merge(sc: Node) -> void:
	var dn := sc.get_node_or_null("DetailNiveau")
	if dn == null or not dn.has_method("is_merging"):
		return
	if not dn.is_merging():
		return
	await dn.merge_finished
	await sc.get_tree().create_timer(0.7).timeout


## Waits `frames` rendered frames (lets shaders compile and LOD/shadows settle). Await it.
static func wait_frames(tree: SceneTree, frames: int) -> void:
	for i in frames:
		await tree.process_frame


## Renders the root viewport at `size` pixels, but in a small window (a quarter of the
## size) in the bottom-right corner of the screen that does not take the focus, so a
## tool does not take over the screen. Screenshots keep the full `size`. Godot sets up
## the window from the project settings after _init, so this is applied on the first
## frame (wait a frame or more before taking a screenshot).
static func render_size(tree: SceneTree, size: Vector2i) -> void:
	tree.process_frame.connect(func() -> void:
		var root := tree.get_root()
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_size = size
		if DisplayServer.get_name() == "headless":
			root.size = size
			return
		root.mode = Window.MODE_WINDOWED
		root.unfocusable = true
		root.size = size / 4
		var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		root.position = screen.end - root.size - Vector2i(20, 20), CONNECT_ONE_SHOT)


## Saves the current image of the root viewport as PNG (res://, user:// or OS path).
static func save_screenshot(tree: SceneTree, path: String) -> void:
	tree.get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))

