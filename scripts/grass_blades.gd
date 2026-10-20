extends Node3D
## Real grass blades (the "Grassprieten" node): when zoomed in, curved blades grow out of
## the grass tiles around the point the camera looks at, and sway in the wind
## (addons/vox_tiles/materials/grass_blade.gdshader). One blade mesh is drawn many times
## with a MultiMesh per chunk of CHUNK x CHUNK metres; chunks are made around the camera
## focus while zoomed in (and dropped again when out of range), only on grass cells
## (scripts/ground_map.gd, the GrondKaart node). The blades fade in below `show_from`
## metres in view (scripts/iso_camera.gd view size) and cast no shadows. Not in the editor.

const Iso = preload("res://scripts/iso_camera.gd")
## Size of a chunk in metres (a multiple of the 4 m ground cell).
const CHUNK := 8.0
## Ground cell size in metres.
const CELL := 4.0
## Height of the top of a grass tile above its cell (the grass voxels' top).
const GRASS_TOP := 0.375

## Off = no blades (the tour switches them off and on in its shader showcase).
@export var enabled := true
@export var camera_path := NodePath("../Camera")
@export var ground_map_path := NodePath("../GrondKaart")
## Blades per square metre (each chunk holds CHUNK^2 x this many, fewer on non-grass).
@export var density := 220.0
## Blades are shown below this view size (metres in view), fully below `full_from`.
@export var show_from := 45.0
@export var full_from := 30.0
## Blade height (m); each blade gets 0.6 .. 1.3 x this, times the cell's grass height
## (short or tall grass, scripts/ground_map.gd).
@export var blade_height := 0.32
## Width and depth of a blade's square columns (m).
@export var blade_width := 0.03
## Square columns per blade (the steps of the staircase).
const SEGMENTS := 3
## New chunks made per frame at most (so moving the camera doesn't hitch).
const CHUNKS_PER_FRAME := 3

var _cam: Camera3D
var _map: Node
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _chunks := {}   # Vector2i chunk -> MultiMeshInstance3D (null = no grass there)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_cam = get_node_or_null(camera_path)
	_map = get_node_or_null(ground_map_path)
	_material = ShaderMaterial.new()
	_material.shader = load("res://addons/vox_tiles/materials/grass_blade.gdshader")
	_material.set_shader_parameter("blade_height", blade_height * 1.3)
	_mesh = _blade_mesh()
	if _map and _map.has_signal("rebuilt"):
		_map.rebuilt.connect(clear)


## Drops every chunk (the grass cells changed, e.g. another map part was loaded).
func clear() -> void:
	for k in _chunks:
		if _chunks[k]:
			_chunks[k].queue_free()
	_chunks.clear()


func _process(_delta: float) -> void:
	if _cam == null or _map == null:
		return
	var view := Iso.view_size(_cam)
	var grow := 1.0 - smoothstep(full_from, show_from, view)
	_material.set_shader_parameter("grow", grow)
	visible = enabled and grow > 0.0
	if not visible:
		return
	# chunks within the visible part of the ground (plus a margin), around the focus
	var focus := Iso.ground_focus(_cam)
	var radius := view * 0.6
	var lo := Vector2i(floori((focus.x - radius) / CHUNK), floori((focus.z - radius) / CHUNK))
	var hi := Vector2i(floori((focus.x + radius) / CHUNK), floori((focus.z + radius) / CHUNK))
	var wanted := {}
	var made := 0
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var k := Vector2i(cx, cz)
			wanted[k] = true
			if not _chunks.has(k) and made < CHUNKS_PER_FRAME:
				_chunks[k] = _make_chunk(k)
				made += 1
	for k in _chunks.keys():
		if not wanted.has(k):
			if _chunks[k]:
				_chunks[k].queue_free()
			_chunks.erase(k)


## The blades of chunk `k` (a MultiMeshInstance3D), or null if it has no grass.
func _make_chunk(k: Vector2i) -> MultiMeshInstance3D:
	var cells: Dictionary = _map.get("grass_cells")
	var origin := Vector2(k) * CHUNK
	var per_cell := int(CELL * CELL * density)
	# per blade 12 floats of transform (rows of the 3x4 matrix) and 4 of custom data
	var buf := PackedFloat32Array()
	var n := int(CHUNK / CELL)
	for j in n:
		for i in n:
			var cell := Vector2i(floori(origin.x / CELL) + i, floori(origin.y / CELL) + j)
			if not cells.has(cell):
				continue
			var mask: PackedByteArray = cells[cell][0]
			var to_tile: Basis = (cells[cell][1] as Basis).inverse()
			var centre := Vector3(cell.x * CELL + CELL * 0.5, 0.0, cell.y * CELL + CELL * 0.5)
			var mres := int(sqrt(mask.size()))
			var height: float = cells[cell][2]
			var seed := cell.x * 73856093 ^ cell.y * 19349663
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			for b in per_cell:
				var x := cell.x * CELL + rng.randf() * CELL
				var z := cell.y * CELL + rng.randf() * CELL
				# clumps: some places dense, some thin (the same noise for every frame)
				if rng.randf() > _clump(x, z):
					continue
				# only on the grass part of the tile's top (not on a path or the water)
				var local := to_tile * (Vector3(x, 0.0, z) - centre)
				var mx := clampi(floori((local.x + CELL * 0.5) / CELL * mres), 0, mres - 1)
				var mz := clampi(floori((local.z + CELL * 0.5) / CELL * mres), 0, mres - 1)
				if mask[mz * mres + mx] == 0:
					continue
				# turned in quarter turns only, so the faces line up with the voxel tiles
				var basis := Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5)
				var s := (0.6 + rng.randf() * 0.7) * height
				basis = basis.scaled(Vector3(1.0, s, 1.0))
				buf.append_array([basis.x.x, basis.y.x, basis.z.x, x,
					basis.x.y, basis.y.y, basis.z.y, GRASS_TOP,
					basis.x.z, basis.y.z, basis.z.z, z,
					rng.randf(), rng.randf(), 0.0, 0.0])
	if buf.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh
	mm.instance_count = buf.size() / 16
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Chance (0.55 .. 1) that a blade grows at (x, z): soft clumps of about a metre.
func _clump(x: float, z: float) -> float:
	var v := sin(x * 2.1 + sin(z * 1.3)) * sin(z * 1.7 + sin(x * 0.9))
	return 0.55 + 0.45 * clampf(v * 0.5 + 0.6, 0.0, 1.0)


## One blocky blade in the voxel style: SEGMENTS square columns of blade_width x
## blade_width stacked on each other, every next one shifted forward (+z) by a step, so
## the blade bends like a staircase; flat top, no bottom. Vertex colour r = the segment's
## tint (0 = base .. 1 = tip), which grass_blade.gdshader uses instead of a gradient.
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := blade_height * 1.3
	var seg_h := h / SEGMENTS
	var hw := blade_width * 0.5
	for i in SEGMENTS:
		var tint := float(i) / (SEGMENTS - 1)
		var y0 := seg_h * i
		var y1 := seg_h * (i + 1)
		var z := blade_width * 0.6 * i * i   # the staircase
		var lo := Vector3(-hw, y0, z - hw)
		var hi := Vector3(hw, y1, z + hw)
		# four sides and the top of the column
		_quad(st, Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3.BACK, tint)
		_quad(st, Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3.FORWARD, tint)
		_quad(st, Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3.RIGHT, tint)
		_quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), Vector3.LEFT, tint)
		_quad(st, Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3.UP, tint)
	return st.commit()


## Two triangles a-b-c, a-c-d with normal `n` and vertex colour r = `tint`.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, tint: float) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(Color(tint, 0, 0))
		st.set_normal(n)
		st.add_vertex(v)
