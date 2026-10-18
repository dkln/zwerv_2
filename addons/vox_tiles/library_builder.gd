@tool
extends RefCounted
## Bouwt per categorie een MeshLibrary uit alle .vox bestanden in assets/tiles/<categorie>.
## Item-ID's blijven stabiel (op naam), zodat bestaande kaarten niet breken als je
## tiles toevoegt of verwijdert.

const TILE_ROOT := "res://assets/tiles"
const LIB_ROOT := "res://assets/libraries"
const PREVIEW_SIZE := 96

## collision: "trimesh" (exacte vorm), "box" (omhullende doos), "none",
## "auto" (gebouwen: dichte blokken krijgen een doos van 4x3x4 m, holle/beloopbare tiles een exacte vorm)
const CATEGORIES := {
	"grond": {"collision": "trimesh"},
	"gebouwen": {"collision": "auto"},
	"details": {"collision": "none"},
	"props": {"collision": "box"},
}


static func library_path(cat: String) -> String:
	return LIB_ROOT.path_join(cat + ".res")


static func lod_path(cat: String, niveau := "lod") -> String:
	return LIB_ROOT.path_join(cat + "_" + niveau + ".res")


## Tiles lager dan dit (meter) werpen geen schaduw (wegen, stoepen, gras, ...).
const SCHADUW_MIN_HOOGTE := 0.7


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
		elif f.get_extension() == "vox":
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()


## changed: Dictionary met paden (res://...vox) die opnieuw geïmporteerd zijn.
## Geeft true terug als de bibliotheek is aangepast en opgeslagen.
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
	# vast register naam -> id: een tile die even ontbreekt (bijv. tijdens het
	# opnieuw genereren) krijgt bij terugkomst dezelfde id, zodat kaarten kloppen
	var register := _lees_register(cat)
	for naam in register:
		next_id = maxi(next_id, int(register[naam]) + 1)
	var register_gewijzigd := false
	var seen := {}
	var dirty := false
	var need_preview: Array[int] = []
	for path in files:
		var key := path.trim_prefix(root + "/").get_basename()
		seen[key] = true
		if not ResourceLoader.exists(path):
			continue # nog niet geïmporteerd
		var mesh := load(path) as Mesh
		if mesh == null:
			continue
		var id: int
		var is_new := not by_name.has(key)
		if is_new:
			if register.has(key) and not lib.get_item_list().has(int(register[key])):
				id = int(register[key])
			else:
				id = next_id
				next_id += 1
			lib.create_item(id)
			lib.set_item_name(id, key)
		else:
			id = by_name[key]
		if int(register.get(key, -1)) != id:
			register[key] = id
			register_gewijzigd = true
		if force or is_new or changed.has(path) or lib.get_item_mesh(id) != mesh:
			lib.set_item_mesh(id, mesh)
			lib.set_item_shapes(id, _shapes(mesh, cfg.collision, key))
			_schaduw(lib, id, mesh)
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
	for niveau in ["lod", "lod2"]:
		if dirty or force or not ResourceLoader.exists(lod_path(cat, niveau)):
			_bouw_lod(cat, lib, niveau)
	if register_gewijzigd:
		_schrijf_register(cat, register)
	if dirty:
		DirAccess.make_dir_recursive_absolute(LIB_ROOT)
		var err := ResourceSaver.save(lib, lib_path)
		if err != OK:
			push_error("Vox Tiles: kon %s niet opslaan (%s)" % [lib_path, err])
		else:
			print("Vox Tiles: bibliotheek '%s' bijgewerkt (%d items)" % [cat, lib.get_item_list().size()])
	return dirty


static func register_path(cat: String) -> String:
	return LIB_ROOT.path_join(cat + "_ids.json")


static func _lees_register(cat: String) -> Dictionary:
	var f := FileAccess.open(register_path(cat), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _schrijf_register(cat: String, register: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(LIB_ROOT)
	var namen := register.keys()
	namen.sort()
	var geordend := {}
	for n in namen:
		geordend[n] = int(register[n])
	var f := FileAccess.open(register_path(cat), FileAccess.WRITE)
	f.store_string(JSON.stringify(geordend, "\t"))


const EXACT := ["hallen/", "parkeergarage", "overkapping", "pilaren", "zuilengang", "poort", "luchtboog",
	"toren_beton", "radiotoren", "_dak", "penthouse", "gevel_", "top_", "toren_spits", "toren_pinakels", "bg_portiek", "verd_loggia"]


static func _schaduw(lib: MeshLibrary, id: int, mesh: Mesh) -> void:
	if not lib.has_method("set_item_mesh_cast_shadow"):
		return
	var hoog := mesh.get_aabb().size.y
	var mode := RenderingServer.SHADOW_CASTING_SETTING_ON if hoog >= SCHADUW_MIN_HOOGTE else RenderingServer.SHADOW_CASTING_SETTING_OFF
	lib.set_item_mesh_cast_shadow(id, mode)


## Grove bibliotheek met dezelfde item-ID's; meshes uit de "lod"-metadata van de import.
static func _bouw_lod(cat: String, lib: MeshLibrary, niveau := "lod") -> void:
	var lod := MeshLibrary.new()
	for id in lib.get_item_list():
		var m := lib.get_item_mesh(id)
		lod.create_item(id)
		lod.set_item_name(id, lib.get_item_name(id))
		if m == null:
			continue
		var grof: Mesh = m.get_meta(niveau) if m.has_meta(niveau) else m
		lod.set_item_mesh(id, grof)
		_schaduw(lod, id, m)
	DirAccess.make_dir_recursive_absolute(LIB_ROOT)
	ResourceSaver.save(lod, lod_path(cat, niveau))


static func _shapes(mesh: Mesh, mode: String, key := "") -> Array:
	if mode == "auto":
		mode = "blok"
		for k in EXACT:
			if key.contains(k):
				mode = "trimesh"
				break
	match mode:
		"blok":
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
