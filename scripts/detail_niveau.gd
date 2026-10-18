extends Node
## Prestaties: schakelt bij het uitzoomen naar grove tiles (minder driehoeken),
## verbergt details en kleine props op afstand en past de schaduwafstand aan het
## zoomniveau aan. Je bewerkt gewoon de normale GridMaps; de grove kopieën worden
## bij het starten automatisch gemaakt.

@export var camera_pad := NodePath("../Camera")
@export var zon_pad := NodePath("../Zon")
@export var lagen: Array[String] = ["Grond", "Gebouwen"]
## Deze lagen worden bij het starten samengevoegd tot grote meshes zonder verborgen
## zijden (scripts/bakker.gd); de GridMap zelf blijft voor botsingen en bewerken.
@export var bakken: Array[String] = ["Gebouwen", "Grond"]
## Lagen waarin tiles even hoog zijn als de cel (bovenkant mag weg onder een buurblok).
@export var boven_verbergen: Array[String] = ["Gebouwen"]
## Vanaf deze zoomgrootte (meter in beeld, zie scripts/iso_camera.gd) worden grove tiles gebruikt.
@export var grof_vanaf := 100.0
## Vanaf deze zoomgrootte de heel grove tiles (blokjes van 25 cm).
@export var heel_grof_vanaf := 130.0
## Vanaf deze zoomgrootte worden de Details-laag en de Props-laag verborgen.
@export var details_tot := 120.0
@export var props_tot := 300.0
## Schaduwafstand = afstand camera-grond + factor * zoomgrootte.
@export var schaduw_factor := 1.0
## Scherptediepte (tilt-shift) schaalt mee met de afstand tot de grond.
@export var scherptediepte := true

const Bakker = preload("res://scripts/bakker.gd")
const Iso = preload("res://scripts/iso_camera.gd")
const CACHE_MAP := "user://samengevoegd"

var _cam: Camera3D
var _zon: DirectionalLight3D
var _paren := []   # [origineel, grof, heel grof]
var _niveau := -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cam = get_node_or_null(camera_pad)
	_zon = get_node_or_null(zon_pad)
	var root := get_parent()
	for naam in lagen:
		var gm := root.get_node_or_null(naam) as GridMap
		if gm == null or gm.mesh_library == null:
			continue
		var paar := [gm]
		for niveau in ["lod", "lod2"]:
			var pad := gm.mesh_library.resource_path.replace(".res", "_" + niveau + ".res")
			if not ResourceLoader.exists(pad):
				paar.append(null)
				continue
			var kopie := GridMap.new()
			kopie.name = naam + "_" + niveau
			kopie.mesh_library = load(pad)
			kopie.cell_size = gm.cell_size
			kopie.cell_octant_size = gm.cell_octant_size
			kopie.cell_center_x = gm.cell_center_x
			kopie.cell_center_y = gm.cell_center_y
			kopie.cell_center_z = gm.cell_center_z
			kopie.transform = gm.transform
			kopie.collision_layer = 0
			kopie.collision_mask = 0
			for c in gm.get_used_cells():
				kopie.set_cell_item(c, gm.get_cell_item(c), gm.get_cell_item_orientation(c))
			kopie.visible = false
			root.add_child.call_deferred(kopie)
			paar.append(kopie)
		_paren.append(paar)
		if naam in bakken:
			_samenvoegen(_paren.size() - 1, naam, gm)


## Vervangt de GridMap-weergave van een laag door samengevoegde meshes (scripts/bakker.gd).
## Gebeurt verdeeld over frames; het resultaat wordt bewaard in user://samengevoegd/
## zodat de volgende start direct klaar is (zolang de kaart en de tiles niet veranderen).
func _samenvoegen(index: int, naam: String, gm: GridMap) -> void:
	var t := Time.get_ticks_msec()
	var data: Dictionary = gm.get("data")
	var root := get_parent()
	var nieuw := []
	for niveau in ["", "_lod", "_lod2"]:
		var pad := gm.mesh_library.resource_path.replace(".res", niveau + ".res")
		if not ResourceLoader.exists(pad):
			nieuw.append(null)
			continue
		var sleutel := "%s_%s%s__%x_%x_%d" % [root.scene_file_path.get_file().get_basename(), naam, niveau,
			hash(data.get("cells", PackedInt32Array())), hash(gm.transform),
			FileAccess.get_modified_time(pad) + Bakker.VERSIE]
		var cache := CACHE_MAP.path_join(sleutel + ".scn")
		var gebakken: Node3D
		if ResourceLoader.exists(cache):
			ResourceLoader.load_threaded_request(cache)
			while ResourceLoader.load_threaded_get_status(cache) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
			var ps := ResourceLoader.load_threaded_get(cache) as PackedScene
			if ps:
				gebakken = ps.instantiate()
		if gebakken == null:
			gebakken = await Bakker.bak(gm, load(pad), naam + "_samengevoegd" + niveau, naam in boven_verbergen)
			if not is_inside_tree():
				return
			_bewaar(gebakken, cache)
		gebakken.visible = false
		root.add_child(gebakken)
		nieuw.append(gebakken)
	if not is_inside_tree():
		return
	var oud: Array = _paren[index]
	_paren[index] = nieuw
	gm.visible = false
	for i in oud.size():
		if oud[i] != null and oud[i] != gm:
			oud[i].queue_free()
	_niveau = -1   # zichtbaarheid opnieuw zetten
	print("%s samengevoegd in %d ms" % [naam, Time.get_ticks_msec() - t])


func _bewaar(node: Node3D, pad: String) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_MAP)
	# oude versies van deze laag (en dit LOD-niveau) opruimen
	var prefix := pad.get_file().split("__")[0] + "__"
	for f in DirAccess.get_files_at(CACHE_MAP):
		if f.begins_with(prefix) and f != pad.get_file():
			DirAccess.remove_absolute(CACHE_MAP.path_join(f))
	for k in node.get_children():
		k.owner = node
	var ps := PackedScene.new()
	ps.pack(node)
	ResourceSaver.save(ps, pad, ResourceSaver.FLAG_COMPRESS)


func _process(_delta: float) -> void:
	if _cam == null:
		return
	var zoom := Iso.grootte(_cam)
	var afstand := Iso.afstand_tot_grond(_cam)
	var niveau := 0
	if zoom > heel_grof_vanaf:
		niveau = 2
	elif zoom > grof_vanaf:
		niveau = 1
	if niveau != _niveau:
		_niveau = niveau
		for p in _paren:
			var keuze := niveau
			while keuze > 0 and p[keuze] == null:
				keuze -= 1
			for i in p.size():
				if p[i] != null:
					p[i].visible = i == keuze
	var root := get_parent()
	var details := root.get_node_or_null("Details")
	if details:
		details.visible = zoom < details_tot
	var props := root.get_node_or_null("Props")
	if props:
		props.visible = zoom < props_tot
	if _zon:
		_zon.directional_shadow_max_distance = afstand + zoom * schaduw_factor
	var attr := _cam.attributes as CameraAttributesPractical
	if attr and scherptediepte:
		attr.dof_blur_far_distance = afstand * 1.1
		attr.dof_blur_far_transition = afstand * 0.47
		attr.dof_blur_near_distance = afstand * 0.83
		attr.dof_blur_near_transition = afstand * 0.37
