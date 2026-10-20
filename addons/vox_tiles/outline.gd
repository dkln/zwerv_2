@tool
extends RefCounted
## Outlines every placed tile of one GridMap layer in the editor, owned by build_tools.gd:
## a wire box around the mesh of each used cell (its real size and rotation), so you
## see where one tile ends and the next begins, also for small details and props.
##
## The boxes are MultiMeshes (a unit wire cube per cell), one per CHUNK x CHUNK metres so
## Godot skips the chunks outside the camera's view, under a Node3D that is a child of
## the GridMap without owner: it moves and hides with the layer and is never saved in
## the scene. It is rebuilt after every edit (the undo history changes).

## Line colour: light blue, stands out on roofs, asphalt, grass and water alike.
const COLOUR := Color(0.35, 0.8, 1.0, 0.9)
## The boxes are this much (metres) larger than the meshes, so the lines lie just outside
## the surfaces instead of flickering in them.
const GROW := 0.01
## Rebuild at most this often (seconds) while edits come in.
const DELAY := 0.15
## Size (metres, horizontally) of the chunks that are culled separately.
const CHUNK := 64.0

var _target: GridMap
var _holder: Node3D               # parent of the chunk MultiMeshInstance3Ds
var _wire: ArrayMesh
var _pending := false
var _local := {}   # item id -> Transform3D from the unit cube to the item's (grown) AABB


## plugin: rebuilds after every edit in its undo history (null: only on set_target).
func _init(plugin: EditorPlugin = null) -> void:
	if plugin:
		plugin.get_undo_redo().version_changed.connect(_schedule)


## Outlines the tiles of `gm` (null: none).
func set_target(gm: GridMap) -> void:
	if gm == _target and (gm == null or (is_instance_valid(_holder) and _holder.get_parent() == gm)):
		return
	_clear()
	_target = gm
	if gm == null:
		return
	if _wire == null:
		_wire = _wire_cube()
	_holder = Node3D.new()
	_holder.name = "VoxTilesOutline"
	gm.add_child(_holder)   # no owner: not saved
	_local.clear()
	_rebuild()


func cleanup() -> void:
	_clear()
	_target = null


func _clear() -> void:
	if is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null


func _schedule() -> void:
	if _pending or _target == null:
		return
	_pending = true
	(Engine.get_main_loop() as SceneTree).create_timer(DELAY).timeout.connect(func() -> void:
		_pending = false
		_rebuild())


## One box per used cell: cell transform * item mesh transform * unit cube -> AABB,
## grouped per chunk into one MultiMeshInstance3D each.
func _rebuild() -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_holder):
		return
	for c in _holder.get_children():
		c.free()
	var lib := _target.mesh_library
	if lib == null:
		return
	var chunks := {}   # Vector2i -> Array of Transform3D
	for cell in _target.get_used_cells():
		var id := _target.get_cell_item(cell)
		if not _local.has(id):
			_local[id] = _item_box(lib, id)
		var pos := _target.map_to_local(cell)
		var key := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		var basis := _target.get_basis_with_orthogonal_index(_target.get_cell_item_orientation(cell))
		chunks[key].append(Transform3D(basis, pos) * _local[id])
	for key in chunks:
		var boxes: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _wire
		mm.instance_count = boxes.size()
		for i in boxes.size():
			mm.set_instance_transform(i, boxes[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_holder.add_child(mmi)


## Transform that maps the unit cube (0..1) onto the grown AABB of item `id`, in the
## item's cell space.
static func _item_box(lib: MeshLibrary, id: int) -> Transform3D:
	var mesh := lib.get_item_mesh(id)
	if mesh == null:
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var box := mesh.get_aabb().grow(GROW)
	return lib.get_item_mesh_transform(id) * Transform3D(Basis.from_scale(box.size), box.position)


## The 12 edges of the unit cube as lines, with an unshaded see-through material.
static func _wire_cube() -> ArrayMesh:
	var v := PackedVector3Array()
	for a in 3:
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		for k in 4:
			var p := Vector3.ZERO
			p[b] = k & 1
			p[c] = k >> 1
			v.append(p)
			p[a] = 1.0
			v.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = COLOUR
	mesh.surface_set_material(0, mat)
	return mesh
