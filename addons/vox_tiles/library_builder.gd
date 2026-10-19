@tool
extends RefCounted
## Builds one MeshLibrary per category from all .vox files in assets/tiles/<category>.
## Item IDs stay stable (by name), so existing maps don't break when you add or
## remove tiles.

const TileMetadata = preload("res://addons/vox_tiles/tile_metadata.gd")

const TILE_ROOT := "res://assets/tiles"
const LIB_ROOT := "res://assets/libraries"
const PREVIEW_SIZE := 96

## collision: "trimesh" (exact shape), "box" (bounding box), "none",
## "auto" (buildings: solid blocks get a 4x3x4 m box, hollow/walkable tiles an exact shape)
const CATEGORIES := {
	"grond": {"collision": "trimesh"},
	"gebouwen": {"collision": "auto"},
	"details": {"collision": "none"},
	"props": {"collision": "box"},
}


## res://assets/libraries/<category>.res
static func library_path(cat: String) -> String:
	return LIB_ROOT.path_join(cat + ".res")


## Coarse library of a category: <category>_lod.res or <category>_lod2.res.
static func lod_path(cat: String, level := "lod") -> String:
	return LIB_ROOT.path_join(cat + "_" + level + ".res")


## Tiles lower than this (metres) cast no shadow (roads, pavements, grass, ...).
const SHADOW_MIN_HEIGHT := 0.7


## Appends all tile .vox files below dir_path (recursively) to out; skips the
## coarse `<name>.lod.vox` versions.
static func list_vox(dir_path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				list_vox(dir_path.path_join(f), out)
		elif f.get_extension() == "vox" and not TileMetadata.is_lod_file(f):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()


## Brings the library of a category in line with the tiles on disk: adds new
## tiles, updates changed ones, removes deleted ones, keeps item ids stable
## (registry <category>_ids.json, or a pinned "id" in the tile metadata) and
## rebuilds the coarse libraries.
## changed: Dictionary with paths (res://...vox) that were reimported.
## previews: render palette previews (editor only). force: update every item.
## Returns true if the library was modified and saved.
static func build_category(cat: String, changed: Dictionary, previews: bool, force := false) -> bool:
	var cfg: Dictionary = CATEGORIES[cat]
	var root := TILE_ROOT.path_join(cat)
	var files := PackedStringArray()
	list_vox(root, files)
	files.sort()
	var lib_path := library_path(cat)
	var lib: MeshLibrary = null
	if ResourceLoader.exists(lib_path):
		lib = load(lib_path) as MeshLibrary
	if lib == null:
		lib = MeshLibrary.new()
	var by_name := {}
	var next_id := 0
	for id in lib.get_item_list():
		by_name[lib.get_item_name(id)] = id
		next_id = maxi(next_id, id + 1)
	# fixed name -> id registry: a tile that is briefly missing (e.g. while
	# regenerating) gets the same id when it comes back, so maps stay correct
	var registry := _read_registry(cat)
	for item_name in registry:
		next_id = maxi(next_id, int(registry[item_name]) + 1)
	var registry_changed := false
	var seen := {}
	var dirty := false
	var need_preview: Array[int] = []
	for path in files:
		var key := path.trim_prefix(root + "/").get_basename()
		seen[key] = true
		if not ResourceLoader.exists(path):
			continue # not imported yet
		var mesh := load(path) as Mesh
		if mesh == null:
			continue
		var id: int
		var is_new := not by_name.has(key)
		# an "id" in the tile metadata pins the item id (see tile_metadata.gd)
		var wanted := _wanted_id(path, key, lib, registry)
		if is_new:
			if wanted >= 0:
				id = wanted
			elif registry.has(key) and not lib.get_item_list().has(int(registry[key])):
				id = int(registry[key])
			else:
				id = next_id
			lib.create_item(id)
			lib.set_item_name(id, key)
		else:
			id = by_name[key]
			if wanted >= 0 and wanted != id:
				# move the item; cells in maps that used the old id now show nothing
				lib.remove_item(id)
				id = wanted
				lib.create_item(id)
				lib.set_item_name(id, key)
				is_new = true
				print("Vox Tiles: %s moved to id %d (from metadata)" % [key, id])
			by_name[key] = id
		next_id = maxi(next_id, id + 1)
		if int(registry.get(key, -1)) != id:
			registry[key] = id
			registry_changed = true
		if wanted < 0:
			TileMetadata.store_id(path, id)
		if force or is_new or changed.has(path) or lib.get_item_mesh(id) != mesh:
			lib.set_item_mesh(id, mesh)
			lib.set_item_shapes(id, _shapes(mesh, cfg.collision, key))
			_set_shadow(lib, id, mesh)
			dirty = true
			need_preview.append(id)
		elif previews and lib.get_item_preview(id) == null:
			need_preview.append(id)
	for k in by_name:
		if not seen.has(k):
			lib.remove_item(by_name[k])
			dirty = true
	if previews and need_preview.size() > 0 and Engine.is_editor_hint():
		var meshes: Array[Mesh] = []
		for id in need_preview:
			meshes.append(lib.get_item_mesh(id))
		var tex: Array = EditorInterface.make_mesh_previews(meshes, PREVIEW_SIZE)
		for i in need_preview.size():
			if i < tex.size() and tex[i] != null:
				lib.set_item_preview(need_preview[i], tex[i])
		dirty = true
	for level in ["lod", "lod2"]:
		if dirty or force or not ResourceLoader.exists(lod_path(cat, level)):
			_build_lod(cat, lib, level)
	if registry_changed:
		_write_registry(cat, registry)
	if dirty:
		DirAccess.make_dir_recursive_absolute(LIB_ROOT)
		var err := ResourceSaver.save(lib, lib_path)
		if err != OK:
			push_error("Vox Tiles: could not save %s (%s)" % [lib_path, err])
		else:
			print("Vox Tiles: library '%s' updated (%d items)" % [cat, lib.get_item_list().size()])
	return dirty


## The id from the tile metadata, or -1 if there is none or it is already taken.
static func _wanted_id(path: String, key: String, lib: MeshLibrary, registry: Dictionary) -> int:
	var wanted = TileMetadata.read(path).get("id")
	if wanted == null:
		return -1
	if not (wanted is float or wanted is int) or int(wanted) < 0:
		push_warning("Vox Tiles: %s: \"id\" must be a number >= 0" % TileMetadata.path_for(path))
		return -1
	var id := int(wanted)
	for other in registry:
		if other != key and int(registry[other]) == id:
			push_warning("Vox Tiles: %s wants id %d, but %s already has it" % [key, id, other])
			return -1
	if lib.get_item_list().has(id) and lib.get_item_name(id) != key:
		push_warning("Vox Tiles: %s wants id %d, but %s already has it" % [key, id, lib.get_item_name(id)])
		return -1
	return id


## The name -> id registry of a category.
static func registry_path(cat: String) -> String:
	return LIB_ROOT.path_join(cat + "_ids.json")


static func _read_registry(cat: String) -> Dictionary:
	var f := FileAccess.open(registry_path(cat), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _write_registry(cat: String, registry: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(LIB_ROOT)
	var names := registry.keys()
	names.sort()
	var ordered := {}
	for n in names:
		ordered[n] = int(registry[n])
	var f := FileAccess.open(registry_path(cat), FileAccess.WRITE)
	f.store_string(JSON.stringify(ordered, "\t"))


## Tile name fragments that get an exact collision shape in "auto" mode.
const EXACT := ["hallen/", "parkeergarage", "overkapping", "pilaren", "zuilengang", "poort", "luchtboog",
	"toren_beton", "radiotoren", "_dak", "penthouse", "gevel_", "top_", "toren_spits", "toren_pinakels", "bg_portiek", "verd_loggia"]


## Low tiles (roads, grass) don't cast shadows: cheaper and avoids shadow acne.
static func _set_shadow(lib: MeshLibrary, id: int, mesh: Mesh) -> void:
	if not lib.has_method("set_item_mesh_cast_shadow"):
		return
	var height := mesh.get_aabb().size.y
	var mode := RenderingServer.SHADOW_CASTING_SETTING_ON if height >= SHADOW_MIN_HEIGHT else RenderingServer.SHADOW_CASTING_SETTING_OFF
	lib.set_item_mesh_cast_shadow(id, mode)


## Coarse library with the same item IDs; meshes come from the import's "lod" metadata.
static func _build_lod(cat: String, lib: MeshLibrary, level := "lod") -> void:
	var lod := MeshLibrary.new()
	for id in lib.get_item_list():
		var m := lib.get_item_mesh(id)
		lod.create_item(id)
		lod.set_item_name(id, lib.get_item_name(id))
		if m == null:
			continue
		var coarse: Mesh = m.get_meta(level) if m.has_meta(level) else m
		lod.set_item_mesh(id, coarse)
		_set_shadow(lod, id, m)
	DirAccess.make_dir_recursive_absolute(LIB_ROOT)
	ResourceSaver.save(lod, lod_path(cat, level))


## Collision shapes for an item as [shape, transform], per CATEGORIES mode.
static func _shapes(mesh: Mesh, mode: String, key := "") -> Array:
	if mode == "auto":
		mode = "block"
		for k in EXACT:
			if key.contains(k):
				mode = "trimesh"
				break
	match mode:
		"block":
			var b := BoxShape3D.new()
			b.size = Vector3(4, 3, 4)
			return [b, Transform3D(Basis(), Vector3(0, 1.5, 0))]
		"trimesh":
			var s := mesh.create_trimesh_shape()
			return [s, Transform3D()] if s else []
		"box":
			var aabb := mesh.get_aabb()
			var b := BoxShape3D.new()
			b.size = aabb.size
			return [b, Transform3D(Basis(), aabb.get_center())]
	return []
