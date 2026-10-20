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
## Hide other layers: hides the other GridMaps while editing. They are shown
## again before the scene is saved or run (_apply_changes), so it never ends up
## in the scene file.
##
## Stamps: while drawing, the scene root is selected so this plugin receives the
## 3D view input (plugin.gd _handles). Click a start and an end cell on street
## level; the stamp (stamps.gd) is applied to the Grond layer as one undo step.

const BuildDock = preload("res://addons/vox_tiles/build_dock.gd")
const Stamps = preload("res://addons/vox_tiles/stamps.gd")
const EditorView = preload("res://addons/vox_tiles/editor_view.gd")
const Outline = preload("res://addons/vox_tiles/outline.gd")

## layer that stamps are applied to
const STAMP_LAYER := "Grond"
const PREVIEW_FILL := Color(0.3, 0.7, 1.0, 0.25)
const PREVIEW_LINE := Color(0.3, 0.7, 1.0, 0.9)

## The edited scene was marked or unmarked as a Vox Tiles scene.
signal marked_changed

var dock: BuildDock
var _plugin: EditorPlugin
var _active: GridMap
var _outline: Outline
## The editor view (set by plugin.gd); the dock's view switch changes its game_view.
var view: EditorView
var _solo := false
var _hidden: Array[GridMap] = []
var _floor_spin: SpinBox
var _stamping := false
var _start = null          # Vector3i of the first clicked cell, or null
var _hover = null          # Vector3i of the cell under the mouse, or null
var _camera: Camera3D


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
	EditorInterface.get_selection().selection_changed.connect(refresh)


## Disconnects and shows hidden layers again; called when the plugin unloads.
func cleanup() -> void:
	_outline.cleanup()
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
		_show_hidden()
		_active = null
		_outline.set_target(null)
		return
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.size() == 1 and selected[0] is GridMap and selected[0] in _layers():
		_active = selected[0]
	if _active and (not is_instance_valid(_active) or not _active in _layers()):
		_active = null
		_hidden.clear()
	var names := _layers().map(func(gm): return String(gm.name))
	dock.set_layers(names, String(_active.name) if _active else "")
	_outline.set_target(_active if view == null or not view.game_view else null)
	dock.set_game_view(view != null and view.game_view)
	var grond := _grond()
	dock.set_library(grond.mesh_library if grond else null)
	_update_floor_text()
	_update_solo()


## True while drawing a stamp: then this plugin takes the 3D view input.
func handles(object: Object) -> bool:
	return _stamping and object is Node and EditorView.is_marked(EditorInterface.get_edited_scene_root())


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
	var metres := _active.global_position.y + level * _active.cell_size.y
	dock.set_floor_text("Floor %d · %.2f m" % [level, metres])


# ------------------------------------------------------------------ stamps

func _set_stamping(on: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if on and _grond() == null:
		dock.set_stamping(false)
		dock.set_status("This scene has no '%s' layer to stamp on." % STAMP_LAYER)
		return
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
	if not _stamping:
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
