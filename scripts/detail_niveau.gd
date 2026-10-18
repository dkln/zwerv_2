extends Node
## Prestaties: schakelt bij het uitzoomen naar grove tiles (minder driehoeken),
## verbergt details en kleine props op afstand en past de schaduwafstand aan het
## zoomniveau aan. Je bewerkt gewoon de normale GridMaps; de grove kopieën worden
## bij het starten automatisch gemaakt.

@export var camera_pad := NodePath("../Camera")
@export var zon_pad := NodePath("../Zon")
@export var lagen: Array[String] = ["Grond", "Gebouwen"]
## Vanaf deze zoomgrootte (meter in beeld, orthografisch) worden grove tiles gebruikt.
@export var grof_vanaf := 140.0
## Vanaf deze zoomgrootte de heel grove tiles (blokjes van 25 cm).
@export var heel_grof_vanaf := 240.0
## Vanaf deze zoomgrootte worden de Details-laag en de Props-laag verborgen.
@export var details_tot := 120.0
@export var props_tot := 300.0
## Schaduwafstand = afstand camera-focus + factor * zoomgrootte.
@export var schaduw_factor := 1.4
@export var camera_afstand := 300.0

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


func _process(_delta: float) -> void:
	if _cam == null:
		return
	var zoom := _cam.size if _cam.projection == Camera3D.PROJECTION_ORTHOGONAL else _cam.global_position.y * 1.5
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
		_zon.directional_shadow_max_distance = camera_afstand + zoom * schaduw_factor
