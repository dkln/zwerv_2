extends Node3D
## Real grass blades (the "Grassprieten" node): curved blades grow out of the grass tiles
## around the point the camera looks at, and sway in the wind
## (addons/vox_tiles/materials/grass_blade.gdshader). One blade mesh is drawn many times
## with a MultiMesh per chunk of CHUNK x CHUNK metres; chunks are made around the camera
## focus while zoomed in (and dropped again when out of range), only on grass cells
## (scripts/world/ground_map.gd, the GrondKaart node). They cast no shadows. Not in the editor.
## Three levels of detail by the metres in view (scripts/camera/iso_camera.gd view size),
## growing into each other: the fine blades up close; further out `medium_*` and then
## `far_*`: fewer and thicker tufts in bigger chunks, wide enough not to sparkle, so a zoomed
## out meadow still has grass that moves, at about the same cost per screen.

const Iso = preload("res://scripts/camera/iso_camera.gd")
## Size of a chunk of fine blades in metres (a multiple of the 4 m ground cell).
const CHUNK := 8.0
## Ground cell size in metres.
const CELL := 4.0
## Height of the top of a grass tile above its cell (the grass voxels' top).
const GRASS_TOP := 0.375

## Off = no blades (the tour switches them off and on in its shader showcase).
@export var enabled := true
@export var camera_path := NodePath("../Camera")
@export var ground_map_path := NodePath("../GrondKaart")
## Fine blades per square metre (each chunk holds CHUNK^2 x this many, fewer on non-grass).
@export var density := 220.0
## Fine blades are shown below this view size (metres in view), fully below `full_from`.
## Further out such a blade is narrower than a pixel or two and the grass sparkles as the
## view moves (and costs a lot of frame time): the medium and far tufts take over.
@export var show_from := 24.0
@export var full_from := 16.0
## Blade height (m); each blade gets 0.6 .. 1.3 x this, times the cell's grass height
## (short or tall grass, scripts/world/ground_map.gd).
@export var blade_height := 0.32
## Width and depth of a blade's square columns (m).
@export var blade_width := 0.03
## Medium tufts: per square metre, their width and up to which view size they are shown.
@export var medium_density := 8.0
@export var medium_width := 0.18
@export var medium_until := 55.0
## Far tufts: the same. Off when `far_until` is 0; `low_detail` off = only the fine blades.
@export var far_density := 1.6
@export var far_width := 0.4
@export var far_until := 220.0
@export var low_detail := true
## Square columns per fine blade (the steps of the staircase); per medium and far tuft.
const FINE_SEGMENTS := 3
const MEDIUM_SEGMENTS := 2
const FAR_SEGMENTS := 1
## Chunk sizes of the medium and far tufts (metres, a multiple of the ground cell): a far
## view holds many more square metres.
const MEDIUM_CHUNK := 16.0
const FAR_CHUNK := 32.0
## How far from the focus the chunks of a level reach, as a part of the view size: the fine
## blades only around the focus (they cost the most), the tufts as far as the screen goes, so
## a meadow has no edge where they stop.
const FINE_REACH := 0.6
const LOW_DETAIL_REACH := 1.1
## Where a level starts to fade out, as a part of the view size it ends at.
const FADE_OUT_START := 0.75
## New chunks made per frame at most (so moving the camera doesn't hitch).
const CHUNKS_PER_FRAME := 3

var _cam: Camera3D
var _map: Node
## Per level of detail: its node, mesh, material, chunks (Vector2i chunk ->
## MultiMeshInstance3D, null = no grass there), chunk size, blades per square metre, reach
## and the view sizes between which it grows in and fades out.
var _levels: Array[Dictionary] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_cam = get_node_or_null(camera_path)
	_map = get_node_or_null(ground_map_path)
	_add_level(CHUNK, density, blade_width, FINE_SEGMENTS, FINE_REACH, 0.0, 0.0, full_from, show_from)
	if low_detail:
		_add_level(MEDIUM_CHUNK, medium_density, medium_width, MEDIUM_SEGMENTS, LOW_DETAIL_REACH,
				full_from, show_from, medium_until * FADE_OUT_START, medium_until)
		if far_until > 0.0:
			_add_level(FAR_CHUNK, far_density, far_width, FAR_SEGMENTS, LOW_DETAIL_REACH,
					medium_until * FADE_OUT_START, medium_until, far_until * FADE_OUT_START, far_until)
	if _map and _map.has_signal("rebuilt"):
		_map.rebuilt.connect(clear)


func _add_level(chunk_size: float, blades_per_metre: float, width: float, segments: int, reach: float,
		grow_in_from: float, grow_in_to: float, fade_out_from: float, fade_out_to: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://addons/vox_tiles/materials/grass_blade.gdshader")
	material.set_shader_parameter("blade_height", blade_height * 1.3)
	var level_node := Node3D.new()
	level_node.name = "Niveau%d" % _levels.size()
	add_child(level_node)
	_levels.append({"node": level_node, "mesh": _blade_mesh(width, segments), "material": material, "chunks": {},
		"chunk_size": chunk_size, "density": blades_per_metre, "reach": reach, "grow_in_from": grow_in_from, "grow_in_to": grow_in_to,
		"fade_out_from": fade_out_from, "fade_out_to": fade_out_to})


## Drops every chunk (the grass cells changed, e.g. another map part was loaded).
func clear() -> void:
	for level in _levels:
		_clear_level(level)


func _clear_level(level: Dictionary) -> void:
	var chunks: Dictionary = level.chunks
	for chunk_key in chunks:
		if chunks[chunk_key]:
			chunks[chunk_key].queue_free()
	chunks.clear()


func _process(_delta: float) -> void:
	if _cam == null or _map == null:
		return
	var view := Iso.view_size(_cam)
	for level in _levels:
		var grow := 1.0 - smoothstep(level.fade_out_from, level.fade_out_to, view)
		if level.grow_in_to > 0.0:
			grow *= smoothstep(level.grow_in_from, level.grow_in_to, view)
		(level.material as ShaderMaterial).set_shader_parameter("grow", grow)
		var shown: bool = enabled and grow > 0.0
		(level.node as Node3D).visible = shown
		if shown:
			_update_chunks(level, view)
		elif not (level.chunks as Dictionary).is_empty():
			_clear_level(level)


## Makes the chunks of this level within the visible part of the ground (plus a margin),
## around the focus, a few per frame, and drops the ones out of range.
func _update_chunks(level: Dictionary, view: float) -> void:
	var focus := Iso.ground_focus(_cam)
	var radius: float = view * level.reach
	var chunk_size: float = level.chunk_size
	var chunks: Dictionary = level.chunks
	var low := Vector2i(floori((focus.x - radius) / chunk_size), floori((focus.z - radius) / chunk_size))
	var high := Vector2i(floori((focus.x + radius) / chunk_size), floori((focus.z + radius) / chunk_size))
	var wanted := {}
	var made := 0
	for chunk_z in range(low.y, high.y + 1):
		for chunk_x in range(low.x, high.x + 1):
			var chunk_key := Vector2i(chunk_x, chunk_z)
			wanted[chunk_key] = true
			if not chunks.has(chunk_key) and made < CHUNKS_PER_FRAME:
				chunks[chunk_key] = _make_chunk(level, chunk_key)
				made += 1
	for chunk_key in chunks.keys():
		if not wanted.has(chunk_key):
			if chunks[chunk_key]:
				chunks[chunk_key].queue_free()
			chunks.erase(chunk_key)


## The blades of this chunk of the level (a MultiMeshInstance3D), or null if it has no grass.
func _make_chunk(level: Dictionary, chunk_key: Vector2i) -> MultiMeshInstance3D:
	var cells: Dictionary = _map.get("grass_cells")
	var chunk_size: float = level.chunk_size
	var origin := Vector2(chunk_key) * chunk_size
	var per_cell := int(CELL * CELL * level.density)
	# per blade 12 floats of transform (rows of the 3x4 matrix) and 4 of custom data
	var buf := PackedFloat32Array()
	var cells_across := int(chunk_size / CELL)
	for cell_row in cells_across:
		for cell_column in cells_across:
			var cell := Vector2i(floori(origin.x / CELL) + cell_column, floori(origin.y / CELL) + cell_row)
			if not cells.has(cell):
				continue
			var mask: PackedByteArray = cells[cell][0]
			var to_tile: Basis = (cells[cell][1] as Basis).inverse()
			var centre := Vector3(cell.x * CELL + CELL * 0.5, 0.0, cell.y * CELL + CELL * 0.5)
			var mres := int(sqrt(mask.size()))
			var height: float = cells[cell][2]
			var rng := RandomNumberGenerator.new()
			rng.seed = cell.x * 73856093 ^ cell.y * 19349663
			for blade_index in per_cell:
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
	mm.mesh = level.mesh
	mm.instance_count = buf.size() / 16
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = level.material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(level.node as Node3D).add_child(mmi)
	return mmi


## Chance (0.55 .. 1) that a blade grows at (x, z): soft clumps of about a metre.
func _clump(x: float, z: float) -> float:
	var v := sin(x * 2.1 + sin(z * 1.3)) * sin(z * 1.7 + sin(x * 0.9))
	return 0.55 + 0.45 * clampf(v * 0.5 + 0.6, 0.0, 1.0)


## One blocky blade in the voxel style: `segments` square columns of `width` x `width`
## stacked on each other, every next one shifted forward (+z) by a step, so
## the blade bends like a staircase; flat top, no bottom. Vertex colour r = the segment's
## tint (0 = base .. 1 = tip), which grass_blade.gdshader uses instead of a gradient.
func _blade_mesh(width: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := blade_height * 1.3
	var seg_h := h / segments
	var hw := width * 0.5
	for i in segments:
		# one column alone: the colour halfway up a blade
		var tint := float(i) / (segments - 1) if segments > 1 else 0.5
		var y0 := seg_h * i
		var y1 := seg_h * (i + 1)
		var z := width * 0.6 * i * i   # the staircase
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
