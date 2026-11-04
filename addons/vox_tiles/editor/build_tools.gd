@tool
extends RefCounted
## Editor tools behind the "Build" dock (build_dock.gd), owned by plugin.gd.
##
## Only in a Vox Tiles scene: the dock's checkbox marks the edited scene as one
## (metadata on the scene root, one undo step; see editor_view.gd), which also
## switches on the fast editor view and the outlines of the tiles of the selected
## layer (outline.gd).
##
## Layers: the GridMaps directly under the edited scene root. Choosing one
## selects it, so Godot's own GridMap editor (palette, floors, paint tools)
## edits that layer. The floor shown in the dock is read from the GridMap
## editor's floor field (it has no API, so we look the SpinBox up in the editor UI).
##
## What is being edited stands out in the 3D view: the floor of the layer (outline.gd) and a
## grid, a card with the selected tile and a box at the mouse (layer_highlight.gd).
##
## Hide other layers: hides the other GridMaps while editing. They are shown
## again before the scene is saved or run (_apply_changes), so it never ends up
## in the scene file.
##
## Stamps: while drawing, the scene root is selected so this plugin receives the
## 3D view input (plugin.gd _handles). Click a start and an end cell on street
## level; the stamp (stamps.gd) is applied to the Grond layer as one undo step.
##
## Traffic: while picking, the same way, a click on a ground tile shows its sides in the
## dock; each may be on or off (forward, left, right, back, in any combination), and so may
## each kind of road user allowed on it; it has a speed limit in km/h. The choice is a
## property of that placed tile, one undo step each (RoadNetwork.LANE_CHOICES, a meta of
## Grond, saved with the scene). The arrows of Rijrichtingen (lane_arrows.gd) show the result.

const BuildDock = preload("res://addons/vox_tiles/editor/build_dock.gd")
const Stamps = preload("res://addons/vox_tiles/editor/stamps.gd")
const EditorView = preload("res://addons/vox_tiles/editor/editor_view.gd")
const Outline = preload("res://addons/vox_tiles/editor/outline.gd")
const LayerHighlight = preload("res://addons/vox_tiles/editor/layer_highlight.gd")

## layer that stamps are applied to
const STAMP_LAYER := "Grond"
const PREVIEW_FILL := Color(0.3, 0.7, 1.0, 0.25)
const PREVIEW_LINE := Color(0.3, 0.7, 1.0, 0.9)
const PICKED_FILL := Color(1.0, 0.55, 0.05, 0.3)

## The edited scene was marked or unmarked as a Vox Tiles scene.
signal marked_changed

var dock: BuildDock
var _plugin: EditorPlugin
var _active: GridMap
var _outline: Outline
var _highlight := LayerHighlight.new()
## The editor view (set by plugin.gd); the dock's view switch changes its game_view.
var view: EditorView
var _solo := false
var _hidden: Array[GridMap] = []
var _floor_spin: SpinBox
var _stamping := false
var _start = null          # Vector3i of the first clicked cell, or null
var _hover = null          # Vector3i of the cell under the mouse, or null
var _camera: Camera3D
var _lane_picking := false
var _lane_cell = null      # Vector3i of the picked road tile, or null


func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_outline = Outline.new(plugin)
	dock = BuildDock.new()
	dock.marked_toggled.connect(_set_marked)
	dock.game_view_toggled.connect(_set_game_view)
	dock.layer_chosen.connect(_choose_layer)
	dock.floor_step.connect(_step_floor)
	dock.solo_toggled.connect(func(on): _solo = on; _update_solo())
	dock.stamping_toggled.connect(_set_stamping)
	dock.lane_picking_toggled.connect(_set_lane_picking)
	dock.lane_side_toggled.connect(_toggle_lane_side)
	dock.lanes_automatic_pressed.connect(_set_choice_field.bind("lanes", null, "Automatic lanes of a tile"))
	dock.lane_kind_toggled.connect(_toggle_lane_kind)
	dock.lane_kinds_automatic_pressed.connect(_set_choice_field.bind("kinds", null, "Default road users of a tile"))
	dock.lane_speed_changed.connect(func(kmh: int): _set_choice_field("speed", kmh, "Speed limit of a tile"))
	dock.lane_speed_automatic_pressed.connect(_set_choice_field.bind("speed", null, "Default speed limit of a tile"))
	EditorInterface.get_selection().selection_changed.connect(refresh)


## Disconnects and shows hidden layers again; called when the plugin unloads.
func cleanup() -> void:
	_outline.cleanup()
	_highlight.cleanup()
	_show_hidden()
	var sel := EditorInterface.get_selection()
	if sel.selection_changed.is_connected(refresh):
		sel.selection_changed.disconnect(refresh)
	if _floor_spin and is_instance_valid(_floor_spin) and _floor_spin.value_changed.is_connected(_on_floor_changed):
		_floor_spin.value_changed.disconnect(_on_floor_changed)


## Updates the dock after the selection or the edited scene changed.
func refresh(_arg = null) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var marked := EditorView.is_marked(root)
	dock.set_marked(marked, root != null)
	if not marked:
		if _stamping:
			_set_stamping(false)
		if _lane_picking:
			_set_lane_picking(false)
		_show_hidden()
		_active = null
		_outline.set_target(null)
		_highlight.set_target(null)
		return
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.size() == 1 and selected[0] is GridMap and selected[0] in _layers():
		_active = selected[0]
	if _active and (not is_instance_valid(_active) or not _active in _layers()):
		_active = null
		_hidden.clear()
	var names := _layers().map(func(gm): return String(gm.name))
	dock.set_layers(names, String(_active.name) if _active else "")
	var in_editor_view := view == null or not view.game_view
	_outline.set_target(_active if in_editor_view else null)
	var editing_layer: bool = in_editor_view and selected.size() == 1 and selected[0] == _active
	_highlight.set_target(_active if editing_layer else null)
	dock.set_game_view(view != null and view.game_view)
	var grond := _grond()
	dock.set_library(grond.mesh_library if grond else null)
	_update_floor_text()
	_update_solo()


## True while drawing a stamp or picking a tile: then this plugin takes the 3D view input;
## and for a layer being edited, whose input it only watches (forward_input passes it on
## to Godot's GridMap editor).
func handles(object: Object) -> bool:
	if not EditorView.is_marked(EditorInterface.get_edited_scene_root()):
		return false
	return (object is Node and (_stamping or _lane_picking)) or (object is GridMap and object in _layers())


## Shows the hidden layers before saving/running; hides them again right after.
func apply_changes() -> void:
	if not _hidden.is_empty():
		_show_hidden()
		_update_solo.call_deferred()


# ------------------------------------------------------------------ layers

## Dock view switch: Editor (fast, outlines) or Game (as in the game).
func _set_game_view(on: bool) -> void:
	if view:
		view.game_view = on
		view.refresh()
	refresh()


## Marks (or unmarks) the edited scene as a Vox Tiles scene, as one undo step.
func _set_marked(on: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var ur := _plugin.get_undo_redo()
	ur.create_action("Vox Tiles scene: on" if on else "Vox Tiles scene: off", UndoRedo.MERGE_DISABLE, root)
	if on:
		ur.add_do_method(root, "set_meta", EditorView.SCENE_META, true)
		ur.add_undo_method(root, "remove_meta", EditorView.SCENE_META)
	else:
		ur.add_do_method(root, "remove_meta", EditorView.SCENE_META)
		ur.add_undo_method(root, "set_meta", EditorView.SCENE_META, true)
	ur.add_do_method(self, "refresh")
	ur.add_undo_method(self, "refresh")
	ur.commit_action()
	marked_changed.emit()


func _layers() -> Array:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return []
	return root.get_children().filter(func(n): return n is GridMap)


func _grond() -> GridMap:
	for gm in _layers():
		if gm.name == STAMP_LAYER:
			return gm
	return null


func _choose_layer(layer_name: String) -> void:
	_set_stamping(false)
	_set_lane_picking(false)
	for gm in _layers():
		if gm.name == layer_name:
			_active = gm
			var sel := EditorInterface.get_selection()
			sel.clear()
			sel.add_node(gm)
			EditorInterface.edit_node(gm)
	refresh()


func _update_solo() -> void:
	_show_hidden()
	if not _solo or _active == null:
		return
	for gm in _layers():
		if gm != _active and gm.visible:
			gm.visible = false
			_hidden.append(gm)


func _show_hidden() -> void:
	for gm in _hidden:
		if is_instance_valid(gm):
			gm.visible = true
	_hidden.clear()


# ------------------------------------------------------------------ floor

## The floor field of Godot's GridMap editor (looked up by its tooltip), or null.
func _find_floor_spin() -> SpinBox:
	if _floor_spin and is_instance_valid(_floor_spin):
		return _floor_spin
	_floor_spin = _find_spin(EditorInterface.get_base_control())
	if _floor_spin:
		_floor_spin.value_changed.connect(_on_floor_changed)
	return _floor_spin


func _find_spin(node: Node) -> SpinBox:
	if node is SpinBox and node.tooltip_text.contains("Floor"):
		return node
	for c in node.get_children():
		var found := _find_spin(c)
		if found:
			return found
	return null


func _step_floor(delta: int) -> void:
	var spin := _find_floor_spin()
	if spin:
		spin.value += delta


func _on_floor_changed(_value: float) -> void:
	_update_floor_text()


## "Floor 2 · 6.38 m" for the active layer: the height of the bottom of that floor.
func _update_floor_text() -> void:
	var spin := _find_floor_spin() if _active else null
	if _active == null or spin == null:
		dock.set_floor_text("")
		return
	var level := int(spin.value)
	_outline.set_floor(level)
	_highlight.set_floor(level)
	_plugin.update_overlays()
	var metres := _active.global_position.y + level * _active.cell_size.y
	dock.set_floor_text("Floor %d · %.2f m" % [level, metres])


# ------------------------------------------------------------------ stamps

func _set_stamping(on: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if on and _grond() == null:
		dock.set_stamping(false)
		dock.set_status("This scene has no '%s' layer to stamp on." % STAMP_LAYER)
		return
	if on:
		_set_lane_picking(false)
	_stamping = on
	_start = null
	_hover = null
	dock.set_stamping(on)
	if on and root:
		# select the root so the GridMap editor lets go and this plugin gets the input
		var sel := EditorInterface.get_selection()
		sel.clear()
		sel.add_node(root)
		EditorInterface.edit_node(root)
	_plugin.update_overlays()


## 3D view input while drawing: hover, first click = start, second click = place.
func forward_input(camera: Camera3D, event: InputEvent) -> int:
	if _lane_picking:
		return _forward_lane_input(camera, event)
	if not _stamping:
		_camera = camera
		if event is InputEventMouseMotion:
			_highlight.set_mouse(event.position)
			_plugin.update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_camera = camera
	if event is InputEventMouseMotion:
		_hover = _pick_cell(camera, event.position)
		_plugin.update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var cancel: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) \
		or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE)
	if cancel:
		if _start == null:
			_set_stamping(false)
		_start = null
		_plugin.update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = _pick_cell(camera, event.position)
		if cell != null:
			if _start == null:
				_start = cell
			else:
				_place(_start, cell)
				_start = null
		_plugin.update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## Grond cell (on floor 0) under a screen position: the camera ray hits street level.
func _pick_cell(camera: Camera3D, screen: Vector2):
	var grond := _grond()
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if grond == null or absf(dir.y) < 0.0001:
		return null
	var t := -origin.y / dir.y
	if t < 0.0:
		return null
	var cell := grond.local_to_map(grond.to_local(origin + dir * t))
	return Vector3i(cell.x, 0, cell.z)


## The planned cells for the current start/hover, or [] if there is nothing to show.
func _current_plan() -> Array:
	if _hover == null:
		return []
	var from: Vector3i = _start if _start != null else _hover
	var ln := Stamps.line(from, _hover)
	return Stamps.plan(dock.stamp(), dock.params(), from, ln.x, ln.y, _grond())


func _place(from: Vector3i, to: Vector3i) -> void:
	var stamp := dock.stamp()
	var ln := Stamps.line(from, to)
	var min_length := Stamps.min_length(stamp, dock.params())
	if ln.y < min_length:
		dock.set_status("%s needs at least %d tiles (this line has %d)." % [Stamps.STAMPS[stamp].label, min_length, ln.y])
		return
	var grond := _grond()
	var lib := grond.mesh_library
	var cells := {}   # cell -> [item id, orientation]; a later entry wins
	var missing := {}
	for e in Stamps.plan(stamp, dock.params(), from, ln.x, ln.y, grond):
		var id := -1
		if e.item != "":
			id = lib.find_item_by_name(e.item)
			if id < 0:
				missing[e.item] = true
				continue
		cells[e.cell] = [id, grond.get_orthogonal_index_from_basis(Basis(Vector3.UP, e.rot * PI / 2.0))]
	var undo := _plugin.get_undo_redo()
	undo.create_action("Stamp: " + Stamps.STAMPS[stamp].label, UndoRedo.MERGE_DISABLE, grond)
	for cell in cells:
		undo.add_do_method(grond, "set_cell_item", cell, cells[cell][0], cells[cell][1])
		undo.add_undo_method(grond, "set_cell_item", cell, grond.get_cell_item(cell), grond.get_cell_item_orientation(cell))
	undo.commit_action()
	dock.set_status("Placed %s (%d tiles long)." % [Stamps.STAMPS[stamp].label, ln.y]
		+ ("" if missing.is_empty() else "\nMissing tiles: " + ", ".join(missing.keys())))


## Draws the footprint of the stamp on street level over the 3D view.
func draw_overlay(overlay: Control) -> void:
	_highlight.draw(overlay, _camera)
	if _lane_picking and _camera != null:
		_draw_lane_tile(overlay)
	if not _stamping or _camera == null:
		return
	var grond := _grond()
	if grond == null:
		return
	var seen := {}
	var half := Vector3(grond.cell_size.x, 0, grond.cell_size.z) * 0.5
	for e in _current_plan():
		var xz := Vector2i(e.cell.x, e.cell.z)
		if seen.has(xz):
			continue
		seen[xz] = true
		var centre := grond.to_global(grond.map_to_local(Vector3i(xz.x, 0, xz.y)))
		centre.y = grond.global_position.y
		var pts := PackedVector2Array()
		for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
			var p: Vector3 = centre + corner * half
			if _camera.is_position_behind(p):
				pts.clear()
				break
			pts.append(_camera.unproject_position(p))
		if pts.size() == 4:
			overlay.draw_colored_polygon(pts, PREVIEW_FILL)
			pts.append(pts[0])
			overlay.draw_polyline(pts, PREVIEW_LINE, 1.0)
	if _start != null and _hover != null:
		var ln := Stamps.line(_start, _hover)
		var font := overlay.get_theme_default_font()
		var at := _camera.unproject_position(grond.to_global(grond.map_to_local(_hover)))
		overlay.draw_string(font, at + Vector2(12, -12), "%d tiles" % ln.y, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


# ------------------------------------------------------------------ lanes

func _set_lane_picking(on: bool) -> void:
	if on and _grond() == null:
		dock.set_lane_picking(false)
		dock.set_status("This scene has no '%s' layer." % STAMP_LAYER)
		return
	if on and _stamping:
		_set_stamping(false)
	_lane_picking = on
	dock.set_lane_picking(on)
	if on:
		# select the root so the GridMap editor lets go and this plugin gets the input
		var root := EditorInterface.get_edited_scene_root()
		var selection := EditorInterface.get_selection()
		selection.clear()
		selection.add_node(root)
		EditorInterface.edit_node(root)
	else:
		_lane_cell = null
		dock.set_lane_tile("", [], false)
	_plugin.update_overlays()


## 3D view input while picking: a click picks a ground tile, Esc stops. Anything else (also
## the right mouse button, to look around) goes on to the 3D view.
func _forward_lane_input(camera: Camera3D, event: InputEvent) -> int:
	_camera = camera
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_set_lane_picking(false)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_lane_cell = _pick_ground_tile(camera, event.position)
		_show_lane_tile()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		_plugin.update_overlays()   # the labels on the tile follow the camera
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## The ground tile under a screen position, or null: the highest level whose surface the
## camera ray hits in a tile. With the tile that is already picked under the mouse: the
## next one down (a tunnel under a street).
func _pick_ground_tile(camera: Camera3D, screen: Vector2):
	var grond := _grond()
	var network := RoadNetwork.new(grond)
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.0001:
		return null
	var levels := {}
	for cell: Vector3i in network.ground_cells():
		levels[cell.y] = true
	var levels_from_top: Array = levels.keys()
	levels_from_top.sort()
	levels_from_top.reverse()
	var under_mouse: Array[Vector3i] = []
	for level: int in levels_from_top:
		var surface := grond.global_position.y + level * grond.cell_size.y + RoadNetwork.ROAD_SURFACE
		var ray_length := (surface - origin.y) / direction.y
		if ray_length < 0.0:
			continue
		var hit := grond.local_to_map(grond.to_local(origin + direction * ray_length))
		var cell := Vector3i(hit.x, level, hit.z)
		if grond.get_cell_item(cell) >= 0:
			under_mouse.append(cell)
	if under_mouse.is_empty():
		return null
	if _lane_cell != null and _lane_cell in under_mouse:
		return under_mouse[(under_mouse.find(_lane_cell) + 1) % under_mouse.size()]
	return under_mouse[0]


## Shows the picked tile in the dock, as the road network sees it now.
func _show_lane_tile() -> void:
	_plugin.update_overlays()
	var grond := _grond()
	if _lane_cell == null or grond == null or grond.get_cell_item(_lane_cell) < 0:
		dock.set_lane_tile("", [], false)
		return
	var network := RoadNetwork.new(grond)
	var description := "%s\ncell %d, %d, level %d" % [network.tile_name(_lane_cell), _lane_cell.x, _lane_cell.z, _lane_cell.y]
	dock.set_lane_tile(description, _open_sides(network, _lane_cell), network.is_chosen(_lane_cell),
			network.allowed_kinds(_lane_cell), network.has_chosen_kinds(_lane_cell),
			network.speed_limit_kmh(_lane_cell), network.has_chosen_speed(_lane_cell))


## The sides of the tile in `cell` traffic may leave it in now.
func _open_sides(network: RoadNetwork, cell: Vector3i) -> Array:
	var headings := network.lanes(cell)
	return RoadNetwork.LOCAL_HEADINGS.keys().filter(
			func(side: String) -> bool: return network.heading_of_side(cell, side) in headings)


## A side button of the dock: from now on this tile has its own lanes.
func _toggle_lane_side(side: String, on: bool) -> void:
	var grond := _grond()
	if _lane_cell == null or grond == null:
		return
	var sides := _open_sides(RoadNetwork.new(grond), _lane_cell)
	sides.erase(side)
	if on:
		sides.append(side)
	if sides.is_empty():
		dock.set_status("A tile with lanes keeps at least one direction; use Automatic to reset it.")
		_show_lane_tile()
		return
	dock.set_status("")
	_set_choice_field("lanes", sides, "Lanes of a tile")


## A road user checkbox of the dock: from now on this tile has its own kinds. All off
## closes it to everyone.
func _toggle_lane_kind(kind: String, on: bool) -> void:
	var grond := _grond()
	if _lane_cell == null or grond == null:
		return
	var kinds: Array = RoadNetwork.new(grond).allowed_kinds(_lane_cell).duplicate()
	kinds.erase(kind)
	if on:
		kinds.append(kind)
	_set_choice_field("kinds", kinds, "Road users of a tile")


## Sets one field ("lanes", "kinds", "speed") of the choice of the picked tile; null forgets it, and
## the tile falls back on what it says itself. An entry for an older tile in the cell goes.
func _set_choice_field(field: String, value: Variant, action: String) -> void:
	var grond := _grond()
	if _lane_cell == null or grond == null:
		return
	var item_name := grond.mesh_library.get_item_name(grond.get_cell_item(_lane_cell))
	var choices: Dictionary = grond.get_meta(RoadNetwork.LANE_CHOICES, {}).duplicate()
	var entry: Dictionary = choices.get(_lane_cell, {}).duplicate()
	if entry.get("tile", "") != item_name:
		entry = {"tile": item_name}
	if value == null:
		entry.erase(field)
	else:
		entry[field] = value
	if entry.has("lanes") or entry.has("kinds") or entry.has("speed"):
		choices[_lane_cell] = entry
	else:
		choices.erase(_lane_cell)
	_commit_lane_choices(grond, choices, action)


func _commit_lane_choices(grond: GridMap, choices: Dictionary, action: String) -> void:
	var undo := _plugin.get_undo_redo()
	undo.create_action(action, UndoRedo.MERGE_DISABLE, grond)
	undo.add_do_method(self, "_store_lane_choices", grond, choices)
	undo.add_undo_method(self, "_store_lane_choices", grond, grond.get_meta(RoadNetwork.LANE_CHOICES, {}))
	undo.commit_action()


func _store_lane_choices(grond: GridMap, choices: Dictionary) -> void:
	if choices.is_empty():
		grond.remove_meta(RoadNetwork.LANE_CHOICES)
	else:
		grond.set_meta(RoadNetwork.LANE_CHOICES, choices)
	_show_lane_tile()


## Marks the picked tile in the 3D view, with the name of each side at that side.
func _draw_lane_tile(overlay: Control) -> void:
	var grond := _grond()
	if _lane_cell == null or grond == null or grond.get_cell_item(_lane_cell) < 0:
		return
	var turn := grond.get_basis_with_orthogonal_index(grond.get_cell_item_orientation(_lane_cell))
	var centre := grond.to_global(grond.map_to_local(_lane_cell))
	centre.y = grond.global_position.y + _lane_cell.y * grond.cell_size.y + RoadNetwork.ROAD_SURFACE
	var half := grond.cell_size.x * 0.5
	var outline := PackedVector2Array()
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		var point: Vector3 = centre + corner * half
		if _camera.is_position_behind(point):
			return
		outline.append(_camera.unproject_position(point))
	overlay.draw_colored_polygon(outline.slice(0, 4), PICKED_FILL)
	overlay.draw_polyline(outline, LayerHighlight.ACCENT, 4.0)
	var font := overlay.get_theme_default_font()
	for side: String in BuildDock.SIDE_LABELS:
		var at: Vector3 = centre + turn * RoadNetwork.LOCAL_HEADINGS[side] * half * 0.75
		overlay.draw_string(font, _camera.unproject_position(at) - Vector2(16, 0), BuildDock.SIDE_LABELS[side],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
