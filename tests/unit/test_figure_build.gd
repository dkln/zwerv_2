extends RefCounted
## Unit tests of building the voxel figures (scripts/player/player_model.gd VoxelFigure,
## scripts/world/townsfolk_figure.gd): only the faces against the air are drawn; faces side
## by side of one colour, material and even shade become one rectangle (merge_faces) that
## looks just as the separate faces did; every corner carries its outward direction for the
## outline and the outline's shell stays closed where merged faces meet in a T; and a
## townsperson built on a thread (TownsfolkFigure.prepare, so a new pedestrian costs no
## stutter) is the same as one built at once.

const PlayerModel = preload("res://scripts/player/player_model.gd")


const PURPLE := Color("#7B3F91")
const GREEN := Color("#2E8B57")


func test_only_faces_against_the_air(test) -> void:
	# a block of 3 x 2 x 2: 6 sides of 2..6 voxel faces, nothing inside
	var figure := PlayerModel.VoxelFigure.new()
	figure.box(Vector3i(0, 0, 0), Vector3i(2, 1, 1), PURPLE)
	figure.merge_faces = false
	var parts := figure.to_parts(0.1, {}, _materials(), PlayerModel.graded)
	test.check(_faces(parts.meshes.body) == 2 * (3 * 2 + 3 * 2 + 2 * 2), "alleen de buitenkant: 32 vlakjes (%d)" % _faces(parts.meshes.body))
	test.check(is_equal_approx(parts.height, 0.2), "de hoogte (%.2f)" % parts.height)


func test_a_block_of_one_colour_is_six_faces(test) -> void:
	var figure := PlayerModel.VoxelFigure.new()
	figure.box(Vector3i(0, 0, 0), Vector3i(3, 5, 2), PURPLE)
	var mesh: ArrayMesh = figure.to_parts(0.1, {}, _materials(), PlayerModel.graded).meshes.body
	test.check(_faces(mesh) == 6, "samengevoegd: één vlak per zijde (%d)" % _faces(mesh))
	test.check(mesh.get_aabb().size.is_equal_approx(Vector3(0.4, 0.6, 0.3)), "even groot (%s)" % mesh.get_aabb().size)


func test_colours_and_materials_stay_apart(test) -> void:
	# two colours of one material side by side, and a block of glass on top
	var figure := PlayerModel.VoxelFigure.new()
	figure.box(Vector3i(0, 0, 0), Vector3i(1, 0, 0), PURPLE)
	figure.box(Vector3i(2, 0, 0), Vector3i(3, 0, 0), GREEN)
	figure.mark("cloth", [PURPLE, GREEN])
	var mesh: ArrayMesh = figure.to_parts(0.1, {}, _materials(), PlayerModel.graded).meshes.body
	# the row of 4 x 1 x 1: top, bottom, front and back each in two, the ends one each
	test.check(_faces(mesh) == 10, "per kleur een eigen vlak: 10 (%d)" % _faces(mesh))
	figure.mark("glass", [GREEN])
	var glassed: ArrayMesh = figure.to_parts(0.1, {}, _materials(), PlayerModel.graded).meshes.body
	test.check(glassed.get_surface_count() == 2, "glas apart (%d oppervlakken)" % glassed.get_surface_count())


func test_merged_looks_the_same(test) -> void:
	# every face of the unmerged figure: covered by the merged one, in the same colour there
	for look_seed in [5, 1234]:
		var merged := _townsperson(look_seed, true)
		var single := _townsperson(look_seed, false)
		var merged_faces := 0
		var single_faces := 0
		var same := true
		var area_same := true
		for part: String in single.meshes:
			var merged_mesh: ArrayMesh = merged.meshes[part]
			var single_mesh: ArrayMesh = single.meshes[part]
			merged_faces += _faces(merged_mesh)
			single_faces += _faces(single_mesh)
			test.check(merged_mesh.get_surface_count() == single_mesh.get_surface_count(), "%s: dezelfde oppervlakken" % part)
			for surface in single_mesh.get_surface_count():
				var merged_arrays := merged_mesh.surface_get_arrays(surface)
				var single_arrays := single_mesh.surface_get_arrays(surface)
				area_same = area_same and is_equal_approx(_area(merged_arrays), _area(single_arrays))
				var single_vertices: PackedVector3Array = single_arrays[Mesh.ARRAY_VERTEX]
				for triangle in range(0, single_vertices.size(), 3):
					var spot := (single_vertices[triangle] + single_vertices[triangle + 1] + single_vertices[triangle + 2]) / 3.0
					var wanted: Variant = _colour_at(single_arrays, spot)
					var found: Variant = _colour_at(merged_arrays, spot)
					same = same and found != null and wanted != null and (found as Color).is_equal_approx(wanted)
		test.check(same, "figuur %d: overal dezelfde kleur en schaduw" % look_seed)
		test.check(area_same, "figuur %d: even veel oppervlak" % look_seed)
		test.check(merged_faces * 2 < single_faces, "figuur %d: %d vlakken in plaats van %d" % [look_seed, merged_faces, single_faces])


func test_the_outline_stays_closed_where_faces_meet(test) -> void:
	# a corner on another face's edge (a T) has the outward direction of that edge there
	var parts := _townsperson(77, true)
	var t_corners := 0
	var closed := true
	var misses := []
	for part: String in parts.meshes:
		var mesh: ArrayMesh = parts.meshes[part]
		var edges := {}   # the axis-aligned edges by the line they lie on
		var corners := []
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var outwards: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
			for index in vertices.size():
				var way := Vector3(outwards[index * 3], outwards[index * 3 + 1], outwards[index * 3 + 2])
				corners.append([_grid(vertices[index]), way])
			for triangle in range(0, vertices.size(), 3):
				for corner_index in 3:
					var first := triangle + corner_index
					var second := triangle + (corner_index + 1) % 3
					var start := _grid(vertices[first])
					var end := _grid(vertices[second])
					var axis := -1
					for candidate in 3:
						if start[candidate] != end[candidate]:
							axis = candidate if axis == -1 else 3
					if axis < 0 or axis > 2:
						continue   # a diagonal
					var start_way := Vector3(outwards[first * 3], outwards[first * 3 + 1], outwards[first * 3 + 2])
					var end_way := Vector3(outwards[second * 3], outwards[second * 3 + 1], outwards[second * 3 + 2])
					if start[axis] > end[axis]:
						var swap := start
						start = end
						end = swap
						var swap_way := start_way
						start_way = end_way
						end_way = swap_way
					var line := start
					line[axis] = -9999 - axis
					if not edges.has(line):
						edges[line] = []
					edges[line].append([start[axis], end[axis], start_way, end_way])
		for corner: Array in corners:
			var point: Vector3i = corner[0]
			for axis in 3:
				var line := point
				line[axis] = -9999 - axis
				for edge: Array in edges.get(line, []):
					if point[axis] > edge[0] and point[axis] < edge[1]:
						t_corners += 1
						var along := float(point[axis] - edge[0]) / float(edge[1] - edge[0])
						var expected: Vector3 = (edge[2] as Vector3).lerp(edge[3], along)
						if expected.distance_to(corner[1]) >= 0.001:
							closed = false
							misses.append("%s %s %s->%s want %s heeft %s" % [part, point, edge[0], edge[1], expected, corner[1]])
	test.check(t_corners > 0, "er zijn T-aansluitingen (%d)" % t_corners)
	test.check(closed, "de omlijning sluit daar aan (%d van %d mis: %s)" % [misses.size(), t_corners, misses.slice(0, 3)])


func test_every_corner_knows_its_way_out(test) -> void:
	var figure := PlayerModel.VoxelFigure.new()
	figure.box(Vector3i(0, 0, 0), Vector3i(1, 1, 1), Color("#7B3F91"))
	var mesh: ArrayMesh = figure.to_parts(0.1, {}, _materials(), PlayerModel.graded).meshes.body
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var outwards: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	test.check(outwards.size() == vertices.size() * 3, "een richting per hoek (CUSTOM0)")
	var middle := mesh.get_aabb().get_center()
	var all_out := true
	for index in vertices.size():
		var way := Vector3(outwards[index * 3], outwards[index * 3 + 1], outwards[index * 3 + 2])
		all_out = all_out and is_equal_approx(way.length(), 1.0) and way.dot(vertices[index] - middle) > 0.0
	test.check(all_out, "elke hoek wijst van het midden af")


func test_a_figure_built_on_a_thread_is_the_same(test) -> void:
	var look := TownsfolkFigure.look_for(424242)
	look["proef"] = "draad"   # a look no one else uses, so it is not built yet
	test.check(not TownsfolkFigure.is_prepared(look), "nog niet gebouwd")
	TownsfolkFigure.prepare(look)
	for attempt in 400:
		if TownsfolkFigure.is_prepared(look):
			break
		OS.delay_msec(5)
	test.check(TownsfolkFigure.is_prepared(look), "op de achtergrond gebouwd")
	var on_thread: Dictionary = TownsfolkFigure.parts_of(look)
	var at_once := PlayerModel.VoxelFigure.parts_from(TownsfolkFigure._faces_of(look), TownsfolkFigure._materials())
	test.check(_describe(on_thread) == _describe(at_once), "dezelfde meshes als meteen gebouwd")


func test_parts_of_waits_for_a_figure_on_its_way(test) -> void:
	var look := TownsfolkFigure.look_for(171717)
	look["proef"] = "wachten"
	TownsfolkFigure.prepare(look)
	var parts: Dictionary = TownsfolkFigure.parts_of(look)   # at once: waits for the thread
	test.check(parts.meshes.has("body") and parts.meshes.has("arm_left"), "lijf en armen")
	test.check(TownsfolkFigure.is_prepared(look), "daarna bewaard")


func _townsperson(look_seed: int, merge: bool) -> Dictionary:
	var figure := PlayerModel.VoxelFigure.new()
	TownsfolkFigure._build_voxels(figure, TownsfolkFigure.look_for(look_seed))
	figure.centre_cell = TownsfolkFigure.CENTRE_CELL
	figure.simplify()
	figure.merge_faces = merge
	return figure.to_parts(TownsfolkFigure.VOXEL, TownsfolkFigure.RIG, _materials(), PlayerModel.graded)


func _faces(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += mesh.surface_get_array_len(surface) / 6
	return count


## A vertex in voxel corners (TownsfolkFigure.VOXEL), as whole numbers.
func _grid(vertex: Vector3) -> Vector3i:
	return Vector3i((vertex / TownsfolkFigure.VOXEL * 2.0).round())   # half voxels: the centre may fall between


func _area(arrays: Array) -> float:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var total := 0.0
	for triangle in range(0, vertices.size(), 3):
		total += (vertices[triangle + 1] - vertices[triangle]).cross(vertices[triangle + 2] - vertices[triangle]).length() * 0.5
	return total


## The colour of the surface at `spot` (interpolated in the triangle it lies in), null if no
## triangle of it holds that spot.
func _colour_at(arrays: Array, spot: Vector3) -> Variant:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for triangle in range(0, vertices.size(), 3):
		var normal := normals[triangle]
		if absf(normal.dot(spot - vertices[triangle])) > 0.0001:
			continue
		var weights := Geometry3D.get_triangle_barycentric_coords(spot, vertices[triangle], vertices[triangle + 1], vertices[triangle + 2])
		if weights.x < -0.0001 or weights.y < -0.0001 or weights.z < -0.0001 or weights == Vector3.ZERO:
			continue
		return colours[triangle] * weights.x + colours[triangle + 1] * weights.y + colours[triangle + 2] * weights.z
	return null


func _materials() -> Dictionary:
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind, true)
	return materials


func _describe(parts: Dictionary) -> String:
	var text := str(parts.height) + str(parts.pivots)
	var names: Array = parts.meshes.keys()
	names.sort()
	for part in names:
		var mesh: ArrayMesh = parts.meshes[part]
		for surface in mesh.get_surface_count():
			text += "%s %d %d;" % [part, mesh.surface_get_material(surface).get_instance_id(), hash(var_to_str(mesh.surface_get_arrays(surface)))]
	return text
