extends Node
## Automatic tour (the "Rondleiding" node of the world scene): on Play the camera first
## looks at the heart of the old town and slowly zooms in while the Dagcyclus node runs
## through the day (tour_data.gd INTRO and DAY: morning, afternoon, evening, night,
## morning, afternoon), then flies isometrically past all stops from tour_data.gd with
## a caption with title and explanation, and starts over (opening included) after the
## last stop.
##
## It takes over the camera (disables free_camera.gd's processing) and waits for
## DetailNiveau to finish merging the city before it starts moving.
## Turn off `active` to look around yourself with the free camera.

const Data = preload("res://scripts/tour_data.gd")
const Iso = preload("res://scripts/iso_camera.gd")
const Caption = preload("res://scripts/caption.gd")

## Run the tour; off = free camera.
@export var active := true
## Only the highlights (tour_data.gd HIGHLIGHTS) instead of every area of the map.
@export var highlights_only := false
## Open with the day going by in the city centre (skipped when `start_at` is set).
@export var day_intro := true
@export var camera_path := NodePath("../Camera")
@export var day_cycle_path := NodePath("../Dagcyclus")
@export var day_hold := 2.5          ## seconds the opening lingers at each time of day
@export var day_change := 3.0        ## seconds from one time of day to the next
@export var travel_time := 2.0       ## seconds between two stops
@export var view_time := 4.0         ## seconds per stop
@export var zoom_in := 0.9           ## camera slowly zooms to this factor of the view size while viewing
## The tour starts at the first stop whose slug contains this (empty = at the beginning).
@export var start_at := ""

var _cam: Camera3D
var _stops := []
## Index of the current stop; keeps counting up, use `% _stops.size()`.
var _i := 0
var _caption: Caption
var _day: Node
## Clock of the opening in hours; keeps counting past 24 so it only runs forward.
var _hour := 13.0


func _ready() -> void:
	if not active or Engine.is_editor_hint():
		return
	_cam = get_node_or_null(camera_path)
	if _cam == null:
		return
	# the free camera must not fight the tour over the camera
	_cam.set_process(false)
	_cam.set_process_unhandled_input(false)
	_stops = Data.stops(owner if owner else get_parent())
	if highlights_only:
		_stops = Data.highlights(_stops)
	_day = get_node_or_null(day_cycle_path)
	if _day:
		_hour = _day.time_of_day
	_caption = Caption.new(self, true)
	_caption.panel.modulate.a = 0.0
	if _stops.is_empty():
		return
	if start_at != "":
		for k in _stops.size():
			if start_at in str(_stops[k]["slug"]):
				_i = k
				break
	var intro := day_intro and start_at == ""
	if intro:
		Iso.place(_cam, _intro_focus(), Data.INTRO[4])
	else:
		var s: Dictionary = _stops[_i]
		Iso.place(_cam, _focus(s), s["size"])
	# only start once the city has been merged (scripts/level_of_detail.gd)
	var dn := get_node_or_null("../DetailNiveau")
	if dn and not dn.is_node_ready():
		await dn.ready
	if dn and dn.has_method("is_merging") and dn.is_merging():
		await dn.merge_finished
	if intro:
		_intro()
	else:
		_next()


## Focus point of the opening (tour_data.gd INTRO).
func _intro_focus() -> Vector3:
	return Vector3(Data.INTRO[2], 0, Data.INTRO[3])


## The opening: flies to the city centre, then zooms in slowly while the clock runs
## through tour_data.gd DAY, with a caption per time of day; then starts the stops.
func _intro() -> void:
	var size0: float = Data.INTRO[4]
	var size1: float = Data.INTRO[5]
	var day := create_tween()
	day.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	day.tween_property(_caption.panel, "modulate:a", 0.0, 0.5)
	day.parallel().tween_property(_cam, "global_position", Iso.position(_intro_focus(), size0), travel_time)
	# back to the first hour while flying (the clock may run backwards here, briefly)
	var first: float = Data.DAY[0][0]
	day.parallel().tween_method(_set_hour, fposmod(_hour, 24.0), first, travel_time)
	var n := Data.DAY.size()
	var duration := day_change * (n - 1) + day_hold * n
	for k in n:
		var phase: Array = Data.DAY[k]
		if k > 0:
			day.tween_method(_set_hour, float(Data.DAY[k - 1][0]), float(phase[0]), day_change)
		day.tween_callback(_show_phase.bind(phase))
		if k == 0:
			day.tween_property(_caption.panel, "modulate:a", 1.0, 0.6)
			# the zoom runs over the whole day, in a tween of its own
			day.tween_callback(func():
				create_tween().tween_property(_cam, "global_position", Iso.position(_intro_focus(), size1), duration))
		day.tween_interval(day_hold)
	day.tween_callback(func():
		_hour = fposmod(_hour, 24.0)
		_next())


## Sets the clock of the Dagcyclus node and the counter of the opening.
func _set_hour(hour: float) -> void:
	_hour = hour
	if _day:
		_day.set_time(hour)
	var h := fposmod(hour, 24.0)
	_caption.counter.text = "Dagverloop · %02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]


## Shows the caption of one time of day of the opening: [hour, name, text].
func _show_phase(phase: Array) -> void:
	_caption.title.text = "%s · %s" % [Data.INTRO[0], phase[1]]
	_caption.text.text = phase[2]
	_set_hour(phase[0])


## Focus point of a stop on the ground (world metres).
func _focus(s: Dictionary) -> Vector3:
	return Vector3(s["x"], 0, s["z"])


## Camera position for a stop. zoom: factor on the stop's view size (< 1 = closer);
## drift: offset of the focus point in metres. Zooming = changing the distance
## (perspective camera with a fixed field of view).
func _pos(s: Dictionary, zoom := 1.0, drift := Vector3.ZERO) -> Vector3:
	return Iso.position(_focus(s) + drift, float(s["size"]) * zoom)


## Flies to the current stop, shows its caption, lingers, then recurses to the next stop.
func _next() -> void:
	var s: Dictionary = _stops[_i % _stops.size()]
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# travel: position and zoom at the same time; caption fades out first
	t.tween_property(_caption.panel, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(_cam, "global_position", _pos(s), travel_time)
	t.tween_callback(_show.bind(s))
	t.tween_property(_caption.panel, "modulate:a", 1.0, 0.6)
	# view: slowly zoom in and drift a little towards screen-left (4% of the view size)
	var drift: Vector3 = Vector3(-1, 0, 1).normalized() * float(s["size"]) * 0.04
	t.parallel().tween_property(_cam, "global_position", _pos(s, zoom_in, drift), view_time).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func():
		_i += 1
		if day_intro and _i % _stops.size() == 0:
			_intro()
		else:
			_next())


## Fills the caption with the stop's texts and the "n / total" counter.
func _show(s: Dictionary) -> void:
	_caption.show_stop(s)
	_caption.counter.text = "%d / %d" % [(_i % _stops.size()) + 1, _stops.size()]
