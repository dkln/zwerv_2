extends Node
## Automatische rondleiding: bij Play vliegt de camera isometrisch langs alle
## situaties in de kaart, met titel en uitleg in beeld, en begint daarna opnieuw.
## Zet `actief` uit om zelf rond te kijken met de vrije camera.

const Data = preload("res://scripts/rondleiding_data.gd")

@export var actief := true
@export var camera_pad := NodePath("../Camera")
@export var reistijd := 3.0          ## seconden tussen twee stops
@export var kijktijd := 7.0          ## seconden per stop
@export var inzoomen := 0.9          ## camera zoomt tijdens het kijken langzaam naar deze factor
@export var afstand := 300.0

var _cam: Camera3D
var _stops := []
var _i := 0
var _paneel: PanelContainer
var _titel: Label
var _tekst: Label
var _teller: Label


func _ready() -> void:
	if not actief or Engine.is_editor_hint():
		return
	_cam = get_node_or_null(camera_pad)
	if _cam == null:
		return
	_cam.set_process(false)
	_cam.set_process_unhandled_input(false)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.rotation_degrees = Vector3(-35.264, 45, 0)
	_cam.near = 1.0
	_cam.far = 4000.0
	_stops = Data.stops(owner if owner else get_parent())
	_maak_bijschrift()
	if _stops.is_empty():
		return
	var s: Dictionary = _stops[0]
	_cam.global_position = _pos(s)
	_cam.size = s["grootte"]
	_volgende()


func _pos(s: Dictionary) -> Vector3:
	return Vector3(s["x"], 0, s["z"]) + Vector3(1, 1, 1).normalized() * afstand


func _volgende() -> void:
	var s: Dictionary = _stops[_i % _stops.size()]
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# reizen: positie en zoom tegelijk; bijschrift vervaagt eerst
	t.tween_property(_paneel, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(_cam, "global_position", _pos(s), reistijd)
	t.parallel().tween_property(_cam, "size", s["grootte"], reistijd)
	t.tween_callback(_toon.bind(s))
	t.tween_property(_paneel, "modulate:a", 1.0, 0.6)
	# kijken: langzaam inzoomen en een klein stukje meedrijven
	var drift: Vector3 = Vector3(-1, 0, 1).normalized() * float(s["grootte"]) * 0.04
	t.parallel().tween_property(_cam, "size", s["grootte"] * inzoomen, kijktijd).set_trans(Tween.TRANS_LINEAR)
	t.parallel().tween_property(_cam, "global_position", _pos(s) + drift, kijktijd).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func():
		_i += 1
		_volgende())


func _toon(s: Dictionary) -> void:
	_titel.text = s["titel"]
	_tekst.text = s["tekst"]
	_teller.text = "%d / %d" % [(_i % _stops.size()) + 1, _stops.size()]


func _maak_bijschrift() -> void:
	var laag := CanvasLayer.new()
	add_child(laag)
	_paneel = PanelContainer.new()
	var stijl := StyleBoxFlat.new()
	stijl.bg_color = Color(0.08, 0.1, 0.13, 0.78)
	stijl.set_corner_radius_all(10)
	stijl.content_margin_left = 22
	stijl.content_margin_right = 22
	stijl.content_margin_top = 14
	stijl.content_margin_bottom = 16
	_paneel.add_theme_stylebox_override("panel", stijl)
	_paneel.position = Vector2(28, 28)
	_paneel.custom_minimum_size = Vector2(620, 0)
	_paneel.modulate.a = 0.0
	laag.add_child(_paneel)
	var vb := VBoxContainer.new()
	_paneel.add_child(vb)
	_teller = Label.new()
	_teller.add_theme_font_size_override("font_size", 14)
	_teller.add_theme_color_override("font_color", Color(0.95, 0.6, 0.45))
	vb.add_child(_teller)
	_titel = Label.new()
	_titel.add_theme_font_size_override("font_size", 34)
	var vet := FontVariation.new()
	vet.base_font = load("res://assets/fonts/Rubik.ttf")
	vet.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	_titel.add_theme_font_override("font", vet)
	vb.add_child(_titel)
	_tekst = Label.new()
	_tekst.add_theme_font_size_override("font_size", 19)
	_tekst.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95))
	_tekst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tekst.custom_minimum_size = Vector2(620, 0)
	vb.add_child(_tekst)
