extends CanvasLayer
## The stutter meter (debug: the quick start, scenes/snel_starten.tscn): measures every frame
## in real time and writes down each one slower than SLOW_MS, with what happened in it, so a
## stutter can be found on the machine itself (where the GPU work happens: shaders compiling,
## meshes going up). Each line in user://haperingen.txt (and the console):
##   time, the frame (ms), the camera's zoom (m) and how it changed, the LOD level, the nodes
##   added or removed, the vehicles and the people on foot.
## Top left a small line: the frames per second, the slowest frame of the last seconds, and
## how many slow frames so far. F3 shows or hides that line.

const SLOW_MS := 33.0
const LOG_PATH := "user://haperingen.txt"
const WINDOW_SECONDS := 3.0

var city: Node
var _label: Label
var _log: FileAccess
var _last_usec := 0
var _last_zoom := 0.0
var _last_nodes := 0
var _slow_count := 0
var _window_slowest := 0.0
var _window_left := WINDOW_SECONDS
var _frames_in_window := 0
var _started_msec := 0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("#FFE9B8"))
	_label.add_theme_color_override("font_shadow_color", Color("#141831"))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_write("hapermeter: frames trager dan %.0f ms (tijd s | frame ms | zoom m (verschil) | LOD | nodes | voertuigen | voetgangers)" % SLOW_MS)
	_last_usec = Time.get_ticks_usec()
	_started_msec = Time.get_ticks_msec()
	print("hapermeter schrijft naar ", ProjectSettings.globalize_path(LOG_PATH))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3:
		_label.visible = not _label.visible


func _process(_delta: float) -> void:
	if city == null or not is_instance_valid(city):
		city = get_tree().current_scene
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	var zoom := _zoom()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if frame_ms > SLOW_MS and Time.get_ticks_msec() - _started_msec > 2000:
		_slow_count += 1
		_write("%7.1f s | %5.0f ms | zoom %5.1f (%+.1f) | LOD %d | nodes %+d | voertuigen %d | voetgangers %d" % [
			(Time.get_ticks_msec() - _started_msec) / 1000.0, frame_ms, zoom, zoom - _last_zoom, _lod_level(),
			nodes - _last_nodes, Vehicle.all_vehicles.size(), _walkers()])
	_last_zoom = zoom
	_last_nodes = nodes
	_window_slowest = maxf(_window_slowest, frame_ms)
	_frames_in_window += 1
	_window_left -= frame_ms / 1000.0
	if _window_left <= 0.0:
		_label.text = "%d fps | traagst %.0f ms | haperingen %d (F3)" % [roundi(_frames_in_window / WINDOW_SECONDS), _window_slowest, _slow_count]
		_window_slowest = 0.0
		_frames_in_window = 0
		_window_left = WINDOW_SECONDS


func _write(line: String) -> void:
	print(line)
	if _log:
		_log.store_line(line)
		_log.flush()


func _zoom() -> float:
	var follow := city.get_node_or_null("Volgcamera") if city else null
	return float(follow.get("_zoom")) if follow and follow.get("_zoom") != null else 0.0


func _lod_level() -> int:
	var detail := city.get_node_or_null("DetailNiveau") if city else null
	return int(detail.get("_level")) if detail and detail.get("_level") != null else -1


func _walkers() -> int:
	var walkers := city.get_node_or_null("Voetgangers") if city else null
	return walkers.call("people").size() if walkers and walkers.has_method("people") else 0
