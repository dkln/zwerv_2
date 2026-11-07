extends SceneTree
## Checks how much of what is drawn lies outside the screen. For a few iso views it walks
## every visible GeometryInstance3D whose box touches the camera frustum (so the renderer
## draws it), samples points in that box and counts how many fall inside the frustum. It
## prints per view the triangles drawn, the share of them outside the screen, and the worst
## nodes (much outside the screen and many triangles).
## usage: Godot --headless --script tools/check/offscreen_audit.gd -- [focus_x focus_z]

const Common = preload("res://tools/tool_common.gd")
const VIEW_SIZES := [16.0, 30.0, 60.0, 120.0, 250.0]
## Sample points per axis in a node's box (x and z; y is taken at three heights).
const SAMPLES := 10
const WORST_COUNT := 12

var _scene: Node
## Mesh -> its triangle count (shared meshes are counted once).
var _triangle_cache := {}


func _init() -> void:
	Common.watchdog(self, 550)
	Common.render_size(self, Vector2i(1920, 1080))
	_scene = Common.instantiate(Common.CITY)
	get_root().add_child(_scene)
	_run.call_deferred()


func _run() -> void:
	await Common.wait_for_merge(_scene)
	var focus := Vector3(40 * 4.0, 0, 42 * 4.0)
	if Common.arg_count() > 1:
		focus = Vector3(Common.arg_float(0), 0, Common.arg_float(1))
	for view_size: float in VIEW_SIZES:
		Common.place_iso(_scene, focus, view_size)
		await Common.wait_frames(self, 30)
		_audit_view(view_size)
	quit()


func _audit_view(view_size: float) -> void:
	var cam: Camera3D = _scene.get_node("Camera")
	var planes := cam.get_frustum()
	var total_triangles := 0.0
	var outside_triangles := 0.0
	var drawn := 0
	var rows := []
	for node in _scene.find_children("*", "GeometryInstance3D", true, false):
		var instance := node as GeometryInstance3D
		if not instance.is_visible_in_tree():
			continue
		if instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var box := instance.global_transform * instance.get_aabb()
		if not _box_touches(box, planes):
			continue
		var triangles := _triangles(instance)
		if triangles == 0:
			continue
		drawn += 1
		var inside := _inside_share(box, planes)
		total_triangles += triangles
		outside_triangles += triangles * (1.0 - inside)
		rows.append([triangles * (1.0 - inside), triangles, inside, box.size, _scene.get_path_to(instance)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("\n== view %.0f m: %d instances drawn, %.0fk triangles, %.0f%% of them outside the screen" % [
		view_size, drawn, total_triangles / 1000.0, 100.0 * outside_triangles / maxf(total_triangles, 1.0)])
	for row in rows.slice(0, WORST_COUNT):
		print("  %7.0fk tris  %3.0f%% on screen  box %5.0f x %4.0f x %5.0f  %s" % [
			row[1] / 1000.0, row[2] * 100.0, row[3].x, row[3].y, row[3].z, row[4]])


## Whether the box is not completely behind one of the frustum planes.
func _box_touches(box: AABB, planes: Array[Plane]) -> bool:
	for plane in planes:
		var all_outside := true
		for corner_index in 8:
			if not plane.is_point_over(box.get_endpoint(corner_index)):
				all_outside = false
				break
		if all_outside:
			return false
	return true


## Share of sample points in the box that lie inside the frustum.
func _inside_share(box: AABB, planes: Array[Plane]) -> float:
	var inside := 0
	var count := 0
	for step_x in SAMPLES:
		for step_z in SAMPLES:
			for step_y in 3:
				var point := box.position + box.size * Vector3((step_x + 0.5) / SAMPLES, step_y * 0.5, (step_z + 0.5) / SAMPLES)
				count += 1
				var is_inside := true
				for plane in planes:
					if plane.is_point_over(point):
						is_inside = false
						break
				if is_inside:
					inside += 1
	return float(inside) / count


func _triangles(instance: GeometryInstance3D) -> int:
	if instance is MeshInstance3D:
		return _mesh_triangles((instance as MeshInstance3D).mesh)
	if instance is MultiMeshInstance3D:
		var multimesh := (instance as MultiMeshInstance3D).multimesh
		if multimesh == null:
			return 0
		var instances := multimesh.visible_instance_count if multimesh.visible_instance_count >= 0 else multimesh.instance_count
		return _mesh_triangles(multimesh.mesh) * instances
	return 0


func _mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	if _triangle_cache.has(mesh):
		return _triangle_cache[mesh]
	var triangles := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		triangles += (indices.size() if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	_triangle_cache[mesh] = triangles
	return triangles
