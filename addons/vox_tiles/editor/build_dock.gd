@tool
extends VBoxContainer
## The "Build" dock (plugin.gd): pick the GridMap layer to edit with one click,
## see the floor you are drawing on in metres, hide the other layers while
## editing, and choose a stamp (stamps.gd) with its parameters.
## The tools only show in a Vox Tiles scene; the checkbox at the top marks the edited
## scene as one (see editor_view.gd).
## It only shows state and emits signals; plugin.gd does the work.

const Stamps = preload("res://addons/vox_tiles/editor/stamps.gd")

## The sides of a tile as the Lanes buttons and the 3D view call them.
const SIDE_LABELS := {"N": "Forward", "W": "Left", "E": "Right", "S": "Back"}
## The kinds of road user (RoadNetwork.ROAD_USER_KINDS) as the checkboxes call them.
const KIND_LABELS := {"auto": "Auto", "brommer": "Brommer", "fiets": "Fiets", "voetganger": "Voetganger"}

signal marked_toggled(on: bool)
signal game_view_toggled(on: bool)
signal layer_chosen(layer_name: String)
signal floor_step(delta: int)
signal solo_toggled(on: bool)
signal stamping_toggled(on: bool)
signal lane_picking_toggled(on: bool)
signal lane_side_toggled(side: String, on: bool)
signal lanes_automatic_pressed
signal lane_kind_toggled(kind: String, on: bool)
signal lane_kinds_automatic_pressed
signal lane_speed_changed(kmh: int)
signal lane_speed_automatic_pressed

var _marked: CheckBox
var _tools: VBoxContainer       # everything below the checkbox
var _view_editor: Button
var _view_game: Button
var _layer_box: HBoxContainer
var _floor_label: Label
var _solo: CheckBox
var _stamp_choice: OptionButton
var _params_grid: GridContainer
var _param_controls := {}   # parameter name -> SpinBox / OptionButton
var _stamp_button: Button
var _status: Label
var _library: MeshLibrary
var _lane_pick_button: Button
var _lane_tile_label: Label
var _lane_box: VBoxContainer
var _lane_side_buttons := {}   # "N", "E", "S", "W" -> Button
var _lanes_automatic: Button
var _lane_kind_boxes := {}     # road user kind -> CheckBox
var _lane_kinds_automatic: Button
var _lane_speed: SpinBox
var _lane_speed_automatic: Button


func _init() -> void:
	name = "Build"
	_marked = CheckBox.new()
	_marked.text = "Vox Tiles scene"
	_marked.tooltip_text = "Use the Vox Tiles plugin in this scene: build tools and a fast editor view\n(no shadows, reflections, effects or animation, lines on the tile borders).\nSaved in the scene; the game itself is not affected."
	_marked.toggled.connect(func(on): marked_toggled.emit(on))
	add_child(_marked)
	_tools = VBoxContainer.new()
	add_child(_tools)
	var view_row := HBoxContainer.new()
	var view_label := Label.new()
	view_label.text = "View"
	view_row.add_child(view_label)
	var group := ButtonGroup.new()
	_view_editor = _button("Editor", func(): game_view_toggled.emit(false))
	_view_editor.tooltip_text = "Fast: no shadows, reflections, effects or animation; outlines of the\ntiles of the selected layer; orthogonal camera."
	_view_game = _button("Game", func(): game_view_toggled.emit(true))
	_view_game.tooltip_text = "As in the game: shadows, sun, reflections, effects and animation.\n(LOD and merging only run in the game itself.)"
	for b in [_view_editor, _view_game]:
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		view_row.add_child(b)
	_view_editor.button_pressed = true
	_tools.add_child(view_row)
	_tools.add_child(_heading("Layer"))
	_layer_box = HBoxContainer.new()
	_tools.add_child(_layer_box)
	var floor_row := HBoxContainer.new()
	floor_row.add_child(_button("-", func(): floor_step.emit(-1)))
	_floor_label = Label.new()
	_floor_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_row.add_child(_floor_label)
	floor_row.add_child(_button("+", func(): floor_step.emit(1)))
	_tools.add_child(floor_row)
	_solo = CheckBox.new()
	_solo.text = "Hide other layers"
	_solo.toggled.connect(func(on): solo_toggled.emit(on))
	_tools.add_child(_solo)

	_tools.add_child(_heading("Stamps"))
	_stamp_choice = OptionButton.new()
	for stamp in Stamps.STAMPS:
		_stamp_choice.add_item(Stamps.STAMPS[stamp].label)
		_stamp_choice.set_item_metadata(_stamp_choice.item_count - 1, stamp)
	_stamp_choice.item_selected.connect(func(_i): _build_params())
	_tools.add_child(_stamp_choice)
	_params_grid = GridContainer.new()
	_params_grid.columns = 2
	_tools.add_child(_params_grid)
	_stamp_button = Button.new()
	_stamp_button.text = "Draw stamp"
	_stamp_button.toggle_mode = true
	_stamp_button.toggled.connect(func(on): stamping_toggled.emit(on))
	_tools.add_child(_stamp_button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tools.add_child(_status)
	_tools.add_child(_heading("Traffic"))
	_build_lane_controls()
	_build_params()
	set_layers([], "")
	set_floor_text("")


## Shows one button per GridMap layer; the active one is pressed.
func set_layers(layer_names: Array, active: String) -> void:
	for c in _layer_box.get_children():
		c.queue_free()
	for layer_name in layer_names:
		var b := _button(layer_name, func(): layer_chosen.emit(layer_name))
		b.toggle_mode = true
		b.button_pressed = layer_name == active
		_layer_box.add_child(b)
	if layer_names.is_empty():
		_layer_box.add_child(_hint("No GridMap layers in this scene"))


## Marked: the edited scene is a Vox Tiles scene (tools shown). has_scene: false
## without an open scene (checkbox disabled).
func set_marked(marked: bool, has_scene: bool) -> void:
	_marked.set_pressed_no_signal(marked)
	_marked.disabled = not has_scene
	_tools.visible = marked


func set_game_view(on: bool) -> void:
	(_view_game if on else _view_editor).set_pressed_no_signal(true)
	(_view_editor if on else _view_game).set_pressed_no_signal(false)


func set_floor_text(text: String) -> void:
	_floor_label.text = text if text != "" else "Select a layer"


func set_solo(on: bool) -> void:
	_solo.set_pressed_no_signal(on)


## The Grond library, used to list the deck tiles.
func set_library(lib: MeshLibrary) -> void:
	if lib != _library:
		_library = lib
		_build_params()


func set_stamping(on: bool) -> void:
	_stamp_button.set_pressed_no_signal(on)
	set_status("Click the start cell, then the end cell in the 3D view. Right-click or Esc cancels." if on else "")


func set_status(text: String) -> void:
	_status.text = text


func stamp() -> String:
	return _stamp_choice.get_item_metadata(_stamp_choice.selected)


func params() -> Dictionary:
	var out := Stamps.defaults(stamp())
	for p in _param_controls:
		var c: Control = _param_controls[p]
		out[p] = int(c.value) if c is SpinBox else c.get_item_metadata(c.selected)
	return out


## (Re)creates the parameter controls of the selected stamp from Stamps.STAMPS:
## [label, default int, min, max] -> SpinBox, [label, default, [options]] -> list,
## [label, default, "prefix", "excluded suffix"] -> list of library tiles.
func _build_params() -> void:
	for c in _params_grid.get_children():
		c.queue_free()
	_param_controls.clear()
	var specs: Dictionary = Stamps.STAMPS[stamp()].params
	for p in specs:
		var spec: Array = specs[p]
		var label := Label.new()
		label.text = spec[0]
		_params_grid.add_child(label)
		var control: Control
		if spec[1] is int:
			control = SpinBox.new()
			control.min_value = spec[2]
			control.max_value = spec[3]
			control.value = spec[1]
		else:
			control = OptionButton.new()
			var options: Array = spec[2] if spec[2] is Array else _library_items(spec[2], spec[3] if spec.size() > 3 else "")
			if not spec[1] in options:
				options.push_front(spec[1])
			for option in options:
				control.add_item(str(option).get_file())
				control.set_item_metadata(control.item_count - 1, option)
			control.select(options.find(spec[1]))
		control.size_flags_horizontal = SIZE_EXPAND_FILL
		_params_grid.add_child(control)
		_param_controls[p] = control


## Pick button, the placed tile that is picked, and a button per side of that tile.
func _build_lane_controls() -> void:
	_lane_pick_button = Button.new()
	_lane_pick_button.text = "Pick tile"
	_lane_pick_button.toggle_mode = true
	_lane_pick_button.tooltip_text = "Click a ground tile in the 3D view to choose its directions, who may come on it and its speed limit.\nClick it again for the tile below it. Esc stops."
	_lane_pick_button.toggled.connect(func(on): lane_picking_toggled.emit(on))
	_tools.add_child(_lane_pick_button)
	_lane_tile_label = Label.new()
	_lane_tile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tools.add_child(_lane_tile_label)
	_lane_box = VBoxContainer.new()
	_tools.add_child(_lane_box)
	var sides := GridContainer.new()
	sides.columns = 3
	_lane_box.add_child(sides)
	# a cross, as the sides lie on the tile: empty corners, forward on top
	for side in ["", "N", "", "W", "", "E", "", "S", ""]:
		if side == "":
			sides.add_child(Control.new())
			continue
		var side_button := Button.new()
		side_button.text = SIDE_LABELS[side]
		side_button.toggle_mode = true
		side_button.size_flags_horizontal = SIZE_EXPAND_FILL
		side_button.toggled.connect(func(on): lane_side_toggled.emit(side, on))
		sides.add_child(side_button)
		_lane_side_buttons[side] = side_button
	_lanes_automatic = Button.new()
	_lanes_automatic.text = "Automatic"
	_lanes_automatic.tooltip_text = "Forget the choice: the lanes of the tile itself, decided from the road around it."
	_lanes_automatic.pressed.connect(func(): lanes_automatic_pressed.emit())
	_lane_box.add_child(_lanes_automatic)
	var allowed := Label.new()
	allowed.text = "Allowed on this tile"
	_lane_box.add_child(allowed)
	for kind: String in KIND_LABELS:
		var kind_box := CheckBox.new()
		kind_box.text = KIND_LABELS[kind]
		if kind == "auto":
			kind_box.tooltip_text = "Cars, vans, trucks and buses."
		else:
			kind_box.tooltip_text = "Stored with the tile; this road user is not in the game yet."
		kind_box.toggled.connect(func(on): lane_kind_toggled.emit(kind, on))
		_lane_box.add_child(kind_box)
		_lane_kind_boxes[kind] = kind_box
	_lane_kinds_automatic = Button.new()
	_lane_kinds_automatic.text = "Tile default"
	_lane_kinds_automatic.tooltip_text = "Forget the choice: who may use it follows from the tile itself."
	_lane_kinds_automatic.pressed.connect(func(): lane_kinds_automatic_pressed.emit())
	_lane_box.add_child(_lane_kinds_automatic)
	var speed_row := HBoxContainer.new()
	var speed_label := Label.new()
	speed_label.text = "Speed limit"
	speed_row.add_child(speed_label)
	_lane_speed = SpinBox.new()
	_lane_speed.min_value = 5
	_lane_speed.max_value = 130
	_lane_speed.step = 5
	_lane_speed.suffix = "km/h"
	_lane_speed.size_flags_horizontal = SIZE_EXPAND_FILL
	_lane_speed.value_changed.connect(func(kmh): lane_speed_changed.emit(int(kmh)))
	speed_row.add_child(_lane_speed)
	_lane_box.add_child(speed_row)
	_lane_speed_automatic = Button.new()
	_lane_speed_automatic.text = "Tile speed"
	_lane_speed_automatic.tooltip_text = "Forget the choice: the speed limit follows from the tile and the road it is part of."
	_lane_speed_automatic.pressed.connect(func(): lane_speed_automatic_pressed.emit())
	_lane_box.add_child(_lane_speed_automatic)
	set_lane_tile("", [], false)


func set_lane_picking(on: bool) -> void:
	_lane_pick_button.set_pressed_no_signal(on)


## Shows the picked tile ("" = none): the sides traffic may leave it in, and whether
## they were chosen by hand; the same for the kinds of road user allowed on it and for
## its speed limit (km/h).
func set_lane_tile(description: String, open_sides: Array, chosen: bool, allowed_kinds := [], kinds_chosen := false,
		speed_kmh := 50.0, speed_chosen := false) -> void:
	_lane_tile_label.text = description
	_lane_box.visible = description != ""
	for side in _lane_side_buttons:
		_lane_side_buttons[side].set_pressed_no_signal(side in open_sides)
	_lanes_automatic.disabled = not chosen
	for kind in _lane_kind_boxes:
		_lane_kind_boxes[kind].set_pressed_no_signal(kind in allowed_kinds)
	_lane_kinds_automatic.disabled = not kinds_chosen
	_lane_speed.set_value_no_signal(speed_kmh)
	_lane_speed_automatic.disabled = not speed_chosen


func _library_items(prefix: String, excluded_suffix := "") -> Array:
	var out := []
	if _library:
		for id in _library.get_item_list():
			var item := _library.get_item_name(id)
			if item.begins_with(prefix) and (excluded_suffix == "" or not item.ends_with(excluded_suffix)):
				out.append(item)
	out.sort()
	return out


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l


func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate.a = 0.6
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	return b
