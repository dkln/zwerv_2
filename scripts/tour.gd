extends Node
## Automatic tour (the "Rondleiding" node of the world scene): on Play the camera flies
## isometrically past all stops from tour_data.gd, shows a caption with title
## and explanation, and starts over after the last stop.
##
## It takes over the camera (disables free_camera.gd's processing) and waits for
## DetailNiveau to finish merging the city before it starts moving.
## Turn off `active` to look around yourself with the free camera.

const Data = preload("res://scripts/tour_data.gd")
const Iso = preload("res://scripts/iso_camera.gd")
const Caption = preload("res://scripts/caption.gd")

## Run the tour; off = free camera.
@export var active := true
@export var camera_path := NodePath("../Camera")
@export var travel_time := 3.0       ## seconds between two stops
@export var view_time := 7.0         ## seconds per stop
@export var zoom_in := 0.9           ## camera slowly zooms to this factor of the view size while viewing
## The tour starts at the first stop whose slug contains this (empty = at the beginning).
@export var start_at := "kanaal"

var _cam: Camera3D
var _stops := []
## Index of the current stop; keeps counting up, use `% _stops.size()`.
var _i := 0
var _caption: Caption


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
	_caption = Caption.new(self, true)
	_caption.panel.modulate.a = 0.0
	if _stops.is_empty():
		return
	if start_at != "":
		for k in _stops.size():
			if start_at in str(_stops[k]["slug"]):
				_i = k
				break
	var s: Dictionary = _stops[_i]
	Iso.place(_cam, _focus(s), s["size"])
	# only start once the city has been merged (scripts/level_of_detail.gd)
	var dn := get_node_or_null("../DetailNiveau")
	if dn and not dn.is_node_ready():
		await dn.ready
	if dn and dn.has_method("is_merging") and dn.is_merging():
		await dn.merge_finished
	_next()


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
		_next())


## Fills the caption with the stop's texts and the "n / total" counter.
func _show(s: Dictionary) -> void:
	_caption.show_stop(s)
	_caption.counter.text = "%d / %d" % [(_i % _stops.size()) + 1, _stops.size()]
