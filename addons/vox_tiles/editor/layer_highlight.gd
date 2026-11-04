@tool
extends RefCounted
## Makes clear in the 3D view what the GridMap editor is editing, owned by build_tools.gd:
## - a thin grid over the floor being edited (a plane under the GridMap, without owner,
##   so it is never saved, like the outlines of outline.gd);
## - a card at the top left with the layer, the floor and the tile selected in the palette,
##   with its preview;
## - a thick box of that tile at the cell under the mouse, with the name of the tile that
##   already lies there (any floor of the layer) and of the one you would place.

const Outline = preload("res://addons/vox_tiles/editor/outline.gd")

const ACCENT := Color(1.0, 0.55, 0.05)
const CARD_COLOUR := Color(0.07, 0.08, 0.1, 0.92)
const CARD_POSITION := Vector2(16, 44)
const CARD_WIDTH := 420.0
const CARD_PADDING := 10.0
const TITLE_SIZE := 24
const TEXT_SIZE := 18
const PREVIEW_SIZE := 140.0
const BOX_LINE_WIDTH := 4.0
## The grid reaches this far (metres) past the tiles of the layer.
const GRID_MARGIN := 64.0
## The grid lies this much (metres) above the bottom of the floor, against flickering.
const GRID_LIFT := 0.02
## Pairs of corners (bits x, y, z) of the 12 edges of a box.
const BOX_EDGES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7),
	Vector2i(0, 2), Vector2i(1, 3), Vector2i(4, 6), Vector2i(5, 7),
	Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 colour;
uniform vec2 cell_size;
uniform vec2 origin;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// half the width of a line, in pixels
const float LINE_HALF_WIDTH = 0.6;
const float LINE_ALPHA = 0.55;
const float FLOOR_ALPHA = 0.04;
// the lines fade out when cells are this few pixels wide, or they would run together
const float CELL_PIXELS_GONE = 4.0;
const float CELL_PIXELS_FULL = 16.0;

void fragment() {
	vec2 grid = (world_position.xz - origin) / cell_size;
	vec2 cells_per_pixel = fwidth(grid);
	vec2 pixels_to_line = abs(fract(grid - 0.5) - 0.5) / cells_per_pixel;
	float line = 1.0 - min(min(pixels_to_line.x, pixels_to_line.y) / LINE_HALF_WIDTH, 1.0);
	float cell_pixels = 1.0 / max(cells_per_pixel.x, cells_per_pixel.y);
	line *= smoothstep(CELL_PIXELS_GONE, CELL_PIXELS_FULL, cell_pixels);
	ALBEDO = colour;
	ALPHA = mix(FLOOR_ALPHA, LINE_ALPHA, line);
}
"""

var _target: GridMap
var _level := 0
var _lowest_floor := 0     # lowest and highest floor with tiles (see _update_grid)
var _highest_floor := 0
var _grid: MeshInstance3D
var _grid_material: ShaderMaterial
var _palette_source: Object    # Godot's GridMapEditorPlugin
var _mouse = null              # Vector2 of the mouse in the 3D view, or null


## Highlights this GridMap (null: nothing).
func set_target(gridmap: GridMap) -> void:
	if gridmap == _target and (gridmap == null or is_instance_valid(_grid)):
		return
	cleanup()
	_target = gridmap
	_mouse = null
	if gridmap == null:
		return
	_grid = MeshInstance3D.new()
	_grid.name = "VoxTilesFloorGrid"
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _grid_material == null:
		var shader := Shader.new()
		shader.code = GRID_SHADER
		_grid_material = ShaderMaterial.new()
		_grid_material.shader = shader
		_grid_material.set_shader_parameter("colour", ACCENT)
	_grid.material_override = _grid_material
	gridmap.add_child(_grid)   # no owner: not saved
	_update_grid()


func set_floor(level: int) -> void:
	if level != _level:
		_level = level
		_update_grid()


func set_mouse(position: Vector2) -> void:
	_mouse = position


func cleanup() -> void:
	if is_instance_valid(_grid):
		_grid.queue_free()
	_grid = null
	_target = null


func _update_grid() -> void:
	if _target == null or not is_instance_valid(_grid):
		return
	var cell_size := Vector2(_target.cell_size.x, _target.cell_size.z)
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	var first := true
	for cell: Vector3i in _target.get_used_cells():
		var spot := Vector2(cell.x, cell.z) * cell_size
		low = spot if first else low.min(spot)
		high = spot if first else high.max(spot)
		_lowest_floor = cell.y if first else mini(_lowest_floor, cell.y)
		_highest_floor = cell.y if first else maxi(_highest_floor, cell.y)
		first = false
	var plane := PlaneMesh.new()
	plane.size = high - low + cell_size + Vector2.ONE * GRID_MARGIN * 2.0
	_grid.mesh = plane
	var middle := (low + high + cell_size) * 0.5
	_grid.position = Vector3(middle.x, _level * _target.cell_size.y + GRID_LIFT, middle.y)
	var map_origin := _target.global_position
	_grid_material.set_shader_parameter("cell_size", cell_size)
	_grid_material.set_shader_parameter("origin", Vector2(map_origin.x, map_origin.z))


## Draws the card and the box at the mouse over the 3D view.
func draw(overlay: Control, camera: Camera3D) -> void:
	if _target == null:
		return
	var item := selected_item()
	_draw_box_at_mouse(overlay, camera, item)
	_draw_card(overlay, item)


## The tile selected in the palette of Godot's GridMap editor (-1: none).
func selected_item() -> int:
	if not is_instance_valid(_palette_source):
		var found := EditorInterface.get_base_control().get_tree().root.find_children("*", "GridMapEditorPlugin", true, false)
		_palette_source = found[0] if not found.is_empty() else null
	return _palette_source.get_selected_palette_item() if _palette_source else -1


func _item_name(item: int) -> String:
	return _target.mesh_library.get_item_name(item) if item >= 0 and _target.mesh_library else "no tile selected"


func _draw_card(overlay: Control, item: int) -> void:
	var font := overlay.get_theme_default_font()
	var has_preview := item >= 0 and _target.mesh_library != null and _target.mesh_library.get_item_preview(item) != null
	var height := CARD_PADDING * 3.0 + TITLE_SIZE + TEXT_SIZE + (PREVIEW_SIZE + CARD_PADDING if has_preview else 0.0)
	var card := Rect2(CARD_POSITION, Vector2(CARD_WIDTH, height))
	overlay.draw_rect(card, CARD_COLOUR)
	overlay.draw_rect(card, ACCENT, false, 2.0)
	var metres := _target.global_position.y + _level * _target.cell_size.y
	var at := CARD_POSITION + Vector2(CARD_PADDING, CARD_PADDING + TITLE_SIZE)
	overlay.draw_string(font, at, "%s  ·  floor %d  ·  %.2f m" % [_target.name, _level, metres],
			HORIZONTAL_ALIGNMENT_LEFT, CARD_WIDTH - CARD_PADDING * 2.0, TITLE_SIZE, ACCENT)
	at.y += CARD_PADDING + TEXT_SIZE
	overlay.draw_string(font, at, _item_name(item), HORIZONTAL_ALIGNMENT_LEFT, CARD_WIDTH - CARD_PADDING * 2.0, TEXT_SIZE, Color.WHITE)
	if has_preview:
		var preview_rect := Rect2(at + Vector2(0, CARD_PADDING), Vector2.ONE * PREVIEW_SIZE)
		overlay.draw_texture_rect(_target.mesh_library.get_item_preview(item), preview_rect, false)
		overlay.draw_rect(preview_rect, ACCENT, false, 2.0)


## The cell of this floor that the ray goes through, or null if it misses the floor.
func _cell_on_floor(origin: Vector3, direction: Vector3, level: int) -> Variant:
	var floor_y := _target.global_position.y + level * _target.cell_size.y
	if absf(direction.y) < 0.0001 or (floor_y - origin.y) / direction.y < 0.0:
		return null
	var hit := _target.to_local(origin + direction * ((floor_y - origin.y) / direction.y))
	return Vector3i(floori(hit.x / _target.cell_size.x), level, floori(hit.z / _target.cell_size.z))


## Name of the placed tile the ray points at: on the floor being edited, else the highest
## floor that has one. "" if there is none.
func tile_under_ray(origin: Vector3, direction: Vector3) -> String:
	var floors: Array[int] = [_level]
	for level in range(_highest_floor, _lowest_floor - 1, -1):
		if level != _level:
			floors.append(level)
	for level in floors:
		var cell: Variant = _cell_on_floor(origin, direction, level)
		if cell != null and _target.get_cell_item(cell) >= 0:
			return _item_name(_target.get_cell_item(cell))
	return ""


## A thick box of the selected tile (else of a cell) where the mouse hits the floor, with
## the names of the tile lying there and the selected one.
func _draw_box_at_mouse(overlay: Control, camera: Camera3D, item: int) -> void:
	if _mouse == null or camera == null:
		return
	var origin := camera.project_ray_origin(_mouse)
	var direction := camera.project_ray_normal(_mouse)
	var cell_under_mouse: Variant = _cell_on_floor(origin, direction, _level)
	if cell_under_mouse == null:
		return
	var cell: Vector3i = cell_under_mouse
	var unit_box := Transform3D(Basis.from_scale(_target.cell_size), -_target.cell_size * 0.5)
	if item >= 0 and _target.mesh_library != null and _target.mesh_library.get_item_mesh(item) != null:
		unit_box = Outline._item_box(_target.mesh_library, item)
	var to_world := _target.global_transform * Transform3D(Basis.IDENTITY, _target.map_to_local(cell)) * unit_box
	var corners := PackedVector2Array()
	for corner_index in 8:
		var corner := Vector3(corner_index & 1, (corner_index >> 1) & 1, (corner_index >> 2) & 1)
		if camera.is_position_behind(to_world * corner):
			return
		corners.append(camera.unproject_position(to_world * corner))
	for edge in BOX_EDGES:
		overlay.draw_line(corners[edge.x], corners[edge.y], ACCENT, BOX_LINE_WIDTH, true)
	var placed := tile_under_ray(origin, direction)
	var at: Vector2 = _mouse + Vector2(16, -12)
	if placed != "":
		_draw_label(overlay, at, placed, Color.WHITE)
		at.y += TEXT_SIZE + 4.0
		if item >= 0:
			_draw_label(overlay, at, "place: " + _item_name(item), ACCENT)
	else:
		_draw_label(overlay, at, _item_name(item), ACCENT)


func _draw_label(overlay: Control, at: Vector2, text: String, colour: Color) -> void:
	var font := overlay.get_theme_default_font()
	overlay.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, 4, Color.BLACK)
	overlay.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, colour)
