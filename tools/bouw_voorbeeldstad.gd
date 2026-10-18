extends SceneTree
## Bouwt scenes/wereld.tscn: een kleine Nederlandse stad als showcase van alle tiles,
## en scenes/nieuwe_kaart.tscn: een lege kaart met dezelfde opzet.
## gebruik: Godot --headless --script tools/bouw_voorbeeldstad.gd
##
## Coördinaten: x = oost, z = zuid (in grond-tiles van 4 m). Richtingen:
## S/E/N/W = de kant waar de voorkant (gevel, stoeprand, ...) van een tile naar wijst.

const LIB := "res://assets/libraries/%s.res"
const DIR := {"S": 0, "E": 1, "N": 2, "W": 3}
## (voor, rechts) -> draaiing, voor hoekstukken met iets aan de voor- en rechterkant
const HOEK := {"SE": 0, "EN": 1, "NW": 2, "WS": 3}

var grond: GridMap
var gebouwen: GridMap
var details: GridMap
var props: GridMap
var libs := {}
var orient := []
var bezet := {} # grond-cellen (x,z) op niveau 0 die al gevuld zijn
var missing := {}
var gebruikt := {} # "Laag:naam" -> true, voor tiles die in context zijn gebruikt
var tint_kaart: Node3D
var catalogus_start := 0.0


func _init() -> void:
	var wereld := _maak_scene("Wereld")
	_bouw_stad()
	_eigenaar_tint(wereld)
	wereld.set_meta("catalogus_start_m", catalogus_start)
	wereld.set_meta("wijken", wijken)
	_opslaan(wereld, "res://scenes/wereld.tscn")
	var leeg := _maak_scene("NieuweKaart")
	_eigenaar_tint(leeg)
	_opslaan(leeg, "res://scenes/nieuwe_kaart.tscn")
	if missing.size() > 0:
		print("ONTBREKENDE TILES: ", missing.keys())
	quit()


# ------------------------------------------------------------------ scene

func _gridmap(naam: String, lib: String, cell: Vector3, center_xz: bool, y: float) -> GridMap:
	var gm := GridMap.new()
	gm.name = naam
	gm.mesh_library = load(LIB % lib)
	libs[naam] = gm.mesh_library
	gm.cell_size = cell
	gm.cell_center_x = center_xz
	gm.cell_center_z = center_xz
	gm.cell_center_y = false
	gm.position.y = y
	return gm


func _maak_scene(naam: String) -> Node3D:
	var root := Node3D.new()
	root.name = naam
	var env := WorldEnvironment.new()
	env.name = "Omgeving"
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.3, 0.5, 0.85)
	sm.sky_horizon_color = Color(0.7, 0.8, 0.92)
	sm.ground_horizon_color = Color(0.6, 0.65, 0.7)
	sm.ground_bottom_color = Color(0.25, 0.27, 0.3)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.ambient_light_sky_contribution = 0.9
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 1.6
	e.ssao_intensity = 2.2
	e.ssao_power = 1.6
	e.ssao_detail = 0.8
	e.ssao_light_affect = 0.15
	e.ssil_enabled = true
	e.ssil_radius = 6.0
	e.ssil_intensity = 0.9
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_hdr_threshold = 1.2
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.1
	e.fog_enabled = false
	e.fog_light_color = Color(0.7, 0.78, 0.88)
	e.fog_density = 0.0005
	env.environment = e
	root.add_child(env)
	var zon := DirectionalLight3D.new()
	zon.name = "Zon"
	# zon van zuid-zuidoost: in het isometrische beeld (kijkend naar het noordwesten)
	# krijgen zowel de zuid- als de oostgevels licht, met duidelijke schaduwen.
	zon.rotation_degrees = Vector3(-62, 27, 0)
	zon.light_energy = 1.55
	zon.light_color = Color(1.0, 0.93, 0.82)
	zon.shadow_enabled = true
	zon.shadow_bias = 0.03
	zon.shadow_normal_bias = 1.2
	zon.shadow_blur = 1.5
	zon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	zon.directional_shadow_max_distance = 500.0
	zon.directional_shadow_split_1 = 0.35
	zon.directional_shadow_blend_splits = true
	root.add_child(zon)
	# zacht vullicht van de andere kant (zonder schaduw), zodat schaduwzijden niet zwart worden
	var vul := DirectionalLight3D.new()
	vul.name = "Vullicht"
	vul.rotation_degrees = Vector3(-35, 200, 0)
	vul.light_energy = 0.22
	vul.light_color = Color(0.62, 0.74, 1.0)
	vul.shadow_enabled = false
	root.add_child(vul)
	grond = _gridmap("Grond", "grond", Vector3(4, 1, 4), true, 0.0)
	gebouwen = _gridmap("Gebouwen", "gebouwen", Vector3(4, 3, 4), true, 0.375)
	details = _gridmap("Details", "details", Vector3(0.5, 0.5, 0.5), false, 0.375)
	props = _gridmap("Props", "props", Vector3(0.5, 0.5, 0.5), false, 0.25)
	for gm in [grond, gebouwen, details, props]:
		root.add_child(gm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.set_script(load("res://scripts/vrije_camera.gd"))
	# isometrische camera, gericht op het midden van de oude stad
	var focus := Vector3(72, 0, 60)
	cam.position = focus + Vector3(1, 1, 1).normalized() * 300.0
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 140.0
	cam.far = 4000.0
	# scherptediepte (tilt-shift): scherp rond het focuspunt op 300 m, wazig ervoor en erachter
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 330.0
	attr.dof_blur_far_transition = 140.0
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = 250.0
	attr.dof_blur_near_transition = 110.0
	attr.dof_blur_amount = 0.07
	cam.attributes = attr
	root.add_child(cam)
	if naam == "Wereld":
		var rl := Node.new()
		rl.name = "Rondleiding"
		rl.set_script(load("res://scripts/rondleiding.gd"))
		root.add_child(rl)
	var dn := Node.new()
	dn.name = "DetailNiveau"
	dn.set_script(load("res://scripts/detail_niveau.gd"))
	root.add_child(dn)
	var dc := Node.new()
	dc.name = "Dagcyclus"
	dc.set_script(load("res://scripts/dagcyclus.gd"))
	root.add_child(dc)
	var rook := Node3D.new()
	rook.name = "Rook"
	rook.set_script(load("res://scripts/rook.gd"))
	root.add_child(rook)
	var tk := Node3D.new()
	tk.name = "TintKaart"
	tk.set_script(load("res://scripts/tint_kaart.gd"))
	root.add_child(tk)
	tint_kaart = tk
	if naam == "Wereld":
		# voorbeeld: twee panden in het bouwblok een andere tint geven
		for v in [[Vector3(18 * 4 + 2, 0, 11 * 4 + 2), Color(1.0, 0.8, 0.65), Vector2i(2, 1)],
				[Vector3(24 * 4 + 2, 0, 2 * 4 + 2), Color(0.8, 0.85, 1.0), Vector2i(1, 1)],
				[Vector3(37 * 4 + 2, 0, 31 * 4 + 2), Color(1.1, 1.0, 0.8), Vector2i(3, 2)]]:
			var tv := Node3D.new()
			tv.name = "TintVlak"
			tv.set_script(load("res://scripts/tint_vlak.gd"))
			tv.position = v[0]
			tv.set("kleur", v[1])
			tv.set("grootte", v[2])
			tk.add_child(tv)
	for n in root.get_children():
		n.owner = root
	orient.clear()
	for k in 4:
		orient.append(grond.get_orthogonal_index_from_basis(Basis(Vector3.UP, k * PI / 2.0)))
	bezet.clear()
	return root


func _eigenaar_tint(root: Node3D) -> void:
	for tv in tint_kaart.get_children():
		tv.owner = root


func _opslaan(root: Node3D, pad: String) -> void:
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, pad)
	print("opgeslagen: ", pad, " (", err, ")")
	root.free()


func _id(gm: GridMap, naam: String) -> int:
	var id: int = gm.mesh_library.find_item_by_name(naam)
	if id < 0:
		missing[naam] = true
	return id


func _rot(r) -> int:
	if r is String:
		if DIR.has(r):
			return orient[DIR[r]]
		return orient[HOEK[r]]
	return orient[int(r) % 4]


## grond-tile
func G(x: int, z: int, naam: String, r = "S", y := 0) -> void:
	var id := _id(grond, naam)
	gebruikt["Grond:" + naam] = true
	if id >= 0:
		grond.set_cell_item(Vector3i(x, y, z), id, _rot(r))
	if y == 0:
		bezet[Vector2i(x, z)] = true


## gebouw-blok (y = verdieping)
func B(x: int, y: int, z: int, naam: String, r = "S") -> void:
	var id := _id(gebouwen, naam)
	gebruikt["Gebouwen:" + naam] = true
	if id >= 0:
		gebouwen.set_cell_item(Vector3i(x, y, z), id, _rot(r))
	bezet[Vector2i(x, z)] = true


## prop op wereldpositie (meters); hoogte in meters boven straatniveau
func Pr(wx: float, wz: float, naam: String, r = "S", wy := 0.0) -> void:
	var id := _id(props, naam)
	gebruikt["Props:" + naam] = true
	if id >= 0:
		props.set_cell_item(Vector3i(roundi(wx * 2), roundi(wy * 2), roundi(wz * 2)), id, _rot(r))


## detail op wereldpositie (meters); hoogte in meters boven gebouwvoet
func D(wx: float, wz: float, wy: float, naam: String, r = "S") -> void:
	var id := _id(details, naam)
	gebruikt["Details:" + naam] = true
	if id >= 0:
		details.set_cell_item(Vector3i(roundi(wx * 2), roundi(wy * 2), roundi(wz * 2)), id, _rot(r))


func rij(x0: int, x1: int, z: int, naam: String, r = "S", y := 0) -> void:
	for x in range(x0, x1 + 1):
		G(x, z, naam, r, y)


func kolom(x: int, z0: int, z1: int, naam: String, r = "S", y := 0) -> void:
	for z in range(z0, z1 + 1):
		G(x, z, naam, r, y)


# ------------------------------------------------------------------ de stad

const W := 96
const H := 80
const OUD_H := 30  # de oorspronkelijke stad


func _bouw_stad() -> void:
	_gracht()
	_hoofdstraat()
	_noordstraat_en_dwarsstraat()
	_grachtenpanden()
	_bouwblok()
	_plein()
	_modern_blok()
	_kantoor()
	_modern_oost()
	_spoorlijn()
	_park()
	_uitbreiding()
	_vul_gras()


func _gracht() -> void:
	# gracht: water op niveau -2, kademuren op -2 en -1 onder de kades
	for z in range(0, 49):
		bezet[Vector2i(8, z)] = true
		bezet[Vector2i(9, z)] = true
		for x in [8, 9]:
			if z >= 12 and z <= 17:
				continue
			if z == 0:
				continue
			G(x, z, "water/water_gracht", "S", -2)
		for x in [7, 10]:
			G(x, z, "water/kademuur_alg", "S", -2)
			G(x, z, "water/kademuur", "S", -1)
	# brug in de Noordstraat: betonnen brugdek met borstwering aan beide kanten
	G(8, 0, "water/water_gracht", "S", -2)
	G(9, 0, "water/water_gracht", "S", -2)
	G(8, 0, "brug/brug_dek_weg_beide", "E")
	G(9, 0, "brug/brug_dek_weg_beide", "E")
	# bakstenen boogbrug in de Hoofdstraat (op waterniveau geplaatst)
	for x in [8, 9]:
		G(x, 12, "brug/brug_boog_gracht_rand", 3, -2)
		for z in range(13, 17):
			G(x, z, "brug/brug_boog_gracht_midden", 1, -2)
		G(x, 17, "brug/brug_boog_gracht_rand", 1, -2)
		for z in range(12, 18):
			bezet[Vector2i(x, z)] = true
	# kades
	for z in range(1, 49):
		if z >= 12 and z <= 17:
			continue
		G(7, z, "stoep/stoep_kade_klinker" if z % 5 == 0 else "stoep/stoep_kade", "E")
		G(10, z, "stoep/stoep_kade_klinker" if z % 5 == 0 else "stoep/stoep_kade", "W")
	# kadestraten (klinkers) en stoepen langs de panden
	for z in range(1, 49):
		if z >= 12 and z <= 17:
			continue
		G(6, z, "weg/straat_klinkers")
		G(11, z, "weg/straat_klinkers")
		G(5, z, "stoep/stoep_rand", "E")
		G(12, z, "stoep/stoep_rand", "W")
	# bomen, lantaarns, paaltjes en fietsen langs de gracht
	for z in range(1, 49):
		if (z >= 11 and z <= 18) or (z >= 39 and z <= 47):
			continue
		var wz := z * 4.0 + 2.0
		if z % 2 == 0:
			Pr(7 * 4 + 1.5, wz, "bomen/linde")
			Pr(10 * 4 + 2.5, wz, "bomen/linde" if z % 4 else "bomen/plataan")
		else:
			Pr(7 * 4 + 1.0, wz, "verlichting/lantaarn_klassiek")
			Pr(10 * 4 + 3.0, wz, "verlichting/lantaarn_klassiek")
		Pr(7 * 4 + 3.5, wz - 1.0, "paaltjes/bolder")
		Pr(10 * 4 + 0.5, wz + 1.0, "paaltjes/bolder")
		if z % 3 == 0:
			Pr(5 * 4 + 0.5, wz, "paaltjes/amsterdammertje")
			Pr(5 * 4 + 0.5, wz + 1, "paaltjes/amsterdammertje")
			Pr(12 * 4 + 3.5, wz, "paaltjes/amsterdammertje")
		if z % 4 == 1:
			Pr(7 * 4 + 2.5, wz + 0.5, "fietsen/fiets_zwart", "E")
			Pr(7 * 4 + 2.5, wz + 1.0, "fietsen/fiets_rood", "E")
	# boten
	Pr(36.0, 14.0, "water/woonboot", "S", -2.0)
	Pr(36.0, 30.0, "water/sloep", "N", -2.0)
	Pr(35.0, 40.0, "water/roeiboot", "S", -2.0)
	Pr(36.0, 96.0, "water/woonboot", "N", -2.0)
	Pr(36.5, 108.0, "water/roeiboot", "E", -2.0)
	Pr(34.0, 84.0, "water/steiger", "S", -2.0)


func _hoofdstraat() -> void:
	# profiel (z): 12 stoep, 13 fietspad, 14-15 rijstroken, 16 fietspad, 17 stoep
	for x in range(0, W):
		if x == 8 or x == 9:
			continue
		if x == 28 or x == 29 or x == 60 or x == 61:
			continue # kruispunten Dwarsstraat en Dwarsstraat2
		var noord_stoep := "stoep/stoep_goot_rand"
		var zuid_stoep := "stoep/stoep_goot_rand"
		if x == 6 or x == 11:
			G(x, 12, "weg/weg_vlak")
			G(x, 17, "weg/weg_vlak")
		elif x == 5 or x == 12:
			G(x, 12, "stoep/stoep_hoek_buiten", "SE" if x == 5 else "WS")
			G(x, 17, "stoep/stoep_hoek_buiten", "EN" if x == 5 else "NW")
		elif x == 27 or x == 59:
			G(x, 12, "stoep/stoep_hoek_buiten", "SE")
			G(x, 17, "stoep/stoep_hoek_buiten", "EN")
		elif x == 30 or x == 62:
			G(x, 12, "stoep/stoep_hoek_buiten", "WS")
			G(x, 17, "stoep/stoep_hoek_buiten", "NW")
		else:
			G(x, 12, noord_stoep if x % 7 != 3 else "stoep/stoep_goot_kolk", "S")
			G(x, 17, zuid_stoep if x % 7 != 3 else "stoep/stoep_goot_kolk", "N")
		G(x, 13, "fietspad/fietspad_recht", "E")
		G(x, 16, "fietspad/fietspad_recht", "E")
		var tram := x >= 12 and x <= 35
		if tram and x >= 62:
			G(x, 14, "tram/tram_rijstrook_onderbroken_kant", "E")
			G(x, 15, "tram/tram_rijstrook_geen_kant", "W")
		elif tram:
			G(x, 14, "tram/tram_recht", "E")
			G(x, 15, "tram/tram_recht", "E")
		else:
			G(x, 14, "weg/rijstrook_onderbroken_kant", "E")
			G(x, 15, "weg/rijstrook_geen_kant", "W")
	# kruispunt met de Dwarsstraat
	for x in [28, 29]:
		G(x, 12, "weg/zebrapad", "S")
		G(x, 13, "weg/fietsoversteek", "S")
		G(x, 14, "weg/weg_vlak")
		G(x, 15, "weg/weg_vlak")
		G(x, 16, "weg/fietsoversteek", "S")
		G(x, 17, "weg/zebrapad", "S")
	# tramhalte en straatmeubilair
	Pr(20 * 4 + 2, 12 * 4 + 1.5, "ov/abri", "S")
	Pr(23 * 4, 12 * 4 + 1.0, "ov/tramhalte_paal", "S")
	Pr(18 * 4, 17 * 4 + 3.0, "ov/bushokje", "N")
	Pr(16 * 4, 17 * 4 + 3.5, "ov/bushalte_paal", "N")
	for x in range(0, W, 3):
		if x >= 7 and x <= 10:
			continue
		Pr(x * 4 + 2, 12 * 4 + 0.5, "verlichting/lantaarn_dubbel", "E")
		Pr(x * 4 + 2, 17 * 4 + 3.5, "verlichting/lantaarn_modern", "N")
	for x in [14, 24, 33]:
		Pr(x * 4 + 1, 12 * 4 + 3.0, "straat/prullenbak_paal")
		Pr(x * 4 + 3, 17 * 4 + 1.0, "fietsen/fietsenrek_vol", "N")
	Pr(13 * 4 + 1, 17 * 4 + 2, "borden/bord_max_50", "N")
	Pr(1 * 4, 12 * 4 + 2, "borden/bord_bebouwde_kom", "E")
	# verkeerslichten
	Pr(27 * 4 + 3, 12 * 4 + 3.5, "verkeer/verkeerslicht", "N")
	Pr(30 * 4 + 1, 17 * 4 + 0.5, "verkeer/verkeerslicht", "S")
	Pr(27 * 4 + 3.5, 17 * 4 + 0.5, "verkeer/verkeerslicht_fiets", "E")
	Pr(30 * 4 + 0.5, 12 * 4 + 3.5, "verkeer/verkeerslicht_voetganger", "W")
	Pr(30 * 4 + 2, 12 * 4 + 1, "verkeer/verkeerslicht_mast", "W")
	# wegwijzer
	Pr(26 * 4 + 2, 17 * 4 + 2, "borden/wegwijzer", "N")


func _noordstraat_en_dwarsstraat() -> void:
	# Noordstraat (z=0), stoep z=1
	for x in range(0, 33):
		if x == 8 or x == 9:
			continue
		if x == 28 or x == 29:
			G(x, 0, "weg/weg_vlak")
			continue
		G(x, 0, "weg/straat_klinkers" if x < 12 else "weg/weg_vlak", "E")
	G(30, 0, "weg/weg_vlak")
	G(31, 0, "weg/weg_vlak")
	G(32, 0, "weg/zebrapad", "E")
	for x in range(13, 28):
		if x == 27:
			G(x, 1, "stoep/stoep_hoek_buiten", "EN")
		elif x == 13:
			G(x, 1, "stoep/stoep_hoek_buiten", "NW")
		else:
			G(x, 1, "stoep/stoep_rand", "N")
	for x in range(0, 5):
		G(x, 1, "stoep/stoep_rand", "N")
	G(5, 1, "stoep/stoep_hoek_buiten", "EN")
	G(12, 1, "stoep/stoep_hoek_buiten", "NW")
	G(7, 0, "weg/straat_klinkers", "E")
	G(10, 0, "weg/straat_klinkers", "E")
	Pr(15 * 4, 1 * 4 + 1, "borden/bord_max_30", "N")
	Pr(25 * 4, 1 * 4 + 1, "borden/bord_woonerf", "N")
	Pr(4 * 4, 1 * 4 + 1, "borden/bord_eenrichtingsweg", "N")
	# Dwarsstraat (x=28,29), stoepen x=27 en x=30
	for z in range(1, 40):
		if z >= 12 and z <= 17:
			continue
		if z == 10 or z == 19:
			G(28, z, "weg/zebrapad")
			G(29, z, "weg/zebrapad")
		elif z == 11:
			G(28, z, "weg/rijstrook_haaientanden", "N")
			G(29, z, "weg/rijstrook_pijl_rechtdoor", "S")
		else:
			G(28, z, "weg/rijstrook_geen_kant", "N")
			G(29, z, "weg/rijstrook_onderbroken_kant", "S")
		if z == 1:
			G(30, z, "stoep/stoep_hoek_buiten", "NW")
		elif z == 10 or z == 19:
			G(27, z, "stoep/stoep_ribbel", "E")
			G(30, z, "stoep/stoep_ribbel", "W")
		elif z % 4 == 2:
			G(27, z, "stoep/stoep_boomrooster", "E")
			G(30, z, "stoep/stoep_boomrooster", "W")
			Pr(27 * 4 + 2, z * 4 + 2, "bomen/linde" if z < 12 else "bomen/kastanje")
			Pr(30 * 4 + 2, z * 4 + 2, "bomen/linde")
		else:
			if z != 1:
				G(27, z, "stoep/stoep_rand", "E")
			G(30, z, "stoep/stoep_rand", "W")
	Pr(30 * 4 + 1, 10 * 4 + 1, "borden/bord_zebrapad", "W")
	Pr(27 * 4 + 3, 19 * 4 + 3, "borden/bord_zebrapad", "E")
	Pr(27 * 4 + 3, 11 * 4, "borden/bord_voorrang_verlenen", "N")
	Pr(30 * 4 + 1, 22 * 4, "borden/bord_parkeren", "W")
	Pr(30 * 4 + 1, 26 * 4, "paaltjes/laadpaal", "W")
	Pr(27 * 4 + 3, 7 * 4, "straat/brievenbus", "E")


# ------------------------------------------------------------------ grachtenpanden

func _pand(x: int, z: int, voor: String, stijl: String, verdiepingen: int, gevels: Array, gevel_top: String, rnd: int) -> void:
	var p := stijl + "/" + stijl + "_"
	var bg: String = ["bg_deur", "bg_deur", "bg_winkel_luifel", "bg_raam", "bg_winkel"][rnd % 5]
	B(x, 0, z, p + bg, voor)
	for v in range(1, verdiepingen):
		B(x, v, z, p + gevels[(rnd + v) % gevels.size()], voor)
	B(x, verdiepingen, z, p + "gevel_" + gevel_top, voor)


func _grachtenpanden() -> void:
	var stijlen := ["klassiek_rood", "klassiek_donker", "klassiek_geel"]
	var tops := ["trap", "klok", "hals", "tuit"]
	var verd := ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon", "verd_raam", "verd_erker"]
	# west: voorgevel naar het oosten (x=4), achterhuis x=3
	for z in range(2, 12):
		var r := z * 7 + 3
		var stijl: String = stijlen[r % 3]
		var n := 3 + (r % 2)
		_pand(4, z, "E", stijl, n, verd, tops[(z * 3) % 4], r)
		var p := stijl + "/" + stijl + "_"
		for v in range(0, n):
			B(3, v, z, p + ("verd_raam" if v > 0 else "bg_raam"), "W")
		B(3, n, z, p + ("dak_zadel_schoorsteen" if z % 3 == 0 else "dak_zadel"), "S")
		# achtertuintjes
		G(2, z, "natuur/gras_bloemen" if z % 2 else "natuur/gras")
		G(1, z, "natuur/moestuin" if z % 3 == 0 else "natuur/gras")
		G(0, z, "plein/plein_vlonder" if z % 4 == 0 else "natuur/gras")
		Pr(2 * 4 + 0.5, z * 4 + 2, "hekken/schutting_hout", "E")
		if z % 3 == 1:
			Pr(1 * 4 + 2, z * 4 + 2, "bomen/fruitboom")
	# oost: voorgevel naar het westen (x=13), achterhuis x=14
	for zz in range(2, 12) + range(18, 29):
		var r: int = zz * 5 + 1
		var stijl: String = stijlen[(r + 1) % 3]
		var n := 3 + (1 if r % 3 == 0 else 0)
		_pand(13, zz, "W", stijl, n, verd, tops[(zz * 5) % 4], r)
		var p := stijl + "/" + stijl + "_"
		for v in range(0, n):
			B(14, v, zz, p + ("verd_luiken" if v > 0 else "bg_raam"), "E")
		B(14, n, zz, p + "dak_zadel", "S")
		G(15, zz, "stoep/stoep_vol")
	# gevel-details: bloembakken, luifels, vlaggen, klimop
	for z in range(2, 12):
		var wz := z * 4.0 + 1.0
		if z % 2 == 0:
			D(20.0, wz + 1.0, 3.5, "ramen/bloembak", "E")
		if z % 4 == 1:
			D(20.0, wz + 2.0, 6.0, "gevel/vlag", "E")
		if z % 5 == 3:
			D(52.0, z * 4.0 + 2.0, 0.0, "gevel/klimop", "W")
	D(52.0, 22.0, 3.0, "gevel/uithangbord", "W")
	D(20.0, 30.0, 2.5, "gevel/buitenlamp", "E")


# ------------------------------------------------------------------ bouwblok met schuine kappen

func _bouwblok() -> void:
	# ring van 2 diep: x 16..26, z 2..11; binnenhof x 18..24, z 4..9
	var s := "klassiek_rood"
	var p := s + "/" + s + "_"
	var x0 := 16
	var x1 := 26
	var z0 := 2
	var z1 := 11
	var dakvar := ["dak_schuin", "dak_schuin", "dak_schuin_dakkapel", "dak_schuin", "dak_schuin_schoorsteen", "dak_schuin_dakraam", "dak_schuin_zonnepanelen"]
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var buiten_rand := x == x0 or x == x1 or z == z0 or z == z1
			var binnen_rand := x == x0 + 1 or x == x1 - 1 or z == z0 + 1 or z == z1 - 1
			if not buiten_rand and not binnen_rand:
				continue
			var k := (x * 13 + z * 7) % 7
			var voor := ""
			var dak: String = dakvar[k]
			var gevel_bg := "bg_deur" if k % 2 == 0 else "bg_raam"
			var gevel_v: String = ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon"][k % 4]
			if buiten_rand:
				var hoek := ""
				if x == x0 and z == z0: hoek = "NW"
				elif x == x1 and z == z0: hoek = "EN"
				elif x == x0 and z == z1: hoek = "WS"
				elif x == x1 and z == z1: hoek = "SE"
				if hoek != "":
					B(x, 0, z, p + ("bg_winkel_hoek" if z == z1 else "bg_raam_hoek"), hoek)
					B(x, 1, z, p + "verd_raam_hoek", hoek)
					B(x, 2, z, p + "dak_schuin_hoek_buiten", hoek)
					continue
				if z == z0: voor = "N"
				elif z == z1: voor = "S"
				elif x == x0: voor = "W"
				else: voor = "E"
				if z == z1:
					gevel_bg = "bg_winkel_luifel" if k % 3 != 1 else "bg_winkel"
				if z == z1 and x == 21:
					gevel_bg = "bg_poort"
			else:
				# binnenrand: gevels kijken naar de binnenhof
				var hoek := ""
				if x == x0 + 1 and z == z0 + 1: hoek = "SE"
				elif x == x1 - 1 and z == z0 + 1: hoek = "WS"
				elif x == x0 + 1 and z == z1 - 1: hoek = "EN"
				elif x == x1 - 1 and z == z1 - 1: hoek = "NW"
				if hoek != "":
					B(x, 0, z, p + "blok_dicht", "S")
					B(x, 1, z, p + "blok_dicht", "S")
					B(x, 2, z, p + "dak_schuin_hoek_binnen", hoek)
					continue
				if z == z0 + 1: voor = "S"
				elif z == z1 - 1: voor = "N"
				elif x == x0 + 1: voor = "E"
				else: voor = "W"
				gevel_bg = "bg_raam" if k % 2 else "bg_deur"
				if z == z1 - 1 and x == 21:
					gevel_bg = "bg_poort"
				if dak == "dak_schuin_zonnepanelen" or dak == "dak_schuin_dakraam":
					dak = "dak_schuin_dakterras" if k % 2 else "dak_schuin_half_plat"
			B(x, 0, z, p + gevel_bg, voor)
			B(x, 1, z, p + gevel_v, voor)
			B(x, 2, z, p + dak, voor)
	# binnenhof
	for x in range(x0 + 2, x1 - 1):
		for z in range(z0 + 2, z1 - 1):
			var t := "natuur/gras"
			if z == z0 + 2 or z == z1 - 2:
				t = "plein/plein_tegels"
			elif x == 21:
				t = "natuur/pad_grind"
			elif (x + z) % 5 == 0:
				t = "natuur/gras_bloemen"
			G(x, z, t, "S" if x != 21 else "S")
	G(21, z1 - 2, "natuur/pad_grind")
	Pr(19 * 4 + 2, 6 * 4 + 2, "bomen/bloesemboom")
	Pr(24 * 4 + 2, 7 * 4 + 2, "bomen/linde")
	Pr(19 * 4 + 2, 8 * 4 + 2, "straat/picknicktafel", "E")
	Pr(23 * 4, 5 * 4 + 2, "planten/hortensia")
	Pr(20 * 4, 5 * 4 + 2, "hekken/haag", "S")
	Pr(22 * 4 + 2, 9 * 4, "hekken/haag", "S")
	Pr(18 * 4 + 2, 4 * 4 + 2, "fietsen/fietsenrek_vol", "E")
	Pr(24 * 4, 9 * 4, "straat/rolcontainer_groen")
	Pr(24.5 * 4, 9 * 4, "straat/rolcontainer_grijs")
	Pr(20 * 4, 7 * 4 + 2, "planten/plantenbak_hout")
	# luifels en details aan de buitenzijde
	D(17 * 4 + 2.0, 12 * 4.0, 2.0, "luifels/luifel_groen_smal", "S")
	D(26 * 4 + 4.0, 6 * 4 + 2.0, 0.0, "gevel/klimop", "E")
	D(16 * 4.0, 7 * 4 + 2.0, 1.0, "gevel/regenpijp", "W")


# ------------------------------------------------------------------ plein

func _plein() -> void:
	for x in range(16, 27):
		for z in range(18, 26):
			var t := "plein/plein_klinkers"
			if x >= 19 and x <= 23 and z >= 19 and z <= 23:
				t = "plein/plein_patroon" if (x == 21 and z == 21) else "plein/plein_natuursteen"
			elif (x == 17 or x == 25) and (z == 19 or z == 24):
				t = "stoep/stoep_boomrooster"
			G(x, z, t)
	G(16, 18, "plein/plein_dambord")
	Pr(21 * 4 + 2, 21 * 4 + 2, "straat/fontein")
	Pr(24 * 4 + 2, 21 * 4 + 2, "straat/kiosk")
	for pos in [Vector2(17, 19), Vector2(25, 19), Vector2(17, 24), Vector2(25, 24)]:
		Pr(pos.x * 4 + 2, pos.y * 4 + 2, "bomen/linde")
	for x in [19, 23]:
		Pr(x * 4 + 2, 19 * 4, "straat/bank_hout", "S")
		Pr(x * 4 + 2, 24 * 4 + 3, "straat/bank_hout", "N")
	Pr(19 * 4, 21 * 4 + 2, "straat/bank_beton", "E")
	Pr(18 * 4 + 2, 22 * 4, "verlichting/lantaarn_klassiek")
	Pr(24 * 4 + 2, 19 * 4, "verlichting/lantaarn_klassiek")
	Pr(20 * 4, 24 * 4, "verlichting/lantaarn_klassiek")
	Pr(22 * 4 + 2, 18 * 4 + 1, "straat/prullenbak_rond")
	Pr(16 * 4 + 2, 21 * 4, "ov/reclamezuil")
	Pr(26 * 4 + 1, 22 * 4, "straat/vlaggenmast")
	Pr(18 * 4, 25 * 4, "planten/plantenbak_beton")
	Pr(24 * 4, 25 * 4, "planten/plantenbak_beton")
	Pr(21 * 4 + 2, 25 * 4 + 1, "planten/pot_terracotta")
	Pr(17 * 4, 21 * 4, "straat/afvalcontainer_ondergronds")


# ------------------------------------------------------------------ moderne blokken

func _modern_blok() -> void:
	# zuidzijde van het plein: x 16..26, z 26..27
	var stijlen := ["modern_wit", "modern_hout", "modern_donker"]
	for x in range(16, 27):
		var s: String = stijlen[((x - 16) / 4) % 3]
		var p := s + "/" + s + "_"
		var k := x % 4
		for z in [26, 27]:
			var voor := "N" if z == 26 else "S"
			var hoek := ""
			if x == 16: hoek = "NW" if z == 26 else "WS"
			elif x == 26: hoek = "EN" if z == 26 else "SE"
			for v in range(0, 3):
				var naam := ""
				if hoek != "":
					naam = ["bg_raam_hoek", "verd_raam_hoek", "verd_balkon_hoek"][v]
					B(x, v, z, p + naam, hoek)
				else:
					if v == 0:
						naam = ["bg_deur", "bg_raam", "bg_winkel", "bg_garage"][k] if z == 26 else ["bg_deur", "bg_raam", "bg_raam", "bg_garage"][k]
					else:
						naam = ["verd_raam", "verd_balkon", "verd_raam_breed", "verd_frans", "verd_dicht"][(k + v) % 5]
					B(x, v, z, p + naam, voor)
			if hoek != "":
				B(x, 3, z, p + "dak_plat_hoek", hoek)
			else:
				var dak := "dak_plat_rand"
				if z == 27 and k == 1:
					dak = "dak_terras_rand"
				B(x, 3, z, p + dak, voor)
	# achtertuinen
	for x in range(16, 27):
		G(x, 28, "natuur/gras" if x % 3 else "plein/plein_vlonder")
		G(x, 29, "natuur/gras")
		Pr(x * 4 + 2, 29 * 4 + 3.5, "hekken/schutting_hout", "S")
	for x in [17, 21, 25]:
		Pr(x * 4 + 2, 28 * 4 + 2, "planten/struik_bloei")
	# zonnepanelen en schotels op de daken (details-laag, hoogte = bovenkant 3e verdieping)
	for x in [18, 22, 24]:
		D(x * 4 + 2.0, 27 * 4 + 2.0, 9.0, "dak/zonnepanelen", "S")
	D(19 * 4 + 2.0, 26 * 4.0, 7.0, "gevel/airco", "N")
	D(23 * 4 + 2.0, 26 * 4.0, 4.0, "gevel/schotel" if false else "dak/schotel", "N")


func _kantoor() -> void:
	# kantoortoren x 31..32, z 18..20, 6 lagen, voorkant west
	var s := "kantoor_glas"
	var p := s + "/" + s + "_"
	var hoogte := 6
	for x in [31, 32]:
		for z in [18, 19, 20]:
			var hoek := ""
			if x == 31 and z == 18: hoek = "NW"
			elif x == 32 and z == 18: hoek = "EN"
			elif x == 31 and z == 20: hoek = "WS"
			elif x == 32 and z == 20: hoek = "SE"
			var voor := "W" if x == 31 else "E"
			for v in range(0, hoogte):
				if hoek != "":
					var n := "bg_glas_hoek" if v == 0 else ("verd_vliesgevel_hoek" if v % 2 else "verd_band_hoek")
					B(x, v, z, p + n, hoek)
				else:
					var n := ("bg_entree" if x == 31 else "bg_glas") if v == 0 else ("verd_vliesgevel" if v % 2 else "verd_band")
					B(x, v, z, p + n, voor)
			if hoek != "":
				B(x, hoogte, z, p + "dak_plat_hoek", hoek)
			else:
				B(x, hoogte, z, p + "dak_installatie_rand", voor)
	# lager kantoor (beton) ernaast
	var s2 := "kantoor_beton"
	var p2 := s2 + "/" + s2 + "_"
	for x in [31, 32]:
		for z in [22, 23]:
			var hoek := ""
			if x == 31 and z == 22: hoek = "NW"
			elif x == 32 and z == 22: hoek = "EN"
			elif x == 31 and z == 23: hoek = "WS"
			elif x == 32 and z == 23: hoek = "SE"
			for v in range(0, 3):
				B(x, v, z, p2 + ("bg_glas_hoek" if v == 0 else "verd_band_hoek"), hoek)
			B(x, 3, z, p2 + "dak_plat_hoek", hoek)
	for z in [21, 24, 25]:
		G(31, z, "stoep/stoep_vol")
		G(32, z, "stoep/stoep_vol")
	Pr(31 * 4 + 2, 21 * 4 + 2, "planten/boombak")
	Pr(31 * 4 + 1, 24 * 4 + 2, "fietsen/fietsenrek_vol", "E")
	Pr(31 * 4 + 1, 19 * 4 + 2, "paaltjes/paal_rvs")
	Pr(30 * 4 + 3, 18 * 4 + 1, "paaltjes/paal_rvs")


func _modern_oost() -> void:
	# moderne rijtjes x 31..32, z 2..10, voorkant west
	var s := "modern_donker"
	var p := s + "/" + s + "_"
	for z in range(2, 11):
		for x in [31, 32]:
			var hoek := ""
			if z == 2: hoek = "NW" if x == 31 else "EN"
			elif z == 10: hoek = "WS" if x == 31 else "SE"
			var voor := "W" if x == 31 else "E"
			for v in range(0, 3):
				if hoek != "":
					B(x, v, z, p + ["bg_deur_hoek", "verd_raam_hoek", "verd_raam_breed_hoek"][v], hoek)
				else:
					var n: String = ["bg_deur", "bg_garage", "bg_deur", "bg_raam"][z % 4] if v == 0 else ["verd_raam", "verd_balkon", "verd_frans", "verd_raam_breed"][(z + v) % 4]
					B(x, v, z, p + n, voor)
			if hoek != "":
				B(x, 3, z, p + "dak_plat_hoek", hoek)
			else:
				B(x, 3, z, p + ("dak_plat_rand"), voor)
	for z in [11]:
		G(31, z, "natuur/gras")
		G(32, z, "natuur/gras")
	Pr(31 * 4 + 2, 11 * 4 + 2, "planten/struik")
	Pr(32 * 4 + 2, 11 * 4 + 2, "hekken/haag_laag", "S")


# ------------------------------------------------------------------ spoorlijn met viaduct

func _spoorlijn() -> void:
	var sporen := [33, 34]
	for x in sporen:
		# vlak spoor aan de uiteinden
		for z in [0]:
			G(x, z, "spoor/trein_overweg", "E")
		for z in [1, 2, 3, 26, 27, 28, 29]:
			G(x, z, "spoor/trein_recht")
		# helling omhoog (noord -> zuid) naar niveau 5
		for i in range(5):
			var z := 4 + i
			var naam := "helling/helling_brug_trein_recht_rand" if x == 34 else "helling/helling_brug_trein_recht"
			G(x, z, naam, "N", i)
		# brugdek op niveau 5
		for z in range(9, 21):
			G(x, z, "brug/brug_dek_trein_rand", "S" if x == 33 else "N", 5)
		# helling omlaag
		for i in range(5):
			var z := 21 + i
			var naam := "helling/helling_brug_trein_recht_rand" if x == 33 else "helling/helling_brug_trein_recht"
			G(x, z, naam, "S", 4 - i)
		# pijlers
		for z in [10, 19]:
			G(x, z, "brug/brug_pijler_gras", "S", 0)
			for y in range(1, 4):
				G(x, z, "brug/brug_pijler", "S", y)
			G(x, z, "brug/brug_pijler_kop", "S", 4)
		for z in [12, 17]:
			G(x, z, "brug/brug_pijler_stoep", "S", 0)
			for y in range(1, 4):
				G(x, z, "brug/brug_pijler", "S", y)
			G(x, z, "brug/brug_pijler_kop", "S", 4)
		for z in [9, 11, 18, 20]:
			G(x, z, "brug/brug_ligger", "S", 4)
	# onder het viaduct: gras en de Hoofdstraat loopt door (zie _hoofdstraat)
	for x in sporen:
		for z in range(4, 26):
			if z >= 12 and z <= 17:
				continue
			if not bezet.has(Vector2i(x, z)):
				G(x, z, "natuur/gras_hoog")
	# bovenleiding
	for z in range(0, OUD_H, 3):
		var wy := 0.5
		if z >= 9 and z <= 20:
			wy = 5.0
		elif (z >= 4 and z < 9) or (z > 20 and z <= 25):
			continue
		Pr(33 * 4 - 0.5, z * 4 + 2, "spoor/bovenleidingmast", "S", wy)
	# overweg in de Noordstraat
	Pr(32 * 4 + 1, 0 * 4 + 3.5, "spoor/spoorboom", "S")
	Pr(35 * 4 + 3, 0 * 4 + 0.5, "spoor/andreaskruis", "N")
	Pr(32 * 4 + 1, 2 * 4, "spoor/seinpaal", "N")
	G(35, 0, "weg/weg_vlak")
	# perron
	for z in range(26, 30):
		G(32, z, "spoor/perron", "E")
		G(31, z, "spoor/perron_midden")
	G(31, 26, "spoor/perron_trap", "N")
	Pr(31 * 4 + 2, 28 * 4, "ov/abri", "E", 1.0)
	Pr(32 * 4 + 1, 27 * 4, "straat/bank_modern", "E", 1.0)
	Pr(31 * 4 + 3, 29 * 4 + 2, "verlichting/lantaarn_modern", "S", 1.0)
	G(30, 26, "stoep/stoep_vol")
	for z in range(4, 12):
		G(35, z, "natuur/gras")


# ------------------------------------------------------------------ park met vijver

func _park() -> void:
	for x in range(0, 5):
		for z in range(18, OUD_H):
			var t := "natuur/gras"
			if (x + z) % 6 == 0:
				t = "natuur/gras_bloemen"
			G(x, z, t)
	# vijver x 1..4, z 20..25
	for x in [2, 3]:
		G(x, 20, "water/water_oever", "S")
		G(x, 25, "water/water_oever", "N")
		for z in range(21, 25):
			G(x, z, "water/water" if (x + z) % 3 else "water/water_lelies")
	for z in range(21, 25):
		G(1, z, "water/water_oever", "E")
		G(4, z, "water/water_oever", "W")
	G(1, 20, "water/water_oever_hoek_buiten", "SE")
	G(4, 20, "water/water_oever_hoek_buiten", "WS")
	G(1, 25, "water/water_oever_hoek_buiten", "EN")
	G(4, 25, "water/water_oever_hoek_buiten", "NW")
	G(3, 22, "water/water_riet")
	# paden
	for z in range(18, OUD_H):
		if z < 20 or z > 25:
			G(0, z, "natuur/pad_grind")
	kolom(5, 18, 29, "natuur/pad_grind")
	rij(0, 4, 27, "natuur/pad_grind", "E")
	G(5, 27, "natuur/pad_grind")
	G(0, 27, "natuur/pad_grind")
	rij(0, 4, 18, "natuur/pad_zand", "E")
	G(1, 28, "natuur/bloemperk_tulpen")
	G(2, 28, "natuur/bloemperk_tulpen", "E")
	G(3, 28, "natuur/bloemperk_tulpen")
	# kade-stoep voor de park-kant
	kolom(6, 18, 29, "weg/straat_klinkers")
	for z in range(18, OUD_H):
		pass
	Pr(0 * 4 + 2, 23 * 4, "bomen/treurwilg")
	Pr(4 * 4 + 3, 19 * 4, "bomen/eik")
	Pr(1 * 4, 29 * 4, "bomen/den")
	Pr(4 * 4 + 2, 29 * 4 + 1, "bomen/populier")
	Pr(3 * 4 + 2, 29 * 4 + 2, "bomen/populier")
	Pr(2 * 4, 19 * 4, "bomen/berk")
	Pr(1 * 4, 19 * 4 + 2, "bomen/berk")
	Pr(4 * 4 + 2, 26 * 4 + 2, "bomen/herfstboom")
	Pr(5 * 4 + 2, 21 * 4, "bomen/conifeer")
	Pr(5 * 4 + 2, 24 * 4, "bomen/conifeer")
	Pr(0 * 4 + 2, 26 * 4 + 2, "straat/bank_hout", "E")
	Pr(2 * 4 + 2, 26 * 4 + 3, "straat/bank_hout", "N")
	Pr(1 * 4 + 1, 26 * 4, "verlichting/lantaarn_park")
	Pr(4 * 4 + 2, 18 * 4 + 2, "verlichting/lantaarn_park")
	Pr(0 * 4 + 2, 21 * 4, "straat/prullenbak_rond")
	Pr(3 * 4, 25 * 4 + 1, "water/steiger", "N", -0.0)
	Pr(2 * 4, 20 * 4 + 2, "planten/riet")
	Pr(4 * 4 + 1, 23 * 4, "planten/riet")
	Pr(3 * 4 + 2, 27 * 4 + 2, "planten/struik_bloei")
	Pr(5 * 4 + 2, 26 * 4 + 2, "water/reddingsboei")
	Pr(0 * 4 + 2, 28 * 4 + 2, "planten/graspol")
	Pr(2 * 4 + 2, 27 * 4 + 1, "planten/varen")


func _vul_gras() -> void:
	for x in range(0, W):
		for z in range(0, H):
			if not bezet.has(Vector2i(x, z)):
				G(x, z, "natuur/gras")


# ==================================================================
# UITBREIDING: herbruikbare bouwhelpers + nieuwe wijken (x 36..95, z 30..79)
# ==================================================================

const ORDE := ["S", "E", "N", "W"]


func _draai(d: String, k: int) -> String:
	return ORDE[(ORDE.find(d) + k) % 4]


func _r(a: int, b: int, n: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995) % maxi(n, 1)


func _heeft(naam: String, gm: GridMap = null) -> bool:
	var g := gm if gm else gebouwen
	return g.mesh_library.find_item_by_name(naam) >= 0


func _zijden(x: int, z: int, x0: int, z0: int, w: int, d: int) -> Array:
	var s := []
	if z == z0: s.append("N")
	if z == z0 + d - 1: s.append("S")
	if x == x0: s.append("W")
	if x == x0 + w - 1: s.append("E")
	return s


func _hoekpaar(sides: Array, voor: String) -> String:
	var kand := []
	for key in ["SE", "EN", "NW", "WS"]:
		if sides.has(key[0]) and sides.has(key[1]):
			kand.append(key)
	for key in kand:
		if key[0] == voor:
			return key
	return kand[0] if kand.size() > 0 else ""


## Plat dak op een cel, gekozen op basis van de vrije zijden.
func _plat_dak(x: int, y: int, z: int, p: String, sides: Array, extra := "") -> void:
	var n := sides.size()
	if n == 0:
		B(x, y, z, p + (extra if extra != "" else "dak_plat_midden"), "S")
	elif n == 1:
		B(x, y, z, p + "dak_plat_rand", sides[0])
	elif n == 2:
		var key := _hoekpaar(sides, "")
		if key != "":
			B(x, y, z, p + "dak_plat_hoek", HOEK[key])
		else:
			B(x, y, z, p + "dak_plat_tegenover", "S" if sides.has("N") else "E")
	elif n == 3:
		var mis := ""
		for d in ORDE:
			if not sides.has(d):
				mis = d
		B(x, y, z, p + "dak_plat_eind", (ORDE.find(mis) + 1) % 4)
	else:
		B(x, y, z, p + ("dak_plat_los" if _heeft(p + "dak_plat_los") else "dak_plat_eind"), "S")


## Rechthoekig gebouw. opts: voor, bg (Array), bg_zij, bg_hoek, verd (Array), verd_hoek,
## dak ("plat"/"schuin"/"zadel"/"kroonlijst"/"kantelen"/"geen"), dak_extra (Array), top, y0, gat (Array van Vector2i zonder dak)
func blok(x0: int, z0: int, w: int, d: int, stijl: String, lagen: int, opts := {}) -> void:
	var p := stijl + "/" + stijl + "_"
	var voor: String = opts.get("voor", "S")
	var bg: Array = opts.get("bg", ["bg_raam"])
	var bg_zij: String = opts.get("bg_zij", bg[0])
	var bg_hoek: String = opts.get("bg_hoek", "bg_raam_hoek")
	var verd: Array = opts.get("verd", ["verd_raam"])
	var verd_hoek: String = opts.get("verd_hoek", "verd_raam_hoek")
	var dak: String = opts.get("dak", "plat")
	var dak_extra: Array = opts.get("dak_extra", [])
	var top: String = opts.get("top", "")
	var y0: int = opts.get("y0", 0)
	var gat: Array = opts.get("gat", [])
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides := _zijden(x, z, x0, z0, w, d)
			for v in range(lagen):
				var naam := "blok_dicht"
				var rot = "S"
				if sides.size() == 0:
					pass
				elif sides.size() == 1 or (sides.size() == 2 and _hoekpaar(sides, voor) == ""):
					var s: String = voor if sides.has(voor) else sides[0]
					if v == 0:
						naam = bg[_r(x, z, bg.size())] if s == voor else bg_zij
					else:
						naam = verd[_r(x * 7 + v, z, verd.size())]
					rot = s
				else:
					var key := _hoekpaar(sides, voor)
					naam = bg_hoek if v == 0 else verd_hoek
					rot = HOEK[key]
				B(x, y0 + v, z, p + naam, rot)
			var yd := y0 + lagen
			if gat.has(Vector2i(x, z)):
				continue
			if top != "" and sides.has(voor):
				B(x, yd, z, p + top, voor)
				continue
			match dak:
				"plat":
					_plat_dak(x, yd, z, p, sides)
				"kroonlijst", "kantelen":
					var basis := "dak_plat_kroonlijst_" if dak == "kroonlijst" else "dak_kantelen_"
					if not _heeft(p + basis + "rand"):
						basis = "dak_kroonlijst_"
					if sides.size() == 1:
						B(x, yd, z, p + basis + "rand", sides[0])
					elif sides.size() >= 2 and _hoekpaar(sides, voor) != "":
						B(x, yd, z, p + basis + "hoek", HOEK[_hoekpaar(sides, voor)])
					else:
						B(x, yd, z, p + "dak_plat_midden", "S")
				"schuin":
					var outs := []
					for s in sides:
						outs.append(s)
					if outs.size() == 1:
						var nm := "dak_schuin"
						if dak_extra.size() > 0 and _r(x, z * 3, 3) == 0:
							nm = dak_extra[_r(x, z, dak_extra.size())]
						B(x, yd, z, p + nm, outs[0])
					elif _hoekpaar(outs, voor) != "":
						B(x, yd, z, p + "dak_schuin_hoek_buiten", HOEK[_hoekpaar(outs, voor)])
					else:
						B(x, yd, z, p + "dak_plat_midden", "S")
				"zadel":
					var langs_x := voor == "N" or voor == "S"
					var eind_a := (x == x0) if langs_x else (z == z0)
					var eind_b := (x == x0 + w - 1) if langs_x else (z == z0 + d - 1)
					if langs_x:
						if eind_b: B(x, yd, z, p + "dak_zadel_schild", "S")
						elif eind_a: B(x, yd, z, p + "dak_zadel_schild", "N")
						else: B(x, yd, z, p + "dak_zadel", "S")
					else:
						if eind_a: B(x, yd, z, p + "dak_zadel_schild", "E")
						elif eind_b: B(x, yd, z, p + "dak_zadel_schild", "W")
						else: B(x, yd, z, p + "dak_zadel", "E")


## Gesloten bouwblok (ring van 2 diep) met schuine kappen die om de hoeken lopen.
func ring(x0: int, z0: int, w: int, d: int, stijl: String, lagen: int, opts := {}) -> void:
	var p := stijl + "/" + stijl + "_"
	var bg: Array = opts.get("bg", ["bg_raam"])
	var verd: Array = opts.get("verd", ["verd_raam"])
	var achter: Array = opts.get("achter", ["verd_raam"])
	var dakvar: Array = opts.get("dak_extra", [])
	var x1 := x0 + w - 1
	var z1 := z0 + d - 1
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var buiten := x == x0 or x == x1 or z == z0 or z == z1
			var binnen := not buiten and (x == x0 + 1 or x == x1 - 1 or z == z0 + 1 or z == z1 - 1)
			if not buiten and not binnen:
				continue
			if buiten:
				var sides := _zijden(x, z, x0, z0, w, d)
				var key := _hoekpaar(sides, "") if sides.size() == 2 else ""
				for v in range(lagen):
					if key != "":
						B(x, v, z, p + ("bg_raam_hoek" if v == 0 else "verd_raam_hoek"), HOEK[key])
					else:
						var nm: String = bg[_r(x, z, bg.size())] if v == 0 else verd[_r(x + v, z, verd.size())]
						B(x, v, z, p + nm, sides[0])
				if key != "":
					B(x, lagen, z, p + "dak_schuin_hoek_buiten", HOEK[key])
				else:
					var dn := "dak_schuin"
					if dakvar.size() > 0 and _r(x, z, 3) == 0:
						dn = dakvar[_r(z, x, dakvar.size())]
					B(x, lagen, z, p + dn, sides[0])
			else:
				var hof := []
				if z == z0 + 1 and x > x0 + 1 and x < x1 - 1: hof.append("S")
				if z == z1 - 1 and x > x0 + 1 and x < x1 - 1: hof.append("N")
				if x == x0 + 1 and z > z0 + 1 and z < z1 - 1: hof.append("E")
				if x == x1 - 1 and z > z0 + 1 and z < z1 - 1: hof.append("W")
				if hof.size() == 0:
					var dk := ""
					if x == x0 + 1 and z == z0 + 1: dk = "SE"
					elif x == x1 - 1 and z == z0 + 1: dk = "WS"
					elif x == x0 + 1 and z == z1 - 1: dk = "EN"
					else: dk = "NW"
					for v in range(lagen):
						B(x, v, z, p + "blok_dicht", "S")
					B(x, lagen, z, p + "dak_schuin_hoek_binnen", dk)
				else:
					for v in range(lagen):
						B(x, v, z, p + achter[_r(x + v, z, achter.size())], hof[0])
					B(x, lagen, z, p + "dak_schuin", hof[0])


## Toren van gestapelde onderdelen (lijst van namen, onderaan eerst).
func toren(x: int, z: int, stijl: String, delen: Array, rot = "S", y0 := 0) -> void:
	var p := stijl + "/" + stijl + "_"
	for i in delen.size():
		B(x, y0 + i, z, p + delen[i], rot)


## Straat-profiel langs x: Array van [z, tile, rot] van noord naar zuid.
func profiel_x(x0: int, x1: int, rijen: Array, skip := []) -> void:
	for x in range(x0, x1 + 1):
		if skip.has(x):
			continue
		for r in rijen:
			G(x, r[0], r[1], r[2])


func profiel_z(z0: int, z1: int, kolommen: Array, skip := []) -> void:
	for z in range(z0, z1 + 1):
		if skip.has(z):
			continue
		for c in kolommen:
			G(c[0], z, c[1], c[2])


func vlak(x0: int, z0: int, x1: int, z1: int, naam: String, rot = "S", y := 0) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			G(x, z, naam, rot, y)


# ------------------------------------------------------------------ de nieuwe wijken

func _uitbreiding() -> void:
	_kerkstraat_en_dwarsstraat2()
	_zuidweg()
	_kerken_en_school()
	_museum_en_raadhuis()
	_jaren30_wijk()
	_herenhuizen()
	_kleine_kerken()
	_hoogbouw()
	_zwemmen_en_hallen()
	_rivier_en_bruggen()
	_jaren60_wijk()
	_boerderij_en_bedrijven()
	_zuidoost()
	_snelweg_en_tunnel()
	_spoor_einde()
	_voetgangersbrug()
	_versiering()
	_campus()
	var z_eind := _demowijken(100)
	catalogus_start = (z_eind + 4) * 4.0
	tint_kaart.set("gebied_cellen", Vector2i(W, z_eind + 4))
	# schaalmodel: een persoon van 1,80 m op een paar plekken
	for pos in [Vector2(70.5, 17.5), Vector2(28.5, 12.5), Vector2(61.0, 47.5), Vector2(87.0, 33.0)]:
		Pr(pos.x * 4, pos.y * 4, "overig/persoon_1m80", "S")


func _kerkstraat_en_dwarsstraat2() -> void:
	# Kerkstraat (z=0) en stoep (z=1) van x 36 tot 95
	for x in range(36, W):
		if x == 60 or x == 61:
			G(x, 0, "weg/kruising_stop")
			continue
		G(x, 0, "weg/rijstrook_onderbroken_geen" if x % 2 else "weg/weg_vlak", "E")
		if x == 59:
			G(x, 1, "stoep/stoep_hoek_buiten", "EN")
		elif x == 62:
			G(x, 1, "stoep/stoep_hoek_buiten", "NW")
		else:
			G(x, 1, "stoep/stoep_rand", "N")
	Pr(45 * 4, 1 * 4 + 1, "borden/bord_max_30", "N")
	Pr(70 * 4, 1 * 4 + 1, "borden/bord_drempel", "N")
	G(72, 0, "weg/drempel_plateau", "E")
	G(48, 0, "weg/drempel_punaise", "E")
	# Dwarsstraat2 (x 60,61) met stoepen 59 en 62, van z 2 tot 39
	for z in range(2, 40):
		if z >= 12 and z <= 17:
			continue
		var stoep_w := "stoep/stoep_goot_rand"
		if z == 10 or z == 20:
			G(60, z, "weg/zebrapad")
			G(61, z, "weg/zebrapad")
			G(59, z, "stoep/stoep_ribbel", "E")
			G(62, z, "stoep/stoep_ribbel", "W")
			continue
		if z == 11:
			G(60, z, "weg/rijstrook_stop_tekst", "N")
			G(61, z, "weg/rijstrook_pijl_rechtdoor_rechts", "S")
		elif z == 18:
			G(60, z, "weg/rijstrook_pijl_links", "N")
			G(61, z, "weg/rijstrook_stopstreep", "S")
		elif z % 7 == 3:
			G(60, z, "weg/drempel_bus", "N")
			G(61, z, "weg/drempel_bus", "S")
		else:
			G(60, z, "weg/rijstrook_geen_kant", "N")
			G(61, z, "weg/rijstrook_doorgetrokken_dubbel" if z > 30 else "weg/rijstrook_onderbroken_kant", "S")
		G(59, z, "stoep/stoep_goot_kolk" if z % 9 == 4 else stoep_w, "E")
		G(62, z, stoep_w, "W")
		if z % 4 == 2:
			Pr(59 * 4 + 1, z * 4 + 2, "verlichting/lantaarn_modern", "W")
			Pr(62 * 4 + 3, z * 4 + 2, "bomen/linde")
	# kruispunt met de Hoofdstraat: verkeerslichten voor auto, fiets, bus en voetganger
	for x in [60, 61]:
		G(x, 12, "weg/zebrapad")
		G(x, 13, "weg/fietsoversteek")
		G(x, 14, "weg/kruis_markering")
		G(x, 15, "weg/weg_vlak")
		G(x, 16, "weg/fietsoversteek")
		G(x, 17, "weg/zebrapad")
	Pr(59 * 4 + 3, 12 * 4 + 3.5, "verkeer/verkeerslicht_set", "N")
	Pr(62 * 4 + 1, 17 * 4 + 0.5, "verkeer/verkeerslicht_set", "S")
	Pr(62 * 4 + 0.5, 12 * 4 + 3.5, "verkeer/verkeerslicht_bus", "W")
	Pr(59 * 4 + 3.5, 17 * 4 + 0.5, "verkeer/verkeerslicht_bus", "E")
	Pr(59 * 4 + 2, 13 * 4 + 1, "verkeer/drukknop_fiets", "E")
	Pr(62 * 4 + 2, 16 * 4 + 3, "verkeer/drukknop_fiets", "W")
	Pr(59 * 4 + 1, 12 * 4 + 1, "verkeer/drukknop_voetganger", "N")
	Pr(62 * 4 + 3, 17 * 4 + 3, "verkeer/drukknop_voetganger", "S")
	Pr(59 * 4 + 1, 11 * 4, "borden/bord_stop" if false else "borden/bord_voorrangskruispunt", "N")
	Pr(62 * 4 + 3, 19 * 4, "borden/bord_verplicht_rechtsaf", "S")
	# tram-bovenleiding langs de Hoofdstraat
	for x in range(40, W, 6):
		Pr(x * 4, 12 * 4 + 3.5, "ov/tram_bovenleiding_mast", "N")


func _zuidweg() -> void:
	# profiel z: 40 stoep, 41 fietspad, 42 rijstrook west, 43 rijstrook oost, 44 busstrook oost, 45 fietspad, 46 stoep
	for x in range(0, W):
		if x == 8 or x == 9:
			G(x, 40, "brug/brug_dek_weg_rand", "W")
			for z in range(41, 46):
				G(x, z, "brug/brug_dek_weg_midden", "E")
			G(x, 46, "brug/brug_dek_weg_rand", "E")
			continue
		if x == 28 or x == 29 or x == 60 or x == 61:
			G(x, 40, "weg/zebrapad")
			G(x, 41, "weg/fietsoversteek")
			G(x, 42, "weg/weg_vlak")
			G(x, 43, "weg/weg_vlak")
			G(x, 44, "weg/weg_vlak")
			G(x, 45, "weg/fietsoversteek")
			G(x, 46, "stoep/stoep_goot_rand", "N")
			continue
		var noord := "stoep/stoep_goot_rand"
		if x == 27 or x == 59:
			noord = "stoep/stoep_hoek_buiten"
			G(x, 40, noord, "SE")
		elif x == 30 or x == 62:
			G(x, 40, "stoep/stoep_hoek_buiten", "WS")
		elif x == 6 or x == 11:
			G(x, 40, "weg/weg_vlak")
		else:
			G(x, 40, noord, "S")
		G(x, 41, "fietspad/fietspad_recht", "E")
		G(x, 42, "weg/rijstrook_onderbroken_kant", "E")
		G(x, 43, "weg/rijstrook_geen_geen", "W")
		var bus := "weg/rijstrook_bus_leeg"
		if x % 16 == 3:
			bus = "weg/rijstrook_bus"
		elif x == 20 or x == 50:
			bus = "weg/busstrook_halte"
		G(x, 44, bus, "W")
		G(x, 45, "fietspad/fietspad_recht", "E")
		G(x, 46, "stoep/stoep_goot_rand", "N")
	# middenberm-lantaarns, bushaltes, borden
	for x in range(2, W, 8):
		Pr(x * 4 + 2, 43 * 4, "verlichting/lantaarn_middenberm", "E")
	Pr(20 * 4, 46 * 4 + 2, "ov/abri", "N")
	Pr(50 * 4, 46 * 4 + 2, "ov/bushokje", "N")
	Pr(22 * 4, 46 * 4 + 3, "ov/bushalte_paal", "N")
	Pr(52 * 4, 46 * 4 + 3, "ov/bushalte_paal", "N")
	Pr(14 * 4, 46 * 4 + 3, "borden/bord_busbaan", "W")
	Pr(70 * 4, 40 * 4 + 1, "borden/bord_max_50", "E")
	Pr(80 * 4, 46 * 4 + 3, "borden/bord_informatie", "W")
	Pr(90 * 4, 40 * 4 + 1, "borden/bord_ziekenhuis", "E")
	Pr(66 * 4, 40 * 4 + 1, "verkeer/wegafzetting_paal_flitser", "E")
	# verkeerszuilen op de middengeleider bij de kruising
	for x in [27, 30, 59, 62]:
		Pr(x * 4 + 2, 43 * 4, "verkeer/verkeerszuil", "E")


func _kerken_en_school() -> void:
	# kathedraal (kerk_steen) x 36..45, z 3..10, voorgevel naar het westen
	var k := "kerk_steen"
	var p := k + "/" + k + "_"
	vlak(36, 2, 45, 11, "plein/plein_natuursteen")
	# schip (2 diep) x 38..45, z 5..6, drie lagen hoog
	for x in range(38, 46):
		for z in [5, 6]:
			var naar := "N" if z == 5 else "S"
			B(x, 0, z, p + "blok_dicht", "S")
			B(x, 1, z, p + "verd_spitsraam", naar)
			B(x, 2, z, p + "verd_spitsraam", naar)
			B(x, 3, z, p + ("dak_schuin_hoek_buiten" if x == 45 else "dak_schuin"), (("EN" if z == 5 else "SE") if x == 45 else naar))
	# zijbeuken (1 laag) met steunberen en luchtbogen
	for x in range(38, 46):
		for z in [4, 7]:
			var naar := "N" if z == 4 else "S"
			B(x, 0, z, p + ("verd_steunbeer" if x % 2 else "bg_spitsraam"), naar)
			if x % 2:
				B(x, 1, z, p + "luchtboog", naar)
			else:
				B(x, 1, z, p + "dak_schuin", naar)
	# westfront met twee torens en roosvenster
	for z in [5, 6]:
		B(37, 0, z, p + "bg_portaal", "W")
		B(37, 1, z, p + "verd_roosvenster" if z == 5 else p + "verd_spitsraam", "W")
		B(37, 2, z, p + "verd_spitsraam", "W")
		B(37, 3, z, p + "gevel_spits" if z == 5 else p + "dak_plat_midden", "W")
	for z in [4, 7]:
		toren(37, z, k, ["toren_portaal", "toren_raam", "toren_raam", "toren_galmgat", "toren_klok", "toren_pinakels"], "W")
	toren(44, 3, k, ["toren_raam", "toren_raam", "toren_galmgat", "toren_spits_onder", "toren_spits_boven"], "N")
	for z in [3, 8]:
		Pr(36 * 4 + 2, z * 4 + 2, "bomen/linde")
	Pr(41 * 4, 9 * 4 + 2, "straat/bank_hout", "N")
	Pr(43 * 4, 9 * 4 + 2, "straat/bank_hout", "N")
	# school met speelplaats x 47..57
	blok(48, 2, 8, 2, "school", 3, {"voor": "S", "bg": ["bg_raam", "bg_entree", "bg_raam"], "bg_zij": "bg_raam",
		"verd": ["verd_raam"], "dak": "plat"})
	B(52, 3, 2, "school/school_dak_zonnepanelen", "S")
	vlak(47, 4, 57, 10, "natuur/speeltuin_rubber")
	vlak(55, 7, 57, 10, "natuur/speeltuin_zand")
	vlak(47, 2, 47, 3, "stoep/stoep_vol")
	vlak(56, 2, 57, 3, "stoep/stoep_vol")
	Pr(49 * 4, 6 * 4, "speeltuin/klimrek")
	Pr(51 * 4 + 2, 8 * 4, "speeltuin/schommel", "E")
	Pr(53 * 4 + 2, 6 * 4, "speeltuin/glijbaan", "E")
	Pr(56 * 4, 8 * 4 + 2, "speeltuin/zandbak")
	Pr(49 * 4, 9 * 4 + 2, "speeltuin/wipwap")
	Pr(54 * 4, 9 * 4 + 2, "speeltuin/draaimolen")
	Pr(57 * 4, 5 * 4, "speeltuin/speelhuisje")
	Pr(51 * 4, 4 * 4 + 1, "speeltuin/basketbalpaal", "S")
	Pr(47 * 4 + 2, 7 * 4 + 2, "speeltuin/voetbaldoel", "E")
	Pr(55 * 4, 4 * 4 + 2, "speeltuin/pingpongtafel")
	for x in range(47, 58, 2):
		Pr(x * 4 + 2, 11 * 4 + 3.5, "hekken/schoolhek", "S")
	Pr(47 * 4 + 1, 11 * 4, "fietsen/fietsenrek_vol", "E")
	Pr(58 * 4 - 1, 9 * 4, "props/borden" if false else "borden/bord_let_op_kinderen", "E")


func _museum_en_raadhuis() -> void:
	vlak(63, 2, 95, 11, "plein/plein_tegels")
	# klassiek museum met koepel (x 64..70, z 4..10)
	var gat := []
	for x in range(66, 69):
		for z in range(6, 9):
			gat.append(Vector2i(x, z))
	blok(64, 4, 7, 7, "museum_klassiek", 2, {"voor": "S", "bg": ["bg_raam_boog", "bg_zuilen", "bg_raam_boog"],
		"bg_zij": "bg_raam_boog", "bg_hoek": "bg_raam_boog_hoek", "verd": ["verd_raam_boog", "verd_relief"],
		"verd_hoek": "verd_raam_boog_hoek", "dak": "kroonlijst", "gat": gat})
	B(67, 2, 7, "museum_klassiek/museum_klassiek_dak_koepel_3x3", "S")
	B(67, 2, 10, "museum_klassiek/museum_klassiek_top_fronton", "S")
	Pr(66 * 4, 11 * 4 + 1, "planten/plantenbak_beton")
	Pr(69 * 4, 11 * 4 + 1, "planten/plantenbak_beton")
	# raadhuis (overheid) x 73..79, z 6..10 + klokkentoren
	blok(73, 6, 7, 5, "overheid", 3, {"voor": "S", "bg": ["bg_raam", "bg_entree", "bg_raam"], "bg_zij": "bg_raam",
		"verd": ["verd_raam_hoog", "verd_balkon"], "verd_hoek": "verd_raam_hoog_hoek", "dak": "kantelen"})
	B(76, 3, 10, "overheid/overheid_top_fronton", "S")
	B(75, 3, 10, "overheid/overheid_top_naambord", "S")
	toren(76, 7, "overheid", ["blok_dicht", "blok_dicht", "blok_dicht", "blok_dicht", "toren_klok", "toren_spits_onder", "toren_spits_boven"])
	for i in 3:
		Pr(74 * 4 + i * 8, 11 * 4 + 2, ["straat/vlaggenmast_nl", "straat/vlaggenmast_regenboog", "straat/vlaggenmast_denhaag"][i], "S")
	D(73 * 4.0, 8 * 4.0, 4.0, "gevel/vlag_regenboog", "W")
	D(80 * 4.0, 8 * 4.0, 4.0, "gevel/vlag_denhaag", "E")
	# modern museum x 83..93, z 4..10
	blok(83, 4, 11, 6, "museum_modern", 2, {"voor": "S", "bg": ["bg_dicht", "bg_entree", "bg_dicht"], "bg_zij": "bg_dicht",
		"bg_hoek": "bg_entree_hoek", "verd": ["verd_lichtstrook", "verd_dicht"], "verd_hoek": "verd_lichtstrook_hoek", "dak": "plat"})
	for x in range(84, 93):
		B(x, 2, 10, "museum_modern/museum_modern_dak_overstek", "S")
	Pr(88 * 4, 11 * 4 + 2, "planten/boombak")
	Pr(92 * 4, 11 * 4 + 2, "planten/boombak")


func _jaren30_wijk() -> void:
	# straten: N-S woonstraat x=47 (stoepen 46 en 48), E-W straat z=29 (stoepen 28 en 30)
	profiel_z(18, 39, [[46, "stoep/stoep_rand", "E"], [47, "weg/straat_eenrichting", "S"], [48, "stoep/stoep_rand", "W"]], [28, 29, 30])
	profiel_x(36, 58, [[28, "stoep/stoep_rand", "S"], [29, "weg/weg_vlak", "E"], [30, "stoep/stoep_rand", "N"]], [46, 47, 48])
	G(46, 29, "weg/weg_vlak")
	G(47, 29, "weg/kruising_haaientanden")
	G(48, 29, "weg/weg_vlak")
	for c in [[46, 28, "SE"], [48, 28, "WS"], [46, 30, "EN"], [48, 30, "NW"]]:
		G(c[0], c[1], "stoep/stoep_hoek_buiten", c[2])
	Pr(46 * 4 + 1, 20 * 4, "borden/bord_eenrichtingsweg", "E")
	Pr(48 * 4 + 3, 38 * 4, "borden/bord_verboden_in_te_rijden", "W")
	Pr(48 * 4 + 3, 37 * 4, "borden/bord_onderbord_uitgezonderd", "W")
	for z in [21, 33]:
		G(47, z, "weg/drempel_asfalt")
	# bovenhuizen hoog (4 lagen) als gesloten bouwblok met winkels/horeca aan de Hoofdstraat
	ring(36, 18, 10, 10, "jaren30", 4, {"bg": ["bg_portiek", "bg_raam", "bg_erker"], "verd": ["verd_raam", "verd_erker", "verd_balkon", "verd_trappenhuis"],
		"achter": ["verd_raam", "verd_balkon"], "dak_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	var winkels := ["bg_kleding", "bg_restaurant", "bg_cafe", "bg_bar", "bg_telefoon", "bg_winkel_luifel", "bg_cafe", "bg_restaurant"]
	for i in range(1, 9):
		B(36 + i, 0, 18, "jaren30/jaren30_" + winkels[i - 1], "N")
	vlak(38, 20, 43, 25, "natuur/gras")
	Pr(40 * 4 + 2, 22 * 4 + 2, "bomen/bloesemboom")
	Pr(42 * 4, 24 * 4, "speeltuin/zandbak")
	# terrassen op de stoep van de Hoofdstraat
	for i in range(1, 9):
		var wx := (36 + i) * 4 + 2.0
		if winkels[i - 1] in ["bg_restaurant", "bg_cafe"]:
			Pr(wx, 17 * 4 + 1.5, "terras/terras_set_parasol" if i % 2 else "terras/terras_set_parasol_groen")
			Pr(wx - 1.5, 17 * 4 + 3.5, "terras/terras_scherm", "S")
		elif winkels[i - 1] == "bg_bar":
			Pr(wx, 17 * 4 + 2, "terras/statafel")
		Pr(wx + 1.5, 17 * 4 + 0.5, "terras/stoepbord", "S") if i % 3 == 0 else null
	# bovenhuizen middelhoog (3 lagen), portiek-woningen aan de straat z=30
	blok(36, 31, 10, 2, "jaren30", 3, {"voor": "N", "bg": ["bg_portiek", "bg_raam", "bg_erker"], "bg_zij": "bg_raam",
		"verd": ["verd_raam", "verd_erker", "verd_balkon"], "dak": "schuin", "dak_extra": ["dak_schuin_dakkapel"]})
	blok(36, 35, 10, 2, "jaren30", 3, {"voor": "S", "bg": ["bg_portiek", "bg_raam"], "bg_zij": "bg_raam",
		"verd": ["verd_raam", "verd_trappenhuis"], "dak": "plat"})
	vlak(36, 33, 45, 34, "natuur/gras")
	for x in range(36, 46, 2):
		Pr(x * 4 + 2, 34 * 4 + 0.5, "muurtjes/tuinmuur_middel" if x % 4 else "muurtjes/tuinmuur_poort", "S")
	vlak(36, 37, 45, 39, "stoep/stoep_vol")
	for x in range(36, 46, 3):
		Pr(x * 4 + 2, 38 * 4 + 2, "bomen/linde")


func _herenhuizen() -> void:
	# herenhuizen 1600 (x 49..53) en 1900 (x 54..58) aan de Hoofdstraat (voorkant noord)
	blok(49, 18, 5, 2, "herenhuis_1600", 3, {"voor": "N", "bg": ["bg_deur", "bg_raam"], "bg_zij": "bg_raam",
		"verd": ["verd_raam", "verd_balkon"], "dak": "schuin", "top": "top_lijstgevel_fronton"})
	B(51, 3, 18, "herenhuis_1600/herenhuis_1600_gevel_klok", "N")
	blok(54, 18, 5, 2, "herenhuis_1900", 3, {"voor": "N", "bg": ["bg_deur", "bg_raam_boog"], "bg_zij": "bg_raam_boog",
		"bg_hoek": "bg_raam_boog_hoek", "verd": ["verd_raam_boog", "verd_erker", "verd_balkon"], "verd_hoek": "verd_raam_boog_hoek", "dak": "schuin",
		"top": "dak_mansarde_rand"})
	# opstap-trappetjes en tuinen met muren en poorten
	for x in [49, 51, 53]:
		D(x * 4 + 2.0, 18 * 4.0, 0.0, "deuren/bordes_klassiek", "N")
	for x in range(49, 59):
		vlak(x, 20, x, 27, "natuur/gras" if x % 2 else "natuur/gras_bloemen")
		Pr(x * 4 + 2, 27 * 4 + 3.5, "muurtjes/tuinmuur_hoog_poort" if x % 3 == 0 else "muurtjes/tuinmuur_hoog", "S")
		Pr(x * 4 + 0.5, 23 * 4 + 2, "hekken/haag", "E")
	Pr(50 * 4 + 2, 24 * 4, "bomen/kastanje")
	Pr(55 * 4 + 2, 25 * 4, "bomen/plataan")
	Pr(57 * 4, 22 * 4, "planten/bosje_klein")
	Pr(52 * 4, 22 * 4, "terras/terras_set")


func _kleine_kerken() -> void:
	vlak(49, 31, 58, 39, "natuur/gras")
	# dorpskerk (klein) x 51..55, z 33, zadeldak, toren op x=50
	var k := "kerk_baksteen"
	blok(51, 33, 5, 1, k, 2, {"voor": "S", "bg": ["bg_spitsraam"], "bg_zij": "bg_spitsraam", "bg_hoek": "bg_spitsraam_hoek",
		"verd": ["verd_dicht"], "verd_hoek": "verd_spitsraam_hoek", "dak": "zadel"})
	toren(50, 33, k, ["toren_portaal", "toren_raam", "toren_klok", "toren_spits_onder", "toren_spits_boven"], "W")
	vlak(49, 32, 56, 34, "natuur/gras_kort")
	G(49, 33, "natuur/grindpad")
	# moderne (gereformeerde) kerk x 53..57, z 36..38 met losse klokkenstoel
	blok(53, 36, 5, 3, "kerk_modern", 2, {"voor": "N", "bg": ["bg_entree", "bg_dicht"], "bg_zij": "bg_dicht",
		"bg_hoek": "bg_entree_hoek", "verd": ["verd_spleet", "verd_kruis"], "verd_hoek": "verd_spleet_hoek", "dak": "plat"})
	toren(51, 37, "kerk_modern", ["toren_beton", "toren_beton", "toren_beton_klok"])
	Pr(50 * 4, 36 * 4, "bomen/treurwilg")
	Pr(57 * 4, 31 * 4 + 2, "bomen/den")


func _hoogbouw() -> void:
	vlak(63, 18, 76, 39, "plein/plein_tegels")
	vlak(80, 18, 95, 39, "plein/plein_tegels")
	profiel_z(18, 39, [[77, "stoep/stoep_rand", "E"], [78, "weg/rijstrook_onderbroken_kant", "S"], [79, "stoep/stoep_rand", "W"]])
	# kantoor jaren 80 (10 lagen)
	blok(64, 19, 3, 3, "kantoor_80", 10, {"voor": "S", "bg": ["bg_entree"], "bg_zij": "bg_glas", "bg_hoek": "bg_glas_hoek",
		"verd": ["verd_spiegelband", "verd_band"], "verd_hoek": "verd_spiegelband_hoek", "dak": "plat"})
	B(65, 10, 20, "kantoor_80/kantoor_80_dak_installatie", "S")
	D(64 * 4 + 4.0, 19 * 4 + 3.0, 30.0, "dak/koelinstallatie", "S")
	D(66 * 4 + 2.0, 21 * 4 + 2.0, 30.0, "dak/luchtbehandeling", "E")
	D(71 * 4 + 2.0, 20 * 4 + 2.0, 42.0, "dak/koelinstallatie", "E")
	D(65 * 4 + 2.0, 26 * 4 + 2.0, 21.0, "dak/koelinstallatie", "S")
	D(67 * 4 + 2.0, 26 * 4 + 2.0, 21.0, "dak/zonnepanelen_schuin_rij", "S")
	D(73 * 4 + 4.0, 33 * 4 + 4.0, 30.0, "dak/koelinstallatie", "S")
	# kantoor jaren 2000 (14 lagen) met kroon
	blok(70, 19, 3, 3, "kantoor_2000", 14, {"voor": "S", "bg": ["bg_entree"], "bg_zij": "bg_glas", "bg_hoek": "bg_glas_hoek",
		"verd": ["verd_zonwering", "verd_vliesgevel"], "verd_hoek": "verd_zonwering_hoek", "dak": "plat"})
	for x in range(70, 73):
		B(x, 14, 21, "kantoor_2000/kantoor_2000_dak_kroon_rand", "S")
	# kantoor modern (7 lagen, lamellen) en een met grote ramen
	blok(64, 25, 5, 3, "kantoor_modern", 7, {"voor": "S", "bg": ["bg_entree", "bg_glas"], "bg_zij": "bg_glas", "bg_hoek": "bg_glas_hoek",
		"verd": ["verd_lamellen", "verd_raam_groot"], "verd_hoek": "verd_lamellen_hoek", "dak": "plat"})
	blok(70, 25, 2, 2, "kantoor_glas", 5, {"voor": "S", "bg": ["bg_entree"], "bg_zij": "bg_glas", "bg_hoek": "bg_glas_hoek",
		"verd": ["verd_raam_klein"], "verd_hoek": "verd_band_hoek", "dak": "plat"})
	# modern appartementengebouw (16 lagen)
	blok(73, 24, 3, 4, "appartement_modern", 16, {"voor": "W", "bg": ["bg_entree", "bg_glas"], "bg_zij": "bg_glas", "bg_hoek": "bg_glas_hoek",
		"verd": ["verd_glas", "verd_loggia", "verd_balkon", "verd_paneel", "verd_raam_groot", "verd_raam_klein"], "verd_hoek": "verd_balkon_hoek", "dak": "plat"})
	B(74, 16, 25, "appartement_modern/appartement_modern_dak_daktuin", "S")
	# galerijflat (jaren 50/60, 10 lagen)
	blok(64, 33, 12, 2, "galerijflat", 10, {"voor": "N", "bg": ["bg_bergingen", "bg_entree", "bg_bergingen"], "bg_zij": "bg_bergingen",
		"bg_hoek": "bg_bergingen_hoek", "verd": ["verd_galerij"], "verd_hoek": "verd_galerij_hoek", "dak": "plat"})
	for x in range(64, 76):
		for v in range(1, 10):
			B(x, v, 34, "galerijflat/galerijflat_" + ("verd_balkons_hoek" if x == 64 or x == 75 else "verd_balkons"),
				("WS" if x == 64 else "SE") if (x == 64 or x == 75) else "S")
	toren(76, 33, "galerijflat", ["bg_entree", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis",
		"verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "dak_liftopbouw"], "E")
	# parkeergarage (4 dekken) x 81..86, z 19..24
	for x in range(81, 87):
		for z in range(19, 25):
			var sides := _zijden(x, z, 81, 19, 6, 6)
			for v in range(4):
				var kind := "dak" if v == 3 else "dek"
				if sides.size() == 0:
					B(x, v, z, "parkeergarage/parkeergarage_%s_midden" % kind, "S")
				elif sides.size() == 1:
					B(x, v, z, "parkeergarage/parkeergarage_%s_rand" % kind, sides[0])
				else:
					B(x, v, z, "parkeergarage/parkeergarage_%s_hoek" % kind, HOEK[_hoekpaar(sides, "")])
	B(81, 0, 21, "parkeergarage/parkeergarage_inrit", "W")
	for v in range(3):
		B(84, v, 21 + (v % 2), "parkeergarage/parkeergarage_helling", "N" if v % 2 == 0 else "S")
	toren(86, 25, "parkeergarage" if false else "kantoor_beton", [], "S")
	B(87, 0, 19, "parkeergarage/parkeergarage_trappenhuis", "S")
	for v in range(1, 4):
		B(87, v, 19, "parkeergarage/parkeergarage_trappenhuis", "S")
	Pr(80 * 4 + 1, 21 * 4, "hekken/slagboom", "W")
	Pr(80 * 4 + 1, 23 * 4, "paaltjes/parkeerautomaat", "W")
	# radiotoren
	B(92, 0, 20, "overig/radiotoren_voet", "S")
	for v in range(1, 12):
		B(92, v, 20, "overig/radiotoren_segment", "S")
	B(92, 12, 20, "overig/radiotoren_top", "S")
	# glazen overkapping met terras
	for x in range(88, 95):
		for z in range(24, 29):
			B(x, 0, z, "overkapping/overkapping_glas_kolom" if (x % 2 == 0 and z % 2 == 0) else "overkapping/overkapping_glas", "S")
	for x in [89, 91, 93]:
		Pr(x * 4, 26 * 4, "terras/terras_set")
	Pr(90 * 4, 27 * 4 + 2, "terras/bloembak_terras")
	# pilaren en zuilengang
	for x in [64, 67, 70]:
		B(x, 0, 30, "pilaren/pilaar_klassiek" if x == 64 else ("pilaren/pilaar_beton" if x == 67 else "pilaren/pilaar_staal"), "S")
	B(72, 0, 30, "pilaren/pilaar_baksteen", "S")
	for x in range(64, 70):
		B(x, 0, 31, "pilaren/zuilengang_klassiek", "N")
	# loopbrug over de straat x=78 (van appartementen naar parkeergarage), op niveau 4 met trappen
	for x in range(76, 81):
		G(x, 30, "brug/loopbrug_overdekt", "E", 4)
	for i in range(4):
		G(80, 34 - i, "brug/loopbrug_trap", "S", i)
	G(80, 30, "brug/loopbrug_pijler", "S", 3) if false else null


func _zwemmen_en_hallen() -> void:
	# binnenbad: holle hal (glas/zwembad) x 88..94, z 31..37 met zwembad-tiles op laag -1
	var h0 := 88
	var z0 := 31
	for x in range(h0, h0 + 7):
		for z in range(z0, z0 + 7):
			var sides := _zijden(x, z, h0, z0, 7, 7)
			var st := "hallen/hal_zwembad_"
			if sides.size() == 0:
				B(x, 0, z, st + "dak", "S")
			elif sides.size() == 1:
				B(x, 0, z, st + ("wand_deur_dak" if (x == 91 and z == z0) else "wand_dak"), sides[0])
			else:
				B(x, 0, z, st + "hoek_dak", HOEK[_hoekpaar(sides, "")])
	vlak(h0, z0, h0 + 6, z0 + 6, "zwembad/zwembad_kant_tegels")
	for x in range(h0 + 1, h0 + 6):
		for z in range(z0 + 2, z0 + 5):
			var es := _zijden(x, z, h0 + 1, z0 + 2, 5, 3)
			if es.size() == 0:
				G(x, z, "zwembad/zwembad_midden", "S", -1)
			elif es.size() == 1:
				G(x, z, "zwembad/zwembad_rand_trap" if (x == h0 + 3 and es[0] == "N") else "zwembad/zwembad_rand", es[0], -1)
			else:
				G(x, z, "zwembad/zwembad_hoek", HOEK[_hoekpaar(es, "")], -1)
			bezet[Vector2i(x, z)] = true
	# sporthal ernaast (hal_sport) x 81..86, z 28..32 en een glazen hal x 81..86, z 34..38? -> buitenbad
	for x in range(81, 87):
		for z in range(28, 32):
			var sides := _zijden(x, z, 81, 28, 6, 4)
			var st := "hallen/hal_glas_"
			if sides.size() == 0:
				B(x, 0, z, st + "dak", "S")
			elif sides.size() == 1:
				B(x, 0, z, st + ("wand_deur_dak" if (z == 31 and x == 83) else "wand_dak"), sides[0])
			else:
				B(x, 0, z, st + "hoek_dak", HOEK[_hoekpaar(sides, "")])
	Pr(83 * 4, 29 * 4 + 2, "bomen/boombak" if false else "planten/boombak")
	Pr(85 * 4, 29 * 4 + 2, "terras/terras_set")
	D(83 * 4 + 2.0, 32 * 4.0, 0.0, "deuren/draaideur", "S")
	# buitenbad x 81..86, z 33..38
	vlak(80, 33, 87, 39, "zwembad/zwembad_kant_tegels")
	for x in range(81, 87):
		for z in range(34, 38):
			var es := _zijden(x, z, 81, 34, 6, 4)
			if es.size() == 0:
				G(x, z, "zwembad/zwembad_midden", "S", -1)
			elif es.size() == 1:
				G(x, z, "zwembad/zwembad_rand", es[0], -1)
			else:
				G(x, z, "zwembad/zwembad_hoek", HOEK[_hoekpaar(es, "")], -1)
			bezet[Vector2i(x, z)] = true
	G(87, 38, "zwembad/kinderbad")
	Pr(81 * 4 + 2, 33 * 4 + 3, "zwembad/duikplank", "S")
	Pr(84 * 4, 33 * 4 + 3.5, "zwembad/zwembadtrap", "S")
	Pr(86 * 4 + 2, 38 * 4 + 2, "zwembad/badmeesterstoel", "N")
	for x in [81, 83, 85]:
		Pr(x * 4 + 2, 39 * 4, "zwembad/ligstoel", "N")
	Pr(87 * 4 + 2, 35 * 4, "zwembad/parasol")
	for z in range(33, 40, 2):
		Pr(80 * 4, z * 4 + 2, "hekken/hek_gaas_hoog", "E")


func _rivier_en_bruggen() -> void:
	# rivier z 49..53 op laag -2, kades op z 48 en 54
	for x in range(0, W):
		for z in range(49, 54):
			G(x, z, "water/water", "S", -2)
			bezet[Vector2i(x, z)] = true
		for z in [48, 54]:
			if (x == 8 or x == 9) and z == 48:
				G(x, z, "water/water_gracht", "S", -2)
				bezet[Vector2i(x, z)] = true
				continue
			G(x, z, "water/kademuur_alg", "S", -2)
			G(x, z, "water/kademuur", "S", -1)
			G(x, z, "stoep/stoep_kade" if x % 6 else "stoep/stoep_kade_klinker", "S" if z == 48 else "N")
			if x % 3 == 0:
				Pr(x * 4 + 2, z * 4 + (1 if z == 48 else 3), "paaltjes/bolder")
			if x % 6 == 3:
				Pr(x * 4 + 2, z * 4 + (2.5 if z == 48 else 1.5), "verlichting/lantaarn_klassiek")
	# stalen boogbrug in de Dwarsstraat2 (x 60,61)
	for i in range(5):
		G(60, 53 - i, "brug/staalboog_rand_%d" % (i + 1), "S")
		G(61, 49 + i, "brug/staalboog_rand_%d" % (i + 1), "N")
	for z in [48, 54]:
		G(60, z, "weg/rijstrook_geen_kant", "N")
		G(61, z, "weg/rijstrook_onderbroken_kant", "S")
	# tuibrug bij x 40,41
	G(40, 51, "brug/tuibrug_0", "S")
	for i in range(1, 4):
		G(40, 51 - i, "brug/tuibrug_%d" % i, "S")
		G(40, 51 + i, "brug/tuibrug_%d" % i, "S") if false else G(40, 51 + i, "brug/brug_dek_weg_rand", "S")
	for z in range(48, 55):
		G(41, z, "brug/brug_dek_weg_rand", "N")
	# ophaalbrug (klassiek, smal) bij x=20
	G(20, 49, "brug/ophaalbrug_dek", "S")
	G(20, 50, "brug/ophaalbrug_portaal", "N")
	G(20, 51, "brug/ophaalbrug_dek", "S")
	G(20, 52, "brug/ophaalbrug_portaal", "S")
	G(20, 53, "brug/ophaalbrug_dek", "S")
	Pr(19 * 4 + 2, 48 * 4 + 2, "water/brugwachtershuisje_klassiek")
	# moderne voetbrug en brug met loopbrug-stijl bij x=75
	for z in range(49, 54):
		G(75, z, "brug/voetbrug_modern", "S")
	Pr(76 * 4 + 2, 54 * 4 + 2, "water/brugwachtershuisje_modern")
	# kadetrap en boten
	G(30, 54, "waterkant/kadetrap", "N", -2)
	bezet[Vector2i(30, 54)] = true
	for x in [12, 26, 50, 68, 88]:
		Pr(x * 4, 52 * 4 + 2, "water/woonboot", "E", -2.0)
	Pr(34 * 4, 50 * 4, "water/sloep", "W", -2.0)
	Pr(56 * 4, 50 * 4 + 2, "water/roeiboot", "E", -2.0)
	Pr(84 * 4, 50 * 4, "water/steiger_lang", "E", -2.0) if false else null


func _jaren60_wijk() -> void:
	# woonstraten z=56 en z=64 (met drempels), N-S straat x=15
	profiel_x(0, 30, [[55, "stoep/stoep_rand", "S"], [56, "weg/weg_vlak", "E"], [57, "stoep/stoep_rand", "N"]], [15])
	profiel_x(0, 30, [[63, "stoep/stoep_rand", "S"], [64, "weg/weg_vlak", "E"], [65, "stoep/stoep_rand", "N"]], [15])
	profiel_z(55, 71, [[14, "stoep/stoep_rand", "E"], [15, "weg/weg_vlak", "S"], [16, "stoep/stoep_rand", "W"]], [55, 56, 57, 63, 64, 65])
	for z in [56, 64]:
		G(15, z, "weg/kruising_vlak")
		G(5, z, "weg/drempel_punaise", "E")
		G(25, z, "weg/verkeersdrempel", "E")
	for c in [[14, 55], [16, 55], [14, 57], [16, 57], [14, 63], [16, 63], [14, 65], [16, 65]]:
		G(c[0], c[1], "weg/weg_vlak")
	G(15, 55, "weg/weg_vlak")
	G(15, 57, "weg/weg_vlak")
	G(15, 63, "weg/weg_vlak")
	G(15, 65, "weg/weg_vlak")
	Pr(14 * 4, 58 * 4, "borden/bord_woonerf", "E")
	# eengezinswoningen (2 lagen, schuine kap, erkers en dakkapellen)
	blok(1, 58, 12, 2, "jaren60", 2, {"voor": "N", "bg": ["bg_deur", "bg_raam", "bg_erker"], "bg_zij": "bg_raam",
		"verd": ["verd_raam", "verd_raam_klein"], "dak": "schuin", "dak_extra": ["dak_schuin_dakkapel", "dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	blok(1, 61, 12, 2, "jaren60", 2, {"voor": "S", "bg": ["bg_deur", "bg_erker", "bg_berging"], "bg_zij": "bg_raam",
		"verd": ["verd_raam", "verd_balkon"], "dak": "schuin", "dak_extra": ["dak_schuin_dakkapel"]})
	vlak(0, 58, 0, 62, "natuur/gras")
	for x in range(1, 13):
		G(x, 60, "natuur/gras" if x % 2 else "natuur/gras_bloemen")
		Pr(x * 4 + 0.5, 60 * 4 + 2, "hekken/schutting_hout", "E")
	# garagedeuren en details
	D(3 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_kanteldeur", "S")
	D(7 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_sectionaal", "S")
	D(11 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_roldeur", "S")
	for x in [2, 6, 10]:
		D(x * 4 + 2.0, 58 * 4.0, 3.5, "zonwering/knikarmscherm_streep", "N")
		D(x * 4 + 2.0, 58 * 4.0, 6.0, "dak/zonnepanelen_klein" if false else "zonwering/uitvalscherm_oranje", "N")
	# maisonnettes / galerijflat laag (4 lagen) x 17..28
	blok(17, 58, 12, 2, "jaren60", 4, {"voor": "N", "bg": ["bg_deur", "bg_raam", "bg_berging"], "bg_zij": "bg_raam",
		"verd": ["verd_raam", "verd_galerij_deur", "verd_raam_klein"], "verd_hoek": "verd_raam_hoek", "dak": "plat"})
	for x in range(18, 28):
		B(x, 2, 58, "jaren60/jaren60_verd_galerij_deur", "N")
		B(x, 3, 58, "jaren60/jaren60_verd_raam_klein", "N")
	# parkeerplaats x 17..28, z 60..62
	for x in range(17, 29):
		G(x, 60, "parkeren/parkeervak_haaks" if x % 4 else "parkeren/parkeervak_laadpaal", "S")
		G(x, 61, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, 62, "parkeren/parkeervak_schuin" if x < 23 else "parkeren/parkeervak_haaks_eind", "N")
	for x in [20, 24, 28]:
		Pr(x * 4, 60 * 4 + 0.5, "paaltjes/laadpaal", "S")
	Pr(17 * 4 + 1, 61 * 4 + 2, "paaltjes/parkeerautomaat", "E")
	Pr(22 * 4, 63 * 4 + 0.5, "straat/afvalcontainer_ondergronds")
	Pr(24 * 4, 63 * 4 + 1, "straat/glasbak")
	Pr(26 * 4, 63 * 4 + 1, "straat/kledingcontainer")
	Pr(28 * 4, 63 * 4 + 1, "straat/container_klein")
	# speeltuin, bosjes en vijver met waterkant x 0..13 / 17..30, z 66..71
	vlak(0, 66, 13, 71, "natuur/gras")
	vlak(1, 67, 5, 70, "natuur/speeltuin_rubber")
	Pr(2 * 4, 68 * 4, "speeltuin/schommel", "E")
	Pr(4 * 4, 69 * 4, "speeltuin/glijbaan")
	Pr(3 * 4, 67 * 4 + 2, "speeltuin/wipwap")
	for x in [7, 9, 11]:
		Pr(x * 4 + 2, 68 * 4 + 2, "planten/bosje_groot" if x == 9 else "planten/bosje_klein")
	Pr(12 * 4, 71 * 4, "planten/braamstruik")
	vlak(17, 66, 30, 71, "natuur/gras")
	for x in range(19, 29):
		G(x, 67, "waterkant/strand" if x < 22 else ("waterkant/beschoeiing" if x < 25 else "waterkant/basalt_talud"), "S")
		for z in range(68, 71):
			G(x, z, "water/water")
		G(x, 71, "water/water_oever", "N")
	G(23, 69, "brug/voetbrug_hout_boog", "S")
	G(26, 69, "water/water_lelies")
	Pr(20 * 4, 69 * 4, "water/steiger_L", "S", 0.0)
	Pr(27 * 4, 68 * 4, "water/steiger_trap", "N", 0.0)
	Pr(18 * 4, 66 * 4 + 2, "terras/terras_set_parasol")
	G(18, 67, "waterkant/strand_hoek", "WS")
	G(29, 67, "waterkant/boulevard", "S")


func _boerderij_en_bedrijven() -> void:
	# boerderij met schuren x 32..44, heuvels en sloten
	vlak(31, 55, 58, 71, "natuur/gras_hoog")
	blok(33, 58, 4, 2, "schuur_zwart", 1, {"voor": "S", "bg": ["bg_deur_groot", "bg_raam"], "bg_zij": "bg_raam",
		"bg_hoek": "bg_raam_hoek", "verd": ["verd_hooideur"], "dak": "schuin"})
	blok(39, 58, 3, 2, "schuur_rood", 2, {"voor": "S", "bg": ["bg_deur_groot", "bg_raam"], "bg_zij": "bg_raam",
		"bg_hoek": "bg_deur_groot_hoek", "verd": ["verd_hooideur"], "verd_hoek": "bg_raam_hoek", "dak": "schuin"})
	vlak(33, 61, 41, 62, "natuur/grind")
	vlak(31, 64, 37, 70, "natuur/moestuin")
	vlak(38, 64, 42, 70, "natuur/heide")
	kolom(43, 56, 71, "water/sloot")
	G(43, 63, "water/duiker")
	vlak(44, 56, 50, 62, "natuur/bos")
	for i in 6:
		Pr((45 + i) * 4, (57 + (i % 3) * 2) * 4, ["bomen/den", "bomen/berk", "bomen/eik", "bomen/den", "bomen/berk", "bomen/populier"][i])
	Pr(47 * 4, 61 * 4, "planten/struikgewas")
	# heuvels: gras, zand en grind
	G(46, 66, "heuvel/heuvel_gras_blok")
	G(45, 66, "heuvel/heuvel_gras_helling", "E")
	G(47, 66, "heuvel/heuvel_gras_helling", "W")
	G(46, 65, "heuvel/heuvel_gras_helling", "S")
	G(46, 67, "heuvel/heuvel_gras_helling", "N")
	G(46, 66, "heuvel/heuvel_gras_top", "S", 1)
	for c in [[45, 65, "SE"], [47, 65, "WS"], [45, 67, "EN"], [47, 67, "NW"]]:
		G(c[0], c[1], "heuvel/heuvel_gras_hoek_buiten", c[2])
	G(50, 69, "heuvel/heuvel_zand_top")
	G(51, 69, "heuvel/heuvel_zand_helling", "W")
	G(53, 69, "heuvel/heuvel_grind_top")
	G(54, 69, "heuvel/heuvel_grind_helling", "W")
	vlak(49, 70, 55, 71, "natuur/zand")
	# bedrijfspanden met industrieel hekwerk
	blok(52, 57, 5, 3, "bedrijfspand", 2, {"voor": "S", "bg": ["bg_roldeur", "bg_kantoor", "bg_roldeur"], "bg_zij": "bg_dicht",
		"bg_hoek": "bg_kantoor_hoek", "verd": ["verd_lichtstraat", "verd_logo"], "verd_hoek": "verd_lichtstraat_hoek", "dak": "plat"})
	vlak(52, 60, 57, 62, "natuur/grind")
	for x in range(51, 58, 3):
		Pr(x * 4, 63 * 4 + 3, "hekken/hek_industrie", "S")
	Pr(58 * 4 - 3, 61 * 4, "hekken/schuifpoort_industrie", "E")
	Pr(54 * 4, 61 * 4 + 2, "straat/container_groot", "E")
	Pr(56 * 4, 61 * 4, "straat/bouwkeet")
	Pr(53 * 4, 60 * 4 + 2, "trappen/brandtrap", "S")
	Pr(57 * 4, 56 * 4 + 1, "trappen/trap_staal_spiraal")
	# kasteeltoren met kantelen
	toren(32, 66, "klassiek_donker", ["blok_dicht", "verd_raam", "verd_dicht", "dak_kantelen_toren"])


func _zuidoost() -> void:
	vlak(64, 55, 95, 71, "natuur/gras")
	# brede boulevard (schema: = = + - - + = =): 2 rijstroken, stoep met halte, 2 trambanen,
	# stoep met halte, 2 rijstroken; buitenste stoepen op x=63 en x=72
	for z in range(55, 72):
		var halte := z >= 60 and z <= 63
		G(63, z, "stoep/stoep_rand", "E")
		G(64, z, "weg/rijstrook_onderbroken_kant", "N")
		G(65, z, "weg/rijstrook_geen_geen", "N")
		G(66, z, "tram/tramhalte_middenperron" if halte else "stoep/stoep_eiland", "S" if halte else "E")
		G(67, z, "tram/trambaan_vrij", "S")
		G(68, z, "tram/trambaan_vrij", "S")
		G(69, z, "tram/tramhalte_middenperron" if halte else "stoep/stoep_eiland", "S" if halte else "E")
		G(70, z, "weg/rijstrook_geen_geen", "S")
		G(71, z, "weg/rijstrook_onderbroken_kant", "S")
		G(72, z, "stoep/stoep_rand", "W")
		if not halte and z % 3 == 0:
			Pr(66 * 4 + 2, z * 4 + 2, "verlichting/lantaarn_dubbel", "E")
			Pr(69 * 4 + 2, z * 4 + 2, "verlichting/lantaarn_dubbel", "E")
			Pr(72 * 4 + 2, z * 4 + 2, "bomen/linde")
	for z in [60, 62]:
		Pr(66 * 4 + 2, z * 4 + 2, "ov/abri", "E", 0.5)
		Pr(69 * 4 + 2, z * 4 + 2, "ov/abri", "W", 0.5)
	Pr(66 * 4 + 2, 63 * 4 + 2, "ov/tramhalte_paal", "E", 0.5)
	Pr(69 * 4 + 2, 63 * 4 + 2, "ov/tramhalte_paal", "W", 0.5)
	for x in [66, 69]:
		Pr(x * 4 + 2, 55 * 4 + 1, "verkeer/verkeerszuil", "N")
		Pr(x * 4 + 2, 71 * 4 + 3, "verkeer/verkeerszuil_geel", "S")
	# weg met middenberm (z 63..65) onder een viaduct door
	for x in range(73, W):
		G(x, 63, "weg/rijstrook_geen_kant", "E")
		G(x, 64, "weg/middenberm_gras" if x % 5 else "weg/middenberm_klinkers", "E")
		G(x, 65, "weg/rijstrook_geen_kant", "W")
		if x % 4 == 0:
			Pr(x * 4 + 2, 64 * 4 + 2, "verlichting/lantaarn_middenberm", "S")
	# viaduct: weg x 74,75 gaat over de middenbermweg heen (op niveau 5)
	for i in range(5):
		G(74, 57 + i, "helling/helling_brug_weg_vlak", "N", i)
		G(75, 57 + i, "helling/helling_brug_weg_vlak_rand", "N", i)
		G(74, 67 + i, "helling/helling_brug_weg_vlak_rand", "S", 4 - i)
		G(75, 67 + i, "helling/helling_brug_weg_vlak", "S", 4 - i)
	for z in range(62, 67):
		G(74, z, "brug/brug_dek_weg_rand", "S", 5)
		G(75, z, "brug/brug_dek_weg_rand", "N", 5)
	for z in [62, 66]:
		for x in [74, 75]:
			G(x, z, "brug/brug_pijler_gras", "S", 0)
			for y in range(1, 4):
				G(x, z, "brug/brug_pijler", "S", y)
			G(x, z, "brug/brug_pijler_kop", "S", 4)
	for x in [74, 75]:
		G(x, 56, "weg/weg_vlak")
		G(x, 55, "weg/weg_vlak")
	# luxe appartementen met dakterras en penthouse (8 lagen) x 77..82, z 56..59
	blok(77, 56, 6, 4, "luxe_appartement", 8, {"voor": "N", "bg": ["bg_glas", "bg_lobby", "bg_glas"], "bg_zij": "bg_glas",
		"bg_hoek": "bg_glas_hoek", "verd": ["verd_terras", "verd_glas"], "verd_hoek": "verd_terras_hoek", "dak": "geen"})
	for x in range(77, 83):
		for z in range(56, 60):
			var sides := _zijden(x, z, 77, 56, 6, 4)
			var p := "luxe_appartement/luxe_appartement_"
			if sides.size() == 0:
				B(x, 8, z, p + "penthouse_midden", "S")
			elif sides.size() == 1:
				B(x, 8, z, p + "penthouse_rand", sides[0])
			else:
				B(x, 8, z, p + "penthouse_hoek", HOEK[_hoekpaar(sides, "")])
	B(79, 9, 57, "luxe_appartement/luxe_appartement_dak_zwembad", "N")
	B(80, 9, 57, "luxe_appartement/luxe_appartement_dak_terras", "N")
	for x in range(77, 83):
		if x != 79 and x != 80:
			B(x, 9, 57, "luxe_appartement/luxe_appartement_dak_groen_midden", "S")
	# kantoor met grind-, bitumen- en groendak, koelinstallaties en zonnepanelen x 85..88, z 56..59
	blok(85, 56, 4, 4, "kantoor_glas", 4, {"voor": "N", "bg": ["bg_entree", "bg_glas"], "bg_zij": "bg_glas", "bg_hoek": "bg_glas_hoek",
		"verd": ["verd_raam_groot", "verd_vliesgevel"], "verd_hoek": "verd_vliesgevel_hoek", "dak": "geen"})
	for x in range(85, 89):
		for z in range(56, 60):
			var soort := "grind_midden" if x < 86 else ("bitumen_midden" if x < 87 else "groen_midden")
			B(x, 4, z, "kantoor_glas/kantoor_glas_dak_" + soort, "S")
	D(85 * 4 + 4.0, 57 * 4 + 2.0, 12.0, "dak/koelinstallatie", "S")
	D(86 * 4 + 4.0, 58 * 4.0, 12.0, "dak/zonnepanelen_schuin_rij", "S")
	D(86 * 4 + 4.0, 59 * 4 + 2.0, 12.0, "dak/zonnepanelen_schuin_rij", "S")
	D(85 * 4.0, 59 * 4 + 2.0, 12.0, "dak/luchtbehandeling", "E")
	# rijtjes met groendak x 77..88, z 68..69
	blok(77, 68, 12, 2, "modern_hout", 2, {"voor": "N", "bg": ["bg_deur", "bg_raam"], "bg_zij": "bg_raam",
		"verd": ["verd_raam", "verd_raam_breed"], "dak": "geen"})
	for x in range(77, 89):
		for z in [68, 69]:
			var sides := _zijden(x, z, 77, 68, 12, 2)
			var p := "modern_hout/modern_hout_dak_groen_"
			if sides.size() == 1:
				B(x, 2, z, p + "rand", sides[0])
			else:
				B(x, 2, z, p + "hoek", HOEK[_hoekpaar(sides, "")])
	# busstation met overkapping x 90..95, z 56..61
	vlak(90, 55, 95, 61, "weg/weg_vlak")
	for x in range(90, 96):
		G(x, 57, "weg/busbaan_vrij" if x == 92 else "weg/rijstrook_bus_leeg", "E")
		B(x, 0, 59, "overkapping/overkapping_glas_kolom" if x % 3 == 0 else "overkapping/overkapping_glas", "S")
		G(x, 59, "tram/tram_halte_perron", "N")
	Pr(91 * 4, 59 * 4 + 2, "straat/bank_modern", "N")
	Pr(94 * 4, 59 * 4 + 2, "straat/bank_modern", "N")
	Pr(90 * 4, 60 * 4, "ov/bushalte_paal", "N")
	# sporthal x 90..95, z 66..70
	for x in range(90, 96):
		for z in range(66, 71):
			var sides := _zijden(x, z, 90, 66, 6, 5)
			var st := "hallen/hal_sport_"
			if sides.size() == 0:
				B(x, 0, z, st + "dak", "S")
			elif sides.size() == 1:
				B(x, 0, z, st + ("wand_deur_dak" if (x == 92 and z == 66) else "wand_dak"), sides[0])
			else:
				B(x, 0, z, st + "hoek_dak", HOEK[_hoekpaar(sides, "")])
	D(92 * 4 + 2.0, 66 * 4.0, 3.0, "tekst/tekst_sporthal", "N")


func _snelweg_en_tunnel() -> void:
	# snelweg z 72..79, met tunnel van de Dwarsstraat2 eronder
	for x in range(0, W):
		G(x, 72, "snelweg/snelweg_berm_vangrail", "E")
		G(x, 73, "snelweg/snelweg_vluchtstrook", "E")
		G(x, 74, "weg/weg_vlak", "E")
		G(x, 75, "snelweg/snelweg_rijstrook_links", "E")
		G(x, 76, "snelweg/snelweg_middenberm_beton", "E")
		G(x, 77, "snelweg/snelweg_rijstrook_links", "W")
		G(x, 78, "weg/weg_vlak", "W")
		G(x, 79, "snelweg/snelweg_vluchtstrook", "W")
	for x in range(4, W, 10):
		Pr(x * 4, 76 * 4 + 2, "verlichting/lantaarn_middenberm", "E")
		Pr(x * 4 + 6, 72 * 4 + 3, "borden/hectometerpaal", "N")
	Pr(30 * 4, 74 * 4 + 2, "borden/snelweg_portaal", "E")
	Pr(70 * 4, 78 * 4 + 2, "borden/snelweg_portaal", "W")
	Pr(12 * 4, 72 * 4 + 2, "borden/bord_autosnelweg", "N")
	# Dwarsstraat2 loopt door tot de tunnel: z 55..59 gewoon, toerit 60..65, tunnelbak 66..71, tunnel 72..79.
	# Naast de autobaan (x 60,61) ligt een fietspad (x 62) in dezelfde tunnelbak.
	for z in range(55, 60):
		G(59, z, "stoep/stoep_rand", "E")
		G(60, z, "weg/rijstrook_geen_kant", "N")
		G(61, z, "weg/rijstrook_onderbroken_kant", "S")
		G(62, z, "fietspad/fietspad_recht")
		G(63, z, "stoep/stoep_vol")
	for d in range(1, 7):
		var z := 59 + d
		G(60, z, "tunnel/tunnel_toerit_wand_d%d" % d, "S", -d)
		G(61, z, "tunnel/tunnel_toerit_d%d" % d, "S", -d)
		G(62, z, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, "S", -d)
		for x in [60, 61, 62]:
			grond.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
			bezet[Vector2i(x, z)] = true
		G(59, z, "stoep/stoep_vol")
		G(63, z, "stoep/stoep_vol")
	for z in range(66, 72):
		G(60, z, "tunnel/tunnelbak_rijstrook_wand_d6", "S", -6)
		G(61, z, "tunnel/tunnelbak_rijstrook_d6", "N", -6)
		G(62, z, "tunnel/tunnelbak_fietspad_wand_rechts_d6", "S", -6)
		for x in [60, 61, 62]:
			grond.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
			bezet[Vector2i(x, z)] = true
		G(59, z, "natuur/gras")
		G(63, z, "natuur/gras")
	G(60, 72, "tunnel/tunnel_rijstrook_wand_portaal", "S", -6)
	G(61, 72, "tunnel/tunnel_rijstrook_portaal", "N", -6)
	G(62, 72, "tunnel/tunnel_fiets_wand_rechts_portaal", "S", -6)
	for z in range(73, 80):
		G(60, z, "tunnel/tunnel_rijstrook_wand", "S", -6)
		G(61, z, "tunnel/tunnel_rijstrook", "N", -6)
		G(62, z, "tunnel/tunnel_fiets_wand_rechts", "S", -6)
	Pr(59 * 4, 59 * 4, "borden/bord_tunnel", "E")
	# fietstunnel onder de snelweg bij x=13 (toerit 6 lagen diep, tunnel op laag -6)
	for d in range(1, 7):
		grond.set_cell_item(Vector3i(13, 0, 65 + d), GridMap.INVALID_CELL_ITEM)
		G(13, 65 + d, "tunnel/fietstunnel_toerit_wand_d%d" % d, "S", -d)
		bezet[Vector2i(13, 65 + d)] = true
	G(13, 72, "tunnel/tunnel_fiets_wand_portaal", "N", -6)
	for z in range(73, 80):
		G(13, z, "tunnel/tunnel_fiets_wand", "S", -6)


func _voetgangersbrug() -> void:
	for i in range(4):
		G(95, 35 + i, "brug/loopbrug_trap", "N", i)
	for z in range(39, 47):
		G(95, z, "brug/loopbrug_open", "S", 4)
	G(95, 47, "brug/loopbrug_open", "E", 4)
	for i in range(4):
		G(94 - i, 47, "brug/loopbrug_trap", "W", 3 - i)
	for z in [39, 46]:
		for y in range(0, 4):
			G(95, z, "brug/loopbrug_pijler", "S", y)


func _spoor_einde() -> void:
	for x in [33, 34]:
		G(x, 30, "spoor/trein_stootblok", "S")
	G(31, 30, "natuur/gras")


func _versiering() -> void:
	# standbeelden
	Pr(21 * 4 + 2, 18 * 4 + 2, "standbeelden/ruiterstandbeeld", "S")
	Pr(64 * 4, 3 * 4, "standbeelden/obelisk")
	Pr(80 * 4, 11 * 4, "standbeelden/standbeeld_persoon", "S")
	Pr(90 * 4, 11 * 4 + 2, "standbeelden/kunstwerk_modern")
	Pr(39 * 4 + 2, 2 * 4 + 2, "standbeelden/buste", "E")
	Pr(46 * 4, 22 * 4, "standbeelden/fontein_beeld") if false else null
	# terras op het plein van de oude stad
	for i in 4:
		Pr((18 + i * 2) * 4, 25 * 4 + 2, ["terras/tafel_rond_stoelen", "terras/tafel_vierkant_stoelen"][i % 2])
		Pr((18 + i * 2) * 4 + 2, 25 * 4 + 2, ["terras/parasol_rood", "terras/parasol_groen", "terras/parasol_blauw", "terras/parasol_naturel"][i])
	Pr(26 * 4, 23 * 4, "terras/parasol_groot")
	Pr(26 * 4, 23 * 4 + 2, "terras/tafel_rond")
	Pr(25 * 4, 23 * 4 + 2, "terras/bistrostoel")
	# klassieke lantaarns langs de herenhuizen en het museum
	for x in range(49, 59, 2):
		Pr(x * 4 + 2, 17 * 4 + 3, "verlichting/lantaarn_gietijzer", "N")
	for x in [64, 70]:
		Pr(x * 4 + 2, 11 * 4 + 2, "verlichting/lantaarn_klassiek_dubbel", "S")
	for x in [84, 88, 92]:
		Pr(x * 4 + 2, 3 * 4, "verlichting/lantaarn_bol")
	# extra vlaggen bij het raadhuis
	for i in 4:
		Pr((82 + i * 2) * 4, 11 * 4 + 3, ["straat/vlaggenmast_eu", "straat/vlaggenmast_amsterdam", "straat/vlaggenmast_rotterdam", "straat/vlaggenmast_transgender"][i], "S")


# ------------------------------------------------------------------ campus onder de snelweg (z 80..98)

func _campus() -> void:
	vlak(0, 80, 95, 98, "natuur/gras")
	# Campuslaan: stoep 81, rijstroken 82-83, stoep 84
	profiel_x(0, 95, [[81, "stoep/stoep_rand", "S"], [82, "weg/rijstrook_onderbroken_kant", "E"], [83, "weg/rijstrook_geen_kant", "W"], [84, "stoep/stoep_rand", "N"]])
	for x in range(2, W, 6):
		Pr(x * 4, 84 * 4 + 3, "verlichting/lantaarn_modern", "N")
	# universiteit: hoofdgebouw + twee vleugels rond een binnenplaats
	blok(4, 86, 15, 2, "universiteit", 3, {"voor": "N", "bg": ["bg_raam_boog"], "bg_zij": "bg_raam_boog", "bg_hoek": "bg_raam_boog_hoek",
		"verd": ["verd_raam", "verd_raam_hoog"], "verd_hoek": "verd_raam_hoek", "dak": "plat"})
	B(11, 0, 86, "universiteit/universiteit_bg_portaal", "N")
	B(11, 3, 87, "universiteit/universiteit_dak_dakruiter", "S")
	blok(4, 89, 2, 6, "universiteit", 2, {"voor": "E", "bg": ["bg_raam_boog"], "bg_zij": "bg_raam_boog", "bg_hoek": "bg_raam_boog_hoek",
		"verd": ["verd_raam"], "verd_hoek": "verd_raam_hoek", "dak": "schuin"})
	blok(17, 89, 2, 6, "universiteit", 2, {"voor": "W", "bg": ["bg_raam_boog"], "bg_zij": "bg_raam_boog", "bg_hoek": "bg_raam_boog_hoek",
		"verd": ["verd_raam"], "verd_hoek": "verd_raam_hoek", "dak": "schuin"})
	vlak(7, 89, 15, 95, "natuur/gras_kort")
	kolom(11, 89, 95, "natuur/grindpad")
	rij(7, 15, 92, "natuur/grindpad", "E")
	Pr(11 * 4 + 2, 92 * 4 + 2, "standbeelden/standbeeld_persoon", "N")
	D(11 * 4 + 2.0, 86 * 4.0, 7.0, "tekst/tekst_universiteit", "N")
	# hogeschool
	blok(24, 86, 14, 6, "hogeschool", 5, {"voor": "N", "bg": ["bg_glas", "bg_entree", "bg_kolonnade"], "bg_zij": "bg_glas",
		"bg_hoek": "bg_glas_hoek", "verd": ["verd_lamellen", "verd_vliesgevel", "verd_raam_groot"], "verd_hoek": "verd_lamellen_hoek", "dak": "plat"})
	for x in range(26, 36, 3):
		B(x, 5, 89, "hogeschool/hogeschool_dak_zonnepanelen", "S")
	D(31 * 4.0, 86 * 4.0, 15.5, "tekst/tekst_hogeschool", "N")
	for x in range(25, 37, 3):
		Pr(x * 4, 85 * 4 + 2, "fietsen/fietsenrek_vol", "N")
	# twee kantoortorens met kolonnade en een loopbrug ertussen (op 36 m)
	for tx in [44, 54]:
		blok(tx, 86, 4, 4, "kantoor_2000", 20, {"voor": "N", "bg": ["bg_kolonnade", "bg_entree"], "bg_zij": "bg_glas",
			"bg_hoek": "bg_kolonnade_hoek", "verd": ["verd_zonwering", "verd_vliesgevel"], "verd_hoek": "verd_zonwering_hoek", "dak": "plat"})
		D(tx * 4 + 6.0, 87 * 4 + 2.0, 60.0, "dak/koelinstallatie", "S")
		D(tx * 4 + 10.0, 88 * 4 + 2.0, 60.0, "dak/koelinstallatie", "S")
		D(tx * 4 + 8.0, 89 * 4 + 2.0, 60.0, "dak/luchtbehandeling", "S")
	blok(48, 86, 6, 3, "kantoor_glas", 3, {"voor": "N", "bg": ["bg_kolonnade"], "bg_zij": "bg_glas", "bg_hoek": "bg_kolonnade_hoek",
		"verd": ["verd_vliesgevel"], "verd_hoek": "verd_vliesgevel_hoek", "dak": "plat"})
	for x in range(48, 54):
		G(x, 88, "brug/loopbrug_overdekt", "E", 36)
	vlak(44, 85, 57, 85, "plein/plein_natuursteen")
	for x in [45, 50, 55]:
		Pr(x * 4 + 2, 85 * 4 + 2, "standbeelden/kunstwerk_modern" if x == 50 else "planten/boombak")
	_winkelstraat()


# ==================================================================
# DEMOWIJKEN: elke tile toegepast in een buurt, gebouw of situatie
# ==================================================================

const RICHTING := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "W": Vector2i(-1, 0), "E": Vector2i(1, 0)}

var _wx := 1
var _wz := 0
var _wijk_naam := ""
var wijken := []
var _wrij := 0
var _detail_rij := {}   # groep -> Array van namen (wachtrij)
var _prop_straat := []
var _prop_groen := []
var _prop_water := []
var _pi_s := 0
var _pi_g := 0
var _pi_w := 0


func _namen(gm: GridMap, prefix: String) -> Array:
	var uit := []
	for id in gm.mesh_library.get_item_list():
		var nm := gm.mesh_library.get_item_name(id)
		if nm.begins_with(prefix):
			uit.append(nm)
	uit.sort()
	return uit


func _kort(stijl: String, nm: String) -> String:
	return nm.split("/")[nm.split("/").size() - 1].trim_prefix(stijl + "_")


## Neemt een rechthoek (in cellen) voor een wijk, met straat eromheen en stoeprand erin.
func _wijk(w: int, d: int) -> Vector2i:
	if _wx + w > W - 1:
		_wx = 1
		_wz += _wrij + 1
		_wrij = 0
	var o := Vector2i(_wx, _wz)
	wijken.append({"naam": _wijk_naam, "x": o.x, "z": o.y, "w": w, "d": d})
	_wx += w + 1
	_wrij = maxi(_wrij, d)
	for x in range(o.x - 1, o.x + w + 1):
		for z in [o.y - 1, o.y + d]:
			if x >= 0 and x < W:
				G(x, z, "weg/weg_vlak", "E")
	for z in range(o.y - 1, o.y + d + 1):
		for x in [o.x - 1, o.x + w]:
			if x >= 0 and x < W:
				G(x, z, "weg/weg_vlak", "S")
	for x in range(o.x, o.x + w):
		for z in range(o.y, o.y + d):
			var sides: Array = _zijden(x, z, o.x, o.y, w, d)
			if sides.size() == 0:
				G(x, z, "natuur/gras")
			elif sides.size() == 1:
				G(x, z, "stoep/stoep_rand", sides[0])
			else:
				G(x, z, "stoep/stoep_hoek_buiten", HOEK[_hoekpaar(sides, "")])
	return o


## Gevels voor een willekeurige verzameling cellen (blootstelling t.o.v. de verzameling zelf).
func _gevels(cellen: Array, stijl: String, lagen: int, bg: Array, verd: Array, bgh: Array, verdh: Array, teller: Dictionary, y0 := 0) -> void:
	var p := stijl + "/" + stijl + "_"
	var set := {}
	for c in cellen:
		set[c] = true
	for c in cellen:
		var sides := []
		for d in ["N", "S", "W", "E"]:
			if not set.has(c + RICHTING[d]):
				sides.append(d)
		var key := _hoekpaar(sides, "N")
		for v in range(lagen):
			var naam := "blok_dicht"
			var rot = "S"
			if sides.size() == 0:
				pass
			elif key == "" or sides.size() == 1:
				var lijst: Array = bg if v == 0 else verd
				if lijst.size() > 0:
					naam = lijst[teller.get("g%d" % mini(v, 1), 0) % lijst.size()]
					teller["g%d" % mini(v, 1)] = teller.get("g%d" % mini(v, 1), 0) + 1
				rot = sides[0]
			else:
				var lijst: Array = bgh if v == 0 else verdh
				if lijst.size() > 0:
					naam = lijst[teller.get("h%d" % mini(v, 1), 0) % lijst.size()]
					teller["h%d" % mini(v, 1)] = teller.get("h%d" % mini(v, 1), 0) + 1
				rot = HOEK[key]
			B(c.x, y0 + v, c.y, p + naam, rot)


## Platte daken op een verzameling cellen, met wisselende varianten per soort.
func _platte_daken(cellen: Array, stijl: String, y: int, soorten: Dictionary, teller: Dictionary) -> void:
	var p := stijl + "/" + stijl + "_"
	var set := {}
	for c in cellen:
		set[c] = true
	for c in cellen:
		var sides := []
		for d in ["N", "S", "W", "E"]:
			if not set.has(c + RICHTING[d]):
				sides.append(d)
		var n := sides.size()
		var soort := "midden"
		var rot = "S"
		if n == 1:
			soort = "rand"
			rot = sides[0]
		elif n == 2:
			var key := _hoekpaar(sides, "")
			if key != "":
				soort = "hoek"
				rot = HOEK[key]
			else:
				soort = "tegenover"
				rot = "S" if sides.has("N") else "E"
		elif n == 3:
			soort = "eind"
			var mis := ""
			for d in ORDE:
				if not sides.has(d):
					mis = d
			rot = (ORDE.find(mis) + 1) % 4
		elif n == 4:
			soort = "los"
		var lijst: Array = soorten.get(soort, [])
		if lijst.is_empty() and soort in ["tegenover", "eind", "los"]:
			lijst = soorten.get("rand", [])
		if lijst.is_empty():
			lijst = soorten.get("midden", [])
		if lijst.is_empty():
			continue
		var i: int = teller.get(soort, 0)
		teller[soort] = i + 1
		B(c.x, y, c.y, p + lijst[i % lijst.size()], rot)


func _lagen_voor(stijl: String) -> int:
	var t := {"jaren30": 4, "jaren60": 2, "galerijflat": 6, "appartement_modern": 8, "luxe_appartement": 6,
		"kantoor_glas": 6, "kantoor_beton": 6, "kantoor_80": 7, "kantoor_2000": 8, "kantoor_modern": 6, "hogeschool": 4,
		"school": 2, "museum_klassiek": 2, "museum_modern": 2, "bedrijfspand": 2, "schuur_zwart": 2, "schuur_rood": 2,
		"kerk_baksteen": 2, "kerk_steen": 3, "kerk_modern": 2}
	return t.get(stijl, 3)


func _demowijken(z0: int) -> int:
	_wx = 1
	_wz = z0 + 1
	_wrij = 0
	# wachtrijen voor details en props
	for nm in _namen(details, ""):
		var g: String = nm.split("/")[0]
		if not _detail_rij.has(g):
			_detail_rij[g] = []
		_detail_rij[g].append(nm)
	for nm in _namen(props, ""):
		var g: String = nm.split("/")[0]
		if g in ["bomen", "planten", "speeltuin"]:
			_prop_groen.append(nm)
		elif g in ["water", "zwembad"]:
			_prop_water.append(nm)
		else:
			_prop_straat.append(nm)
	# een buurt per gebouwstijl
	var stijlen := []
	for nm in _namen(gebouwen, ""):
		var st: String = nm.split("/")[0]
		if not stijlen.has(st) and not st in ["daken", "hallen", "overkapping", "pilaren", "parkeergarage", "overig"]:
			stijlen.append(st)
	for st in stijlen:
		_wijk_naam = "stijl:" + st
		_stijl_buurt(st)
	_dakenwijk()
	_hallen_en_overig()
	_verkeerstuin()
	_kruispunten()
	_verkeerslichten()
	_bedrijventerrein()
	_tint_demo()
	_bochten()
	_dorpskern()
	_lussen_en_spoor()
	_dijk_met_hellingen()
	_tunnelpark()
	_kanaal_met_bruggen()
	_natuurpark()
	_rest_in_context()
	_vergroen(z0, _wz + _wrij + 2)
	return _wz + _wrij + 2


## Bomen en struiken op lege grasvelden in de demowijken.
func _vergroen(z0: int, z1: int) -> void:
	var gras := grond.mesh_library.find_item_by_name("natuur/gras")
	var bomen := ["bomen/linde", "bomen/eik", "bomen/berk", "bomen/kastanje", "bomen/plataan", "planten/struik", "planten/bosje_klein", "bomen/bloesemboom"]
	for x in range(0, W):
		for z in range(z0, z1):
			if grond.get_cell_item(Vector3i(x, 0, z)) != gras:
				continue
			if gebouwen.get_cell_item(Vector3i(x, 0, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			if _r(x * 3, z * 7, 100) < 9:
				Pr(x * 4 + 2.0, z * 4 + 2.0, bomen[_r(x, z, bomen.size())])


# ------------------------------------------------------------------ buurt per gebouwstijl

func _stijl_buurt(stijl: String) -> void:
	var p := stijl + "/" + stijl + "_"
	var bg := []
	var bgh := []
	var verd := []
	var verdh := []
	var vlak_d := {"midden": [], "rand": [], "hoek": [], "tegenover": [], "eind": [], "los": []}
	var schuin := []
	var hb := []
	var hi := []
	var zadel := []
	var zadel_schild := []
	var zadel_hoek := []
	var zadel_t := []
	var toppen := []
	var toren := []
	var penthouse := {}
	var speciaal := []
	for nm in _namen(gebouwen, stijl + "/"):
		var k := _kort(stijl, nm)
		if k == "blok_dicht":
			continue
		if k.begins_with("bg_"):
			(bgh if k.contains("hoek") else bg).append(k)
		elif k.begins_with("verd_"):
			(verdh if k.contains("hoek") else verd).append(k)
		elif k.begins_with("toren_"):
			toren.append(k)
		elif k.begins_with("penthouse_"):
			penthouse[k.trim_prefix("penthouse_")] = k
		elif k.begins_with("gevel_") or k.begins_with("top_"):
			toppen.append(k)
		elif k.contains("koepel") or k.contains("dakruiter") or k.contains("overstek") or k.contains("liftopbouw") or k == "luchtboog":
			speciaal.append(k)
		elif k.begins_with("dak_schuin") or k == "dak_lessenaar" or k == "dak_piramide":
			if k.contains("hoek_buiten"):
				hb.append(k)
			elif k.contains("hoek_binnen"):
				hi.append(k)
			else:
				schuin.append(k)
		elif k.begins_with("dak_zadel"):
			if k.contains("schild"):
				zadel_schild.append(k)
			elif k.contains("hoek"):
				zadel_hoek.append(k)
			elif k.ends_with("_t"):
				zadel_t.append(k)
			else:
				zadel.append(k)
		elif k.begins_with("dak_"):
			var soort := "midden"
			for s in ["rand", "hoek", "tegenover", "eind", "los"]:
				if k.ends_with("_" + s) or k.contains("_" + s + "_"):
					soort = s
			if k.contains("terras") or k.contains("zwembad") or k.contains("daktuin"):
				soort = "rand"
			if k == "dak_kantelen_toren":
				soort = "los"
			vlak_d[soort].append(k)
		else:
			speciaal.append(k)
	var lagen := _lagen_voor(stijl)
	var heeft_plat: bool = not (vlak_d["midden"].is_empty() and vlak_d["rand"].is_empty())
	var heeft_schuin := not schuin.is_empty()
	var nA := clampi(maxi(ceili(bg.size() / 2.0), ceili(verd.size() / 1.5)), 5, 14)
	var dA := 2
	if heeft_plat:
		dA = 2 + maxi(1, ceili(vlak_d["midden"].size() / float(maxi(1, nA - 2))))
	# breedte van de tweede rij uitrekenen
	var rij2 := 0
	if heeft_schuin and not hi.is_empty():
		rij2 += 6
	if not zadel.is_empty() or not zadel_schild.is_empty():
		rij2 += 4
	if not zadel_t.is_empty():
		rij2 += 4
	rij2 += 5                                  # klein rijtje voor eind/tegenover/los
	rij2 += toppen.size() + 1
	if not toren.is_empty():
		rij2 += 3
	rij2 += speciaal.size() * 2
	var w := maxi(nA + 6, mini(rij2 + 2, 60)) + 2
	var d := 2 + dA + 2 + 5 + 2 + 3 + 1 + (3 if heeft_schuin and hi.is_empty() else 0)
	var o := _wijk(w, d)
	var cx := o.x + 1
	var cz := o.y + 1
	var teller := {}
	# --- bouwblok A: voorkant naar het noorden (straat), achter tuinen
	var cellen := []
	for x in range(cx + 1, cx + 1 + nA):
		for z in range(cz + 1, cz + 1 + dA):
			cellen.append(Vector2i(x, z))
	var lagen_a := lagen
	_gevels(cellen, stijl, lagen_a, bg, verd, bgh, verdh, teller)
	var dak_y := lagen_a
	if not penthouse.is_empty():
		var pt := {"rand": [penthouse.get("rand", "")], "hoek": [penthouse.get("hoek", "")], "tegenover": [penthouse.get("tegenover", "")], "midden": [penthouse.get("midden", "")]}
		for k in pt.keys():
			if pt[k][0] == "":
				pt.erase(k)
		_platte_daken(cellen, stijl, dak_y, pt, {})
		dak_y += 1
	if heeft_plat:
		_platte_daken(cellen, stijl, dak_y, vlak_d, teller)
	elif heeft_schuin:
		for c in cellen:
			var sides := []
			for dd in ["N", "S", "W", "E"]:
				if not cellen.has(c + RICHTING[dd]):
					sides.append(dd)
			var key := _hoekpaar(sides, "N")
			if key != "" and sides.size() >= 2:
				B(c.x, dak_y, c.y, p + hb[teller.get("hb", 0) % hb.size()] if not hb.is_empty() else p + schuin[0], HOEK[key])
				teller["hb"] = teller.get("hb", 0) + 1
			else:
				B(c.x, dak_y, c.y, p + schuin[teller.get("sch", 0) % schuin.size()], sides[0])
				teller["sch"] = teller.get("sch", 0) + 1
	# tuinen achter blok A
	var zt := cz + 1 + dA
	vlak(cx + 1, zt, cx + nA, zt + 1, "natuur/gras_kort")
	for x in range(cx + 1, cx + 1 + nA):
		_prop(x * 4 + 2.0, (zt + 2) * 4 - 0.5, "groen")
	# --- tweede rij: hofje, zadeldaken, rijtje, toppen, toren, specials
	var rx := cx + 1
	var rz := cz + dA + 4
	if heeft_schuin and not hi.is_empty():
		var ring_cellen := []
		for x in range(rx, rx + 5):
			for z in range(rz, rz + 5):
				if x == rx + 2 and z == rz + 2:
					continue
				ring_cellen.append(Vector2i(x, z))
		_gevels(ring_cellen, stijl, maxi(1, mini(lagen, 3)), bg, verd, bgh, verdh, teller)
		var yr := maxi(1, mini(lagen, 3))
		for c in ring_cellen:
			var sides := []
			for dd in ["N", "S", "W", "E"]:
				if not ring_cellen.has(c + RICHTING[dd]):
					sides.append(dd)
			if sides.size() == 0:
				# binnenhoek: lage hoek richting het hofje
				var dx: int = (rx + 2) - c.x
				var dz: int = (rz + 2) - c.y
				var dk: String = ("S" if dz > 0 else "N") + ("E" if dx > 0 else "W")
				var map := {"SE": "SE", "SW": "WS", "NE": "EN", "NW": "NW"}
				B(c.x, yr, c.y, p + hi[teller.get("hi", 0) % hi.size()], HOEK[map[dk]])
				teller["hi"] = teller.get("hi", 0) + 1
			elif sides.size() >= 2:
				var key := _hoekpaar(sides, "")
				B(c.x, yr, c.y, p + hb[teller.get("hb", 0) % hb.size()], HOEK[key])
				teller["hb"] = teller.get("hb", 0) + 1
			else:
				B(c.x, yr, c.y, p + schuin[teller.get("sch", 0) % schuin.size()], sides[0])
				teller["sch"] = teller.get("sch", 0) + 1
		G(rx + 2, rz + 2, "natuur/gras_bloemen")
		_prop((rx + 2) * 4 + 2.0, (rz + 2) * 4 + 2.0, "groen")
		rx += 6
	if not zadel.is_empty() or not zadel_schild.is_empty():
		# L-vorm (1 diep) met zadeldaken, schild-einden en een L-hoek
		var lc := [Vector2i(rx, rz + 2), Vector2i(rx + 1, rz + 2), Vector2i(rx + 2, rz + 2), Vector2i(rx + 2, rz + 1), Vector2i(rx + 2, rz)]
		_gevels(lc, stijl, 1, bg, verd, bgh, verdh, teller)
		var zs: String = zadel_schild[0] if not zadel_schild.is_empty() else zadel[0]
		var zz: String = zadel[teller.get("z", 0) % zadel.size()] if not zadel.is_empty() else zs
		B(rx, 1, rz + 2, p + zs, "N")
		B(rx + 1, 1, rz + 2, p + zz, "S")
		B(rx + 2, 1, rz + 2, p + (zadel_hoek[0] if not zadel_hoek.is_empty() else zz), "SE")
		B(rx + 2, 1, rz + 1, p + (zadel[1 % zadel.size()] if not zadel.is_empty() else zs), "E")
		B(rx + 2, 1, rz, p + zs, "E")
		# overige zadel-varianten op een los rijtje van 3
		var extra := zadel.slice(2) if zadel.size() > 2 else []
		var zr := rz + 4
		if not extra.is_empty():
			var rc := [Vector2i(rx, zr), Vector2i(rx + 1, zr), Vector2i(rx + 2, zr)]
			_gevels(rc, stijl, 1, bg, verd, bgh, verdh, teller)
			B(rx, 1, zr, p + zs, "N")
			B(rx + 1, 1, zr, p + extra[0], "S")
			B(rx + 2, 1, zr, p + zs, "S")
		rx += 4
	if not zadel_t.is_empty():
		var tc := [Vector2i(rx, rz + 1), Vector2i(rx + 1, rz + 1), Vector2i(rx + 2, rz + 1), Vector2i(rx + 1, rz)]
		_gevels(tc, stijl, 1, bg, verd, bgh, verdh, teller)
		var zs2: String = zadel_schild[0] if not zadel_schild.is_empty() else zadel_t[0]
		B(rx + 1, 1, rz + 1, p + zadel_t[0], "S")
		B(rx, 1, rz + 1, p + zs2, "N")
		B(rx + 2, 1, rz + 1, p + zs2, "S")
		B(rx + 1, 1, rz, p + zs2, "E")
		rx += 4
	if heeft_schuin and hi.is_empty():
		var sc := []
		var bw := maxi(2, ceili(schuin.size() / 2.0) + 2)
		for x in range(cx + 1, cx + 1 + bw):
			for z in [cz + d - 9, cz + d - 8]:
				sc.append(Vector2i(x, z))
		_gevels(sc, stijl, 1, bg, verd, bgh, verdh, teller)
		var si := 0
		for c in sc:
			var sides := []
			for dd in ["N", "S", "W", "E"]:
				if not sc.has(c + RICHTING[dd]):
					sides.append(dd)
			if sides.size() >= 2 and not hb.is_empty():
				B(c.x, 1, c.y, p + hb[0], HOEK[_hoekpaar(sides, "")])
			else:
				B(c.x, 1, c.y, p + schuin[si % schuin.size()], sides[0] if sides.size() == 1 else "N")
				si += 1
	# klein rijtje (1 diep) + losstaand pand: eind / tegenover / los
	var kc := [Vector2i(rx, rz), Vector2i(rx + 1, rz), Vector2i(rx + 2, rz)]
	_gevels(kc, stijl, maxi(1, mini(lagen, 2)), bg, verd, bgh, verdh, teller)
	var ky := maxi(1, mini(lagen, 2))
	if not penthouse.is_empty():
		var pt2 := {}
		for k2 in penthouse.keys():
			pt2[k2] = [penthouse[k2]]
		_platte_daken(kc, stijl, ky, pt2, {})
		ky += 1
	if heeft_plat:
		_platte_daken(kc, stijl, ky, vlak_d, teller)
	_gevels([Vector2i(rx, rz + 2)], stijl, 1, bg, verd, bgh, verdh, teller)
	if heeft_plat:
		_platte_daken([Vector2i(rx, rz + 2)], stijl, 1, vlak_d, teller)
	rx += 4
	# smalle panden met elk een andere top (grachtengevel, lijstgevel, fronton, ...)
	for i in toppen.size():
		var x: int = rx + i
		var hc := [Vector2i(x, rz), Vector2i(x, rz + 1)]
		_gevels(hc, stijl, maxi(2, mini(lagen, 3)), bg, verd, bgh, verdh, teller)
		var yt := maxi(2, mini(lagen, 3))
		B(x, yt, rz, p + toppen[i], "N")
		if not zadel.is_empty():
			B(x, yt, rz + 1, p + zadel[0], "E")
		elif heeft_plat:
			B(x, yt, rz + 1, p + vlak_d["rand"][0] if not vlak_d["rand"].is_empty() else p + vlak_d["midden"][0], "S")
	if not toppen.is_empty():
		rx += toppen.size() + 1
	# toren(s)
	if not toren.is_empty():
		var volgorde := ["toren_portaal", "toren_raam", "toren_galmgat", "toren_klok", "toren_spits_onder", "toren_spits_boven"]
		var t1 := []
		for t in volgorde:
			if toren.has(t):
				t1.append(t)
		if t1.is_empty() or not t1[0] in ["toren_portaal", "toren_raam"]:
			t1.push_front("blok_dicht")
			t1.push_front("blok_dicht")
		toren(rx, rz + 1, stijl, t1, "N")
		if toren.has("toren_pinakels"):
			toren(rx + 1, rz + 1, stijl, ["blok_dicht", "toren_raam" if toren.has("toren_raam") else "blok_dicht", "toren_pinakels"], "N")
		if toren.has("toren_beton"):
			toren(rx + 1, rz + 3, stijl, ["toren_beton", "toren_beton", "toren_beton_klok" if toren.has("toren_beton_klok") else "toren_beton"], "N")
		rx += 3
	# bijzondere daken op eigen pandjes
	for k in speciaal:
		if k.ends_with("3x3"):
			var dc := []
			for x in range(rx, rx + 3):
				for z in range(rz, rz + 3):
					dc.append(Vector2i(x, z))
			_gevels(dc, stijl, 1, bg, verd, bgh, verdh, teller)
			B(rx + 1, 1, rz + 1, p + k, "S")
			rx += 4
		elif k == "luchtboog":
			_gevels([Vector2i(rx, rz + 1), Vector2i(rx + 1, rz + 1)], stijl, 2, bg, verd, bgh, verdh, teller)
			B(rx, 0, rz, p + k, "N")
			B(rx + 1, 0, rz, p + k, "N")
			rx += 3
		else:
			_gevels([Vector2i(rx, rz)], stijl, 1, bg, verd, bgh, verdh, teller)
			B(rx, 1, rz, p + k, "N")
			rx += 2
	# --- detailpand: een blanco pand waarop gevel- en dakonderdelen worden aangebracht
	_detailpand(cx + 1, cz + d - 6, stijl)
	# straatmeubilair langs de noordrand
	for x in range(o.x + 1, o.x + w - 1, 2):
		_prop(x * 4 + 2.0, o.y * 4 + 0.75, "straat")


func _pak_detail(groep: String) -> String:
	if not _detail_rij.has(groep) or _detail_rij[groep].is_empty():
		return ""
	var lijst: Array = _detail_rij[groep]
	var nm: String = lijst.pop_front()
	lijst.push_back(nm)  # blijft rouleren
	return nm


var _detail_gebruikt := {}


func _pak_detail_nieuw(groep: String) -> String:
	if not _detail_rij.has(groep):
		return ""
	for nm in _detail_rij[groep]:
		if not _detail_gebruikt.has(nm):
			_detail_gebruikt[nm] = true
			return nm
	return _pak_detail(groep)


func _detailpand(x0: int, z0: int, stijl: String) -> void:
	var basis := stijl + "/" + stijl + "_blok_dicht"
	if not _heeft(basis):
		basis = "klassiek_rood/klassiek_rood_blok_dicht"
	for x in range(x0, x0 + 4):
		for z in range(z0, z0 + 2):
			B(x, 0, z, basis, "S")
			B(x, 1, z, basis, "S")
			B(x, 2, z, "modern_wit/modern_wit_dak_plat_" + ("hoek" if (x == x0 or x == x0 + 3) else "rand"),
				("WS" if x == x0 else "SE") if (x == x0 or x == x0 + 3) else "S")
	var fz := (z0 + 2) * 4.0  # zuidgevel
	for i in 4:
		var mx := (x0 + i) * 4 + 2.0
		var deur := _pak_detail_nieuw("deuren")
		if deur != "":
			D(mx, fz, 0.0, deur, "S")
		var boven := _pak_detail_nieuw("luifels") if i % 2 == 0 else _pak_detail_nieuw("zonwering")
		if boven != "":
			D(mx, fz, 2.5, boven, "S")
		var raam := _pak_detail_nieuw("ramen")
		if raam != "":
			D(mx, fz, 3.5, raam, "S")
		var g := _pak_detail_nieuw("gevel")
		if g != "":
			D((x0 + i) * 4 + 0.5, fz, 1.0, g, "S")
	var tekst := _pak_detail_nieuw("tekst")
	if tekst != "":
		D((x0 + 2) * 4.0, fz, 5.0, tekst, "S")
	var tekst2 := _pak_detail_nieuw("tekst")
	if tekst2 != "":
		D((x0 + 2) * 4.0, z0 * 4.0, 5.0, tekst2, "N")
	var balkon := _pak_detail_nieuw("balkons")
	if balkon != "":
		D(x0 * 4.0, (z0 + 1) * 4.0, 3.0, balkon, "W")
	for i in 2:
		var dk := _pak_detail_nieuw("dak")
		if dk != "":
			D((x0 + 1 + i * 2) * 4.0, (z0 + 1) * 4.0, 6.0, dk, "S")


func _prop(wx: float, wz: float, soort: String, wy := 0.0) -> void:
	var lijst: Array = _prop_straat if soort == "straat" else (_prop_groen if soort == "groen" else _prop_water)
	if lijst.is_empty():
		return
	var i := _pi_s if soort == "straat" else (_pi_g if soort == "groen" else _pi_w)
	var nm: String = lijst[i % lijst.size()]
	if soort == "straat": _pi_s += 1
	elif soort == "groen": _pi_g += 1
	else: _pi_w += 1
	Pr(wx, wz, nm, "S", wy)


# ------------------------------------------------------------------ dakenwijk: alle dakpansoorten en kapvormen

func _dakenwijk() -> void:
	var soorten := []
	for nm in _namen(gebouwen, "daken/"):
		var s: String = nm.split("/")[1]
		if not soorten.has(s):
			soorten.append(s)
	for s in soorten:
		var p: String = "daken/" + s + "/" + s + "_"
		var vormen := []
		for nm in _namen(gebouwen, "daken/" + s + "/"):
			vormen.append(nm.split("/")[2].trim_prefix(s + "_"))
		_wijk_naam = "dak:" + s
		var o := _wijk(22, 10)
		var muur: String = "jaren30/jaren30_" if s.begins_with("pannen") else "klassiek_rood/klassiek_rood_"
		var cx := o.x + 2
		var cz := o.y + 2
		# rij van 2 diep: schuine kappen met hoekkepers, varianten in het midden
		var rij := []
		for x in range(cx, cx + 6):
			for z in [cz, cz + 1]:
				rij.append(Vector2i(x, z))
		_gevels(rij, muur.split("/")[0], 2, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
		var vi := 0
		var mid := []
		for v in ["schuin", "schuin_dakkapel", "schuin_schoorsteen", "schuin_afgeplat"]:
			if vormen.has(v):
				mid.append(v)
		for c in rij:
			var sides := []
			for d in ["N", "S", "W", "E"]:
				if not rij.has(c + RICHTING[d]):
					sides.append(d)
			if sides.size() >= 2:
				var hoek: String = "schuin_afgeplat_hoek_buiten" if (c.x == cx and vormen.has("schuin_afgeplat_hoek_buiten")) else "schuin_hoek_buiten"
				B(c.x, 2, c.y, p + hoek, HOEK[_hoekpaar(sides, "")])
			else:
				B(c.x, 2, c.y, p + mid[vi % mid.size()], sides[0])
				vi += 1
		# L-vorm met binnenhoek (kilkeper)
		var lx := cx + 7
		var lc := [Vector2i(lx, cz), Vector2i(lx + 1, cz), Vector2i(lx, cz + 1), Vector2i(lx + 1, cz + 1),
			Vector2i(lx + 2, cz), Vector2i(lx + 3, cz), Vector2i(lx + 2, cz + 1), Vector2i(lx + 3, cz + 1),
			Vector2i(lx, cz + 2), Vector2i(lx + 1, cz + 2), Vector2i(lx, cz + 3), Vector2i(lx + 1, cz + 3)]
		_gevels(lc, muur.split("/")[0], 1, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
		B(lx, 1, cz, p + "schuin_hoek_buiten", "NW")
		B(lx + 1, 1, cz, p + "schuin", "N")
		B(lx + 2, 1, cz, p + "schuin", "N")
		B(lx + 3, 1, cz, p + "schuin_hoek_buiten", "EN")
		B(lx + 3, 1, cz + 1, p + "schuin_hoek_buiten", "SE")
		B(lx + 2, 1, cz + 1, p + "schuin", "S")
		B(lx + 1, 1, cz + 1, p + "schuin_hoek_binnen", "SE")
		B(lx, 1, cz + 1, p + "schuin", "W")
		B(lx, 1, cz + 2, p + "schuin", "W")
		B(lx + 1, 1, cz + 2, p + "schuin", "E")
		B(lx, 1, cz + 3, p + "schuin_hoek_buiten", "WS")
		B(lx + 1, 1, cz + 3, p + "schuin_hoek_buiten", "SE")
		# tweede L-vorm met afgeknotte kappen
		if vormen.has("schuin_afgeplat_hoek_binnen"):
			var ax := cx
			var az := cz + 4
			var ac := [Vector2i(ax, az), Vector2i(ax + 1, az), Vector2i(ax + 2, az), Vector2i(ax + 3, az),
				Vector2i(ax, az + 1), Vector2i(ax + 1, az + 1), Vector2i(ax + 2, az + 1), Vector2i(ax + 3, az + 1),
				Vector2i(ax, az + 2), Vector2i(ax + 1, az + 2), Vector2i(ax, az + 3), Vector2i(ax + 1, az + 3)]
			_gevels(ac, muur.split("/")[0], 1, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
			B(ax, 1, az, p + "schuin_afgeplat_hoek_buiten", "NW")
			B(ax + 1, 1, az, p + "schuin_afgeplat", "N")
			B(ax + 2, 1, az, p + "schuin_afgeplat", "N")
			B(ax + 3, 1, az, p + "schuin_afgeplat_hoek_buiten", "EN")
			B(ax + 3, 1, az + 1, p + "schuin_afgeplat_hoek_buiten", "SE")
			B(ax + 2, 1, az + 1, p + "schuin_afgeplat", "S")
			B(ax + 1, 1, az + 1, p + "schuin_afgeplat_hoek_binnen", "SE")
			B(ax, 1, az + 1, p + "schuin_afgeplat", "W")
			B(ax, 1, az + 2, p + "schuin_afgeplat", "W")
			B(ax + 1, 1, az + 2, p + "schuin_afgeplat", "E")
			B(ax, 1, az + 3, p + "schuin_afgeplat_hoek_buiten", "WS")
			B(ax + 1, 1, az + 3, p + "schuin_afgeplat_hoek_buiten", "SE")
		# zadeldaken (1 diep), L-hoek en T
		var zx := cx + 12
		var zc := [Vector2i(zx, cz + 2), Vector2i(zx + 1, cz + 2), Vector2i(zx + 2, cz + 2), Vector2i(zx + 2, cz + 1), Vector2i(zx + 2, cz)]
		_gevels(zc, muur.split("/")[0], 1, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
		B(zx, 1, cz + 2, p + "zadel_schild", "N")
		B(zx + 1, 1, cz + 2, p + ("zadel_afgeplat" if vormen.has("zadel_afgeplat") else "zadel"), "S")
		B(zx + 2, 1, cz + 2, p + "zadel_hoek", "SE")
		B(zx + 2, 1, cz + 1, p + "zadel", "E")
		B(zx + 2, 1, cz, p + "zadel_schild", "E")
		var tx := cx + 16
		if vormen.has("zadel_t"):
			var tc := [Vector2i(tx, cz + 1), Vector2i(tx + 1, cz + 1), Vector2i(tx + 2, cz + 1), Vector2i(tx + 1, cz)]
			_gevels(tc, muur.split("/")[0], 1, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
			B(tx + 1, 1, cz + 1, p + "zadel_t", "S")
			B(tx, 1, cz + 1, p + "zadel_schild", "N")
			B(tx + 2, 1, cz + 1, p + "zadel_schild", "S")
			B(tx + 1, 1, cz, p + "zadel_schild", "E")
		# piramide- en lessenaarsdak op losse schuurtjes
		for i in 2:
			var nm2: String = ["piramide", "lessenaar"][i]
			if vormen.has(nm2):
				_gevels([Vector2i(tx + i * 2, cz + 4)], muur.split("/")[0], 1, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
				B(tx + i * 2, 1, cz + 4, p + nm2, "S")
		for x in range(o.x + 1, o.x + 21, 3):
			_prop(x * 4 + 2.0, (o.y + 9) * 4 + 3.0, "groen")


# ------------------------------------------------------------------ hallen, overkappingen, pilaren, parkeergarage, radiotoren

func _hallen_en_overig() -> void:
	_wijk_naam = "hallen"
	var o := _wijk(30, 14)
	var x0 := o.x + 2
	var z0 := o.y + 2
	# drie holle hallen naast elkaar (glas, zwembad, sport) met dak-varianten
	var hs := ["hal_glas", "hal_zwembad", "hal_sport"]
	for i in 3:
		var hx := x0 + i * 6
		for x in range(hx, hx + 5):
			for z in range(z0, z0 + 4):
				var sides: Array = _zijden(x, z, hx, z0, 5, 4)
				var st: String = "hallen/" + hs[i] + "_"
				if sides.size() == 0:
					B(x, 0, z, st + ("dak_kolom" if x == hx + 2 else "dak"), "S")
				elif sides.size() == 1:
					var nm: String = "wand_deur_dak" if (x == hx + 2 and z == z0 + 3) else "wand_dak"
					B(x, 0, z, st + nm, sides[0])
				else:
					B(x, 0, z, st + "hoek_dak", HOEK[_hoekpaar(sides, "")])
		# open wand-varianten zonder dak als hoge hal (2 lagen)
		for x in range(hx, hx + 5):
			var sides2 := ["N"] if x != hx and x != hx + 4 else (["N", "W"] if x == hx else ["N", "E"])
			if sides2.size() == 1:
				B(x, 1, z0, "hallen/" + hs[i] + "_wand", "N")
			else:
				B(x, 1, z0, "hallen/" + hs[i] + "_hoek", HOEK[_hoekpaar(sides2, "")])
		vlak(hx, z0, hx + 4, z0 + 3, "zwembad/zwembad_kant_tegels" if i == 1 else "plein/plein_tegels")
	# overkapping en pilaren
	for x in range(x0, x0 + 6):
		for z in range(z0 + 6, z0 + 9):
			B(x, 0, z, "overkapping/overkapping_glas_kolom" if (x - x0) % 2 == 0 and z == z0 + 6 else "overkapping/overkapping_glas", "S")
	var pil := _namen(gebouwen, "pilaren/")
	for i in pil.size():
		B(x0 + 8 + i, 0, z0 + 7, pil[i], "N")
	# parkeergarage met alle onderdelen
	var gx := x0 + 18
	var gz := z0 + 6
	for x in range(gx, gx + 4):
		for z in range(gz, gz + 4):
			var sides: Array = _zijden(x, z, gx, gz, 4, 4)
			for v in range(2):
				var kind: String = "dak" if v == 1 else "dek"
				if sides.size() == 0:
					B(x, v, z, "parkeergarage/parkeergarage_%s_midden" % kind, "S")
				elif sides.size() == 1:
					B(x, v, z, "parkeergarage/parkeergarage_%s_rand" % kind, sides[0])
				else:
					B(x, v, z, "parkeergarage/parkeergarage_%s_hoek" % kind, HOEK[_hoekpaar(sides, "")])
	B(gx, 0, gz + 1, "parkeergarage/parkeergarage_inrit", "W")
	B(gx + 1, 0, gz + 1, "parkeergarage/parkeergarage_helling", "N")
	B(gx + 2, 0, gz + 2, "parkeergarage/parkeergarage_helling_rand", "S")
	B(gx + 4, 0, gz, "parkeergarage/parkeergarage_trappenhuis", "S")
	B(gx + 4, 1, gz, "parkeergarage/parkeergarage_trappenhuis", "S")
	# radiotoren
	B(x0 + 26, 0, z0 + 2, "overig/radiotoren_voet", "S")
	for v in range(1, 8):
		B(x0 + 26, v, z0 + 2, "overig/radiotoren_segment", "S")
	B(x0 + 26, 8, z0 + 2, "overig/radiotoren_top", "S")


# ------------------------------------------------------------------ verkeerstuin: doorlopende straten met alle markeringen

func _verkeerstuin() -> void:
	_wijk_naam = "verkeerstuin"
	var tiles := []
	for groep in ["weg/", "tram/", "fietspad/", "parkeren/", "snelweg/"]:
		for nm in _namen(grond, groep):
			var k: String = nm.split("/")[1]
			if k.contains("bocht") or k.ends_with("_t") or k.contains("3x3") or k.contains("eind") or k == "tram_kruising" \
					or k == "fietspad_kruising" or k.contains("perron") or k.contains("middengeleider_kop"):
				continue
			tiles.append(nm)
	var stoepen := []
	for nm in _namen(grond, "stoep/"):
		var k: String = nm.split("/")[1]
		if k in ["stoep_rand", "stoep_goot_rand", "stoep_goot_kolk", "stoep_oprit", "stoep_goot_oprit", "stoep_ribbel",
				"stoep_boomrooster", "stoep_klinker_rand", "stoep_inrit_breed", "stoep_vol", "stoep_klinker_vol"]:
			stoepen.append(nm)
	var per_straat := 18
	var straten := ceili(tiles.size() / float(per_straat))
	var o := _wijk(straten * 6 + 1, per_straat * 2 + 2)
	for s in straten:
		var x: int = o.x + 1 + s * 6
		for i in per_straat:
			var idx: int = s * per_straat + i
			if idx >= tiles.size():
				break
			var nm: String = tiles[idx]
			var st: String = stoepen[idx % stoepen.size()]
			for r in 2:
				var z: int = o.y + 1 + i * 2 + r
				G(x, z, st, "E")
				G(x + 1, z, nm, "N")
				G(x + 2, z, nm, "S")
				G(x + 3, z, st, "W")
			if i % 3 == 0:
				_prop((x - 0.0) * 4 + 3.0, (o.y + 1 + i * 2) * 4 + 4.0, "straat")
				_prop((x + 4) * 4 + 1.0, (o.y + 1 + i * 2) * 4 + 4.0, "straat")
		vlak(x + 4, o.y + 1, x + 4, o.y + per_straat * 2, "natuur/gras")


# ------------------------------------------------------------------ fietslus, tramlus en spoorwegemplacement

func _lus(x0: int, z0: int, bocht: String, recht_lijst: Array, t: String, kruising: String, eind: String) -> void:
	var x1 := x0 + 4
	var z1 := z0 + 4
	G(x0, z0, bocht, "S")
	G(x1, z0, bocht, "W")
	G(x1, z1, bocht, "N")
	G(x0, z1, bocht, "E")
	var i := 0
	for x in range(x0 + 1, x1):
		if x == x0 + 2:
			continue
		G(x, z0, recht_lijst[i % recht_lijst.size()], "E"); i += 1
		G(x, z1, recht_lijst[i % recht_lijst.size()], "E"); i += 1
	for z in range(z0 + 1, z1):
		if z == z0 + 2:
			continue
		G(x0, z, recht_lijst[i % recht_lijst.size()], "S"); i += 1
		G(x1, z, recht_lijst[i % recht_lijst.size()], "S"); i += 1
	G(x0 + 2, z0, t, "W")
	G(x0, z0 + 2, t, "S")
	G(x1, z0 + 2, t, "N")
	G(x0 + 2, z1, t, "W")
	G(x0 + 2, z1 + 1, eind if eind != "" else recht_lijst[0], "N")
	G(x0 + 2, z0 + 2, kruising, "S")
	G(x0 + 2, z0 + 1, recht_lijst[0], "S")
	G(x0 + 2, z0 + 3, recht_lijst[0], "S")
	G(x0 + 1, z0 + 2, recht_lijst[0], "E")
	G(x0 + 3, z0 + 2, recht_lijst[0], "E")
	for c in [[x0 + 1, z0 + 1], [x0 + 3, z0 + 1], [x0 + 1, z0 + 3], [x0 + 3, z0 + 3]]:
		G(c[0], c[1], "natuur/gras_bloemen")


func _lussen_en_spoor() -> void:
	_wijk_naam = "lussen"
	var o := _wijk(40, 12)
	var x0 := o.x + 2
	var z0 := o.y + 2
	vlak(o.x + 1, o.y + 1, o.x + 38, o.y + 10, "natuur/gras")
	# fietslus
	var fr := []
	for nm in _namen(grond, "fietspad/"):
		var k: String = nm.split("/")[1]
		if not (k.contains("bocht") or k.ends_with("_t") or k.contains("kruising") or k.contains("eind")):
			fr.append(nm)
	_lus(x0, z0, "fietspad/fietspad_bocht", fr, "fietspad/fietspad_t", "fietspad/fietspad_kruising", "fietspad/fietspad_eind")
	_prop((x0 + 1) * 4 + 2.0, (z0 + 1) * 4 + 2.0, "groen")
	# tramlus
	var tr := ["tram/tram_recht", "tram/tram_klinker_recht", "tram/tram_gras_recht", "tram/trambaan_vrij", "tram/trambaan_vrij_gras"]
	var tx := x0 + 7
	_lus(tx, z0, "tram/tram_bocht", tr, "tram/tram_t", "tram/tram_kruising", "")
	G(tx, z0 + 4, "tram/tram_gras_bocht", "E")
	G(tx - 1, z0 + 1, "tram/tram_halte_perron", "E")
	G(tx + 5, z0 + 1, "tram/tramhalte_middenperron", "S")
	G(tx + 7, z0 + 2, "tram/tram_bocht_groot_3x3", "S")
	for x in range(tx + 6, tx + 9):
		for z in range(z0 + 1, z0 + 4):
			if not (x == tx + 7 and z == z0 + 2):
				grond.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	# spoorwegemplacement: lus met kleine bochten, overweg, wissel, perron, stootblok, grote bocht
	var sx := x0 + 18
	_lus(sx, z0, "spoor/trein_bocht", ["spoor/trein_recht", "spoor/trein_bovenleiding_recht"], "spoor/trein_recht", "spoor/trein_recht", "spoor/trein_stootblok")
	G(sx + 4, z0 + 5, "spoor/tram_gras_kruising_weg", "E")
	G(sx + 2, z0, "spoor/trein_overweg", "S")
	G(sx + 2, z0 - 1, "weg/weg_vlak")
	G(sx + 2, z0 + 4, "spoor/trein_overweg_fiets", "S")
	G(sx, z0 + 2, "spoor/trein_wissel", "S")
	G(sx + 2, z0 + 2, "spoor/trein_recht", "S")
	G(sx - 1, z0 + 1, "spoor/perron", "E")
	G(sx - 1, z0 + 2, "spoor/perron_midden")
	G(sx - 1, z0 + 3, "spoor/perron_trap", "N")
	G(sx + 8, z0 + 2, "spoor/trein_bocht_groot_3x3", "S")
	for x in range(sx + 7, sx + 10):
		for z in range(z0 + 1, z0 + 4):
			if not (x == sx + 8 and z == z0 + 2):
				grond.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	_prop((sx + 1) * 4 + 2.0, (z0 - 1) * 4 + 3.0, "straat")


# ------------------------------------------------------------------ dijk met alle hellingen als opritten

func _dijk_met_hellingen() -> void:
	_wijk_naam = "dijk"
	var hel := _namen(grond, "helling/")
	var heuvel := _namen(grond, "heuvel/")
	var o := _wijk(mini(hel.size() + 4, 92), 7 * ceili((hel.size() + 4) / 90.0) + 1)
	var x := o.x + 1
	var z := o.y + 1
	for nm in hel:
		if x > o.x + 89:
			x = o.x + 1
			z += 7
		var k: String = nm.split("/")[1]
		var bron: String = k.trim_prefix("helling_brug_").trim_prefix("helling_").trim_prefix("flauw_")
		bron = bron.trim_suffix("_rand").trim_suffix("_a").trim_suffix("_b")
		var vlakke: String = _zoek_grond(bron)
		if vlakke == "" or k.contains("hoek"):
			vlakke = "natuur/gras"
		# dijk: grondblok met de vlakke tile erop
		G(x, z, "terrein/grond_blok")
		G(x, z, vlakke, "S", 1)
		if k.begins_with("flauw_") and k.ends_with("_a"):
			G(x, z + 1, nm.replace("_a", "_b") if grond.mesh_library.find_item_by_name(nm.replace("_a", "_b")) >= 0 else vlakke)
			G(x, z + 2, nm)
			G(x, z + 3, vlakke)
		elif k.begins_with("flauw_") and k.ends_with("_b"):
			G(x, z + 1, nm)
			G(x, z + 2, nm.replace("_b", "_a") if grond.mesh_library.find_item_by_name(nm.replace("_b", "_a")) >= 0 else vlakke)
			G(x, z + 3, vlakke)
		else:
			G(x, z + 1, nm, "S")
			G(x, z + 2, vlakke)
			G(x, z + 3, vlakke)
		x += 1
	# heuvels van gras, zand en grind
	var hx := o.x + 1
	var hz := z + 4
	for mat in ["gras", "zand", "grind"]:
		var p: String = "heuvel/heuvel_" + mat + "_"
		G(hx + 1, hz + 1, p + "blok")
		G(hx + 1, hz + 1, p + "top", "S", 1)
		G(hx + 1, hz, p + "helling", "S")
		G(hx + 1, hz + 2, p + "helling", "N")
		G(hx, hz + 1, p + "helling", "E")
		G(hx + 2, hz + 1, p + "helling", "W")
		G(hx, hz, p + "hoek_buiten", "SE")
		G(hx + 2, hz, p + "hoek_buiten", "WS")
		G(hx, hz + 2, p + "hoek_buiten", "EN")
		G(hx + 2, hz + 2, p + "hoek_buiten", "NW")
		G(hx + 3, hz + 1, p + "hoek_binnen", "S")
		hx += 5


# ------------------------------------------------------------------ tunnelpark: verdiepte wegen en tunnels

func _sleuf(x: int, z: int, naam: String, diepte: int, rot = "S") -> void:
	grond.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	G(x, z, naam, rot, -diepte)
	bezet[Vector2i(x, z)] = true


func _tunnelpark() -> void:
	_wijk_naam = "tunnelpark"
	var o := _wijk(40, 26)
	vlak(o.x + 1, o.y + 1, o.x + 38, o.y + 24, "natuur/gras")
	var z0 := o.y + 2
	# A: autotunnel (3 stroken) met toerit, open bak, portaal en tunnel met weg erboven
	var x := o.x + 2
	for d in range(1, 7):
		_sleuf(x, z0 + d - 1, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_sleuf(x + 1, z0 + d - 1, "tunnel/tunnel_toerit_d%d" % d, d)
		_sleuf(x + 2, z0 + d - 1, "tunnel/tunnel_toerit_wand_rechts_d%d" % d, d)
	for r in range(2):
		_sleuf(x, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_wand_d6", 6)
		_sleuf(x + 1, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_d6", 6)
		_sleuf(x + 2, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_wand_rechts_d6", 6)
	G(x, z0 + 8, "tunnel/tunnel_rijstrook_wand_portaal", "S", -6)
	G(x + 1, z0 + 8, "tunnel/tunnel_rijstrook_portaal", "S", -6)
	G(x + 2, z0 + 8, "tunnel/tunnel_rijstrook_wand_rechts_portaal", "S", -6)
	for r in range(9, 14):
		G(x, z0 + r, "tunnel/tunnel_rijstrook_wand", "S", -6)
		G(x + 1, z0 + r, "tunnel/tunnel_middenwand" if r == 11 else "tunnel/tunnel_rijstrook", "S", -6)
		G(x + 2, z0 + r, "tunnel/tunnel_rijstrook_wand_rechts", "S", -6)
	# weg bovenop de tunnel
	for xx in range(o.x + 1, o.x + 12):
		for zz in [z0 + 10, z0 + 11]:
			G(xx, zz, "weg/rijstrook_onderbroken_kant" if zz == z0 + 10 else "weg/rijstrook_geen_kant", "E" if zz == z0 + 10 else "W")
	# B: verdiepte weg die trapsgewijs dieper gaat (auto + fiets), zonder dak
	x = o.x + 8
	var z := z0
	for d in range(1, 7):
		_sleuf(x, z, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_sleuf(x + 1, z, "tunnel/tunnel_toerit_d%d" % d, d)
		_sleuf(x + 2, z, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
		_sleuf(x, z + 1, "tunnel/tunnelbak_rijstrook_wand_d%d" % d, d)
		_sleuf(x + 1, z + 1, "tunnel/tunnelbak_rijstrook_d%d" % d, d)
		_sleuf(x + 2, z + 1, "tunnel/tunnelbak_fietspad_wand_rechts_d%d" % d, d)
		z += 2
	# C: voetgangers/fietsonderdoorgang met stoep- en fietsbakken op elke diepte
	x = o.x + 14
	for d in range(1, 7):
		var zz: int = z0 + (d - 1) * 2
		_sleuf(x, zz, "tunnel/tunnelbak_stoep_wand_d%d" % d, d)
		_sleuf(x + 1, zz, "tunnel/tunnelbak_stoep_d%d" % d, d)
		_sleuf(x + 2, zz, "tunnel/tunnelbak_fietspad_d%d" % d, d)
		_sleuf(x + 3, zz, "tunnel/tunnelbak_fietspad_wand_d%d" % d, d)
		_sleuf(x + 4, zz, "tunnel/tunnelbak_stoep_wand_rechts_d%d" % d, d)
		_sleuf(x, zz + 1, "tunnel/tunnelbak_rijstrook_wand_d%d" % d, d)
		_sleuf(x + 4, zz + 1, "tunnel/tunnelbak_rijstrook_wand_rechts_d%d" % d, d)
		_sleuf(x + 1, zz + 1, "tunnel/tunnelbak_stoep_d%d" % d, d)
		_sleuf(x + 2, zz + 1, "tunnel/tunnelbak_fietspad_d%d" % d, d)
		_sleuf(x + 3, zz + 1, "tunnel/tunnelbak_stoep_d%d" % d, d)
	# D: fietstunnel met toeritten en portalen
	x = o.x + 21
	for d in range(1, 7):
		_sleuf(x, z0 + d - 1, "tunnel/fietstunnel_toerit_wand_d%d" % d, d)
		_sleuf(x + 1, z0 + d - 1, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
	G(x, z0 + 6, "tunnel/tunnel_fiets_wand_portaal", "N", -6)
	G(x + 1, z0 + 6, "tunnel/tunnel_fiets_wand_rechts_portaal", "N", -6)
	G(x + 2, z0 + 6, "tunnel/tunnel_fietspad", "S", -6)
	for r in range(7, 11):
		G(x, z0 + r, "tunnel/tunnel_fiets_wand", "S", -6)
		G(x + 1, z0 + r, "tunnel/tunnel_fiets_wand_rechts", "S", -6)
	for xx in range(x - 1, x + 3):
		for zz in range(z0 + 7, z0 + 11):
			G(xx, zz, "natuur/gras_kort")


# ------------------------------------------------------------------ kanaal met alle bruggen

func _kanaal_met_bruggen() -> void:
	_wijk_naam = "kanaal"
	var o := _wijk(90, 13)
	var z0 := o.y + 3
	# kanaal z0..z0+4 op laag -2, kades erlangs
	for x in range(o.x + 1, o.x + 89):
		for z in range(z0, z0 + 5):
			_sleuf(x, z, "water/water_gracht", 2)
		for z in [z0 - 1, z0 + 5]:
			G(x, z, "water/kademuur_alg", "S", -2)
			G(x, z, "water/kademuur", "S", -1)
			G(x, z, "stoep/stoep_kade" if x % 4 else "stoep/stoep_kade_klinker", "S" if z == z0 - 1 else "N")
		for z in [z0 - 2, z0 + 6]:
			G(x, z, "weg/weg_vlak", "E")
	var x := o.x + 3
	# brugdekken (1 tile breed, 5 lang)
	for nm in _namen(grond, "brug/brug_dek_"):
		var k: String = nm.split("/")[1]
		var rot := "S"
		for z in range(z0, z0 + 5):
			G(x, z, nm, rot)
		if k.ends_with("_rand") or k.contains("_rand_"):
			for z in range(z0, z0 + 5):
				G(x + 1, z, nm, "N")
			x += 1
		x += 2
	# bakstenen boogbruggen (op waterniveau)
	for i in 3:
		var nm: String = ["brug/brug_boog_gracht_rand", "brug/brug_boog_gracht_midden", "brug/brug_boog_gracht_rand"][i]
		for z in range(z0, z0 + 5):
			G(x + i, z, nm, ["S", "S", "N"][i], -2)
	x += 4
	for z in range(z0, z0 + 5):
		G(x, z, "brug/brug_boog_gracht_beide", "S", -2)
	x += 2
	# ophaalbrug, moderne voetbrug, staalboog, tuibrug
	for i in 5:
		G(x, z0 + i, "brug/ophaalbrug_portaal" if i in [1, 3] else "brug/ophaalbrug_dek", "N" if i == 1 else "S")
	_prop((x + 1) * 4 + 1.0, (z0 - 1) * 4 + 2.0, "water")
	x += 2
	for i in 5:
		G(x, z0 + i, "brug/voetbrug_modern", "S")
	x += 2
	for i in 5:
		G(x, z0 + 4 - i, "brug/staalboog_%d" % (i + 1), "S")
		G(x + 2, z0 + 4 - i, "brug/staalboog_rand_%d" % (i + 1), "S")
		G(x + 3, z0 + i, "brug/staalboog_rand_%d" % (i + 1), "N")
	x += 5
	G(x, z0 + 2, "brug/tuibrug_0", "S")
	for i in range(1, 4):
		G(x, z0 + 2 - i, "brug/tuibrug_%d" % i, "S")
	for i in range(1, 4):
		G(x, z0 + 2 + i, "brug/brug_dek_weg_rand", "S")
	x += 2
	# viaduct op pijlers (laag 3) over het kanaal
	for z in range(z0 - 1, z0 + 6):
		G(x, z, "brug/brug_dek_weg_beide", "S", 3)
	G(x, z0 - 2, "brug/brug_landhoofd", "S", 2)
	for z in [z0 + 1, z0 + 3]:
		G(x, z, "brug/brug_pijler_water", "S", -2)
		G(x, z, "brug/brug_pijler", "S", -1)
		G(x, z, "brug/brug_pijler", "S", 0)
		G(x, z, "brug/brug_pijler", "S", 1)
		G(x, z, "brug/brug_pijler_kop", "S", 2)
	for z in [z0, z0 + 2, z0 + 4]:
		G(x, z, "brug/brug_ligger", "S", 2)
	G(x + 1, z0 - 1, "brug/brug_pijler_stoep", "S")
	G(x + 1, z0 + 5, "brug/brug_pijler_gras", "S")
	x += 3
	# loopbrug over het kanaal met trappen
	for z in range(z0 - 1, z0 + 6):
		G(x, z, "brug/loopbrug_overdekt" if z < z0 + 2 else "brug/loopbrug_open", "S", 3)
	for i in 3:
		G(x + 1, z0 - 1 - i, "brug/loopbrug_trap", "N", 2 - i) if false else null
	G(x, z0 + 2, "brug/loopbrug_pijler", "S", -2)
	for y in range(-1, 3):
		G(x, z0 + 2, "brug/loopbrug_pijler", "S", y)
	x += 2
	# kadetrap en boten
	G(x, z0 + 5, "waterkant/kadetrap", "N", -2)
	for i in range(0, 80, 9):
		_prop((o.x + 4 + i) * 4 + 0.0, (z0 + 2) * 4 + 2.0, "water", -2.0)


# ------------------------------------------------------------------ natuur- en recreatiepark

func _natuurpark() -> void:
	_wijk_naam = "natuurpark"
	var o := _wijk(48, 16)
	vlak(o.x + 1, o.y + 1, o.x + 46, o.y + 14, "natuur/gras")
	# vijver (laag 0) met oevers, strand, beschoeiing, basalt, boulevard, riet en lelies
	var px := o.x + 2
	var pz := o.y + 2
	for x in range(px + 1, px + 7):
		for z in range(pz + 1, pz + 5):
			G(x, z, ["water/water", "water/water_lelies", "water/water_riet", "water/water"][(x + z) % 4])
	for x in range(px + 1, px + 7):
		G(x, pz, ["water/water_oever", "waterkant/strand", "waterkant/beschoeiing", "waterkant/basalt_talud", "waterkant/boulevard", "water/water_oever"][x - px - 1], "S")
		G(x, pz + 5, "water/water_oever", "N")
	for z in range(pz + 1, pz + 5):
		G(px, z, "water/water_oever", "E")
		G(px + 7, z, "water/water_oever", "W")
	G(px, pz, "water/water_oever_hoek_buiten", "SE")
	G(px + 7, pz, "water/water_oever_hoek_buiten", "WS")
	G(px, pz + 5, "waterkant/strand_hoek", "EN")
	G(px + 7, pz + 5, "water/water_oever_hoek_buiten", "NW")
	G(px + 3, pz + 2, "brug/voetbrug_hout_boog", "E")
	G(px + 5, pz + 3, "brug/voetbrug_hout_vlak", "S")
	G(px + 2, pz + 4, "waterkant/aanlegplaats", "N")
	G(px + 6, pz + 1, "water/kademuur_water", "S")
	G(px + 8, pz + 2, "water/water_oever_hoek_binnen", "S")
	for i in 4:
		_prop((px + 2 + i * 1.5) * 4, (pz + 3) * 4 + 2.0, "water", 0.0)
	# sloot met bocht en duiker
	var sx := o.x + 12
	for z in range(o.y + 2, o.y + 8):
		G(sx, z, "water/duiker" if z == o.y + 5 else "water/sloot")
	G(sx, o.y + 8, "water/sloot_bocht", "N")
	for xx in range(sx - 2, sx + 3):
		G(xx, o.y + 5, "weg/berm" if xx != sx else "water/duiker", "N")
	# terrasvormige tuin met grondblokken en trappen
	var tx := o.x + 16
	var tz := o.y + 2
	for x in range(tx, tx + 4):
		G(x, tz, ["terrein/grond_blok", "terrein/grond_blok_beton", "terrein/grond_blok_baksteen", "terrein/grond_blok"][x - tx])
		G(x, tz, "natuur/gras_bloemen", "S", 1)
	G(tx, tz + 1, "terrein/trap_1m", "S")
	G(tx + 1, tz + 1, "terrein/trap_1m_breed", "S")
	G(tx + 2, tz + 1, "terrein/trap_1m_fietsgoot", "S")
	G(tx + 3, tz + 1, "helling/helling_dijk_beton", "S")
	# pleinmozaïek met alle plein- en natuur-tiles
	var tegels := _namen(grond, "plein/") + _namen(grond, "natuur/")
	var mx := o.x + 22
	var mz := o.y + 2
	for i in tegels.size():
		G(mx + (i % 12), mz + int(i / 12), tegels[i])
	for i in 6:
		_prop((mx + i * 2) * 4 + 2.0, (mz + 3) * 4 + 2.0, "groen")
	# buitenzwembad met alle zwembad-tiles
	var zx := o.x + 22
	var zz := o.y + 8
	vlak(zx, zz, zx + 7, zz + 5, "zwembad/zwembad_kant_tegels")
	for x in range(zx + 1, zx + 6):
		for z in range(zz + 1, zz + 4):
			var es: Array = _zijden(x, z, zx + 1, zz + 1, 5, 3)
			var nm: String = "zwembad/zwembad_midden"
			var rot = "S"
			if es.size() == 1:
				nm = "zwembad/zwembad_rand_trap" if (x == zx + 3 and es[0] == "N") else "zwembad/zwembad_rand"
				rot = es[0]
			elif es.size() >= 2:
				nm = "zwembad/zwembad_hoek"
				rot = HOEK[_hoekpaar(es, "")]
			_sleuf(x, z, nm, 1, rot)
	_sleuf(zx + 6, zz + 2, "zwembad/zwembad_eind", 1, "E")
	G(zx + 7, zz + 4, "zwembad/kinderbad")
	for i in 4:
		_prop((zx + 1 + i * 1.5) * 4, (zz + 5) * 4 + 1.0, "water", 0.0)


# ------------------------------------------------------------------ vangnet: wat nog nergens staat, in een kleine situatie

func _rest_in_context() -> void:
	_wijk_naam = "rest"
	var rest_g := _ongebruikt_lijst(grond)
	var rest_b := _ongebruikt_lijst(gebouwen)
	var rest_d := _ongebruikt_lijst(details)
	var rest_p := _ongebruikt_lijst(props)
	var n := rest_g.size() + rest_b.size() + rest_d.size() + rest_p.size()
	print("nog niet in een buurt: grond %d, gebouwen %d, details %d, props %d" % [rest_g.size(), rest_b.size(), rest_d.size(), rest_p.size()])
	print("  ", rest_g, rest_b, rest_d)
	if n == 0:
		return
	var o := _wijk(60, 4 + ceili(n / 14.0) * 4)
	var x := o.x + 2
	var z := o.y + 2
	for nm in rest_g:
		var k: String = nm.split("/")[0]
		if k == "stoep":
			for c in [[x - 1, z], [x + 1, z], [x, z - 1], [x, z + 1]]:
				G(c[0], c[1], "weg/weg_vlak")
			G(x, z, nm)
		elif k == "tunnel":
			var dd := 6
			var i: int = nm.find("_d")
			if i >= 0 and nm.substr(i + 2).is_valid_int():
				dd = int(nm.substr(i + 2))
			_sleuf(x, z, nm, dd)
		else:
			G(x, z, nm)
		x += 4
		if x > o.x + 56:
			x = o.x + 2
			z += 4
	for nm in rest_b:
		var st: String = nm.split("/")[0]
		var basis: String = st + "/" + st + "_blok_dicht"
		if not _heeft(basis):
			basis = "klassiek_rood/klassiek_rood_blok_dicht"
		var k: String = _kort(st, nm)
		if k.begins_with("bg_"):
			B(x, 0, z, nm, "S")
		elif k.begins_with("verd_") or k.begins_with("toren_"):
			B(x, 0, z, basis, "S")
			B(x, 1, z, nm, "S")
		else:
			B(x, 0, z, basis, "S")
			B(x, 1, z, nm, "S")
		x += 4
		if x > o.x + 56:
			x = o.x + 2
			z += 4
	for nm in rest_d:
		B(x, 0, z, "klassiek_rood/klassiek_rood_blok_dicht", "S")
		B(x, 1, z, "klassiek_rood/klassiek_rood_blok_dicht", "S")
		D(x * 4 + 2.0, (z + 1) * 4.0, 3.0, nm, "S")
		x += 4
		if x > o.x + 56:
			x = o.x + 2
			z += 4
	for nm in rest_p:
		Pr(x * 4 + 2.0, z * 4 + 2.0, nm, "S")
		x += 4
		if x > o.x + 56:
			x = o.x + 2
			z += 4


func _ongebruikt_lijst(gm: GridMap) -> Array:
	var aanwezig := {}
	for c in gm.get_used_cells():
		aanwezig[gm.get_cell_item(c)] = true
	var uit := []
	for id in gm.mesh_library.get_item_list():
		if not aanwezig.has(id):
			uit.append(gm.mesh_library.get_item_name(id))
	uit.sort()
	return uit


func _zoek_grond(eind: String) -> String:
	for id in grond.mesh_library.get_item_list():
		var nm := grond.mesh_library.get_item_name(id)
		if nm.ends_with("/" + eind):
			return nm
	return ""


# ------------------------------------------------------------------ kruispunten: verkeerseilanden, rotonde en stoephoeken

func _kruispunten() -> void:
	_wijk_naam = "kruispunten"
	var o := _wijk(44, 14)
	vlak(o.x + 1, o.y + 1, o.x + 42, o.y + 12, "weg/weg_vlak")
	# brede weg met middeneilanden (gewoon, met goot, klinker) en eindkoppen
	var z := o.y + 3
	var x := o.x + 2
	for variant in ["", "goot_"]:
		G(x, z, "stoep/stoep_" + variant + "eiland_eind", "W")
		G(x + 1, z, "stoep/stoep_" + variant + "eiland", "E")
		G(x + 2, z, "stoep/stoep_" + variant + "eiland", "E")
		G(x + 3, z, "stoep/stoep_" + variant + "eiland_eind", "E")
		_prop((x + 1) * 4 + 2.0, z * 4 + 2.0, "straat")
		x += 5
	G(x, z, "weg/middengeleider_kop", "S")
	G(x, z + 1, "weg/middengeleider", "S")
	G(x, z + 2, "weg/middengeleider", "S")
	x += 2
	# rotonde met rond middeneiland
	G(x + 1, z + 1, "stoep/stoep_eiland_rond")
	G(x + 4, z + 1, "stoep/stoep_goot_eiland_rond")
	_prop((x + 1) * 4 + 2.0, (z + 1) * 4 + 2.0, "groen")
	x += 7
	# smalle uitstekende stoepen (eind van een stoepstrook)
	G(x, z, "stoep/stoep_smal_eind", "N")
	G(x, z + 1, "stoep/stoep_eiland", "E")
	G(x + 2, z, "stoep/stoep_goot_smal_eind", "N")
	G(x + 2, z + 1, "stoep/stoep_goot_eiland", "E")
	# straathoeken: buitenhoeken, binnenhoeken en de varianten met goot/klinker/kade
	var hz := o.y + 8
	var hx := o.x + 2
	for variant in ["", "goot_", "klinker_", "kade_"]:
		var pre: String = "stoep/stoep_" + variant
		# een L-vormige stoep langs een bocht in de weg: buitenhoek, randen en binnenhoek
		G(hx, hz, pre + "hoek_buiten" if _heeft(pre + "hoek_buiten", grond) else "stoep/stoep_hoek_buiten", "SE")
		G(hx + 1, hz, pre + "rand" if _heeft(pre + "rand", grond) else "stoep/stoep_rand", "S")
		G(hx, hz + 1, pre + "rand" if _heeft(pre + "rand", grond) else "stoep/stoep_rand", "E")
		G(hx + 1, hz + 1, pre + "hoek_binnen" if _heeft(pre + "hoek_binnen", grond) else "stoep/stoep_hoek_binnen", "NW")
		G(hx + 1, hz + 2, "stoep/stoep_vol")
		G(hx + 2, hz + 1, "stoep/stoep_vol")
		G(hx + 2, hz + 2, "stoep/stoep_vol")
		hx += 5
	G(hx, hz, "stoep/stoep_rand_hoek_binnen", "S")
	G(hx + 1, hz, "stoep/stoep_rand", "S")
	G(hx - 1, hz, "stoep/stoep_rand", "S")
	G(hx, hz + 1, "stoep/stoep_vol")
	G(hx + 1, hz + 1, "stoep/stoep_vol")
	hx += 4
	G(hx, hz, "stoep/stoep_goot_rand_hoek_binnen", "S")
	G(hx + 1, hz, "stoep/stoep_goot_rand", "S")
	G(hx, hz + 1, "stoep/stoep_vol")
	hx += 4
	G(hx, hz + 1, "stoep/stoep_dubbel_hoek_binnen", "S")
	G(hx, hz + 2, "stoep/stoep_vol")
	G(hx + 2, hz + 1, "stoep/stoep_goot_dubbel_hoek_binnen", "S")
	G(hx + 2, hz + 2, "stoep/stoep_vol")


# ------------------------------------------------------------------ winkelstraat (wandelgebied) bij de campus

func _winkelstraat() -> void:
	var x0 := 62
	var x1 := 95
	# wandelstraat z 90..92 met een middenstrook van natuursteen
	vlak(x0, 86, x1, 97, "natuur/gras")
	for x in range(x0, x1 + 1):
		G(x, 90, "plein/plein_klinkers")
		G(x, 91, "plein/plein_natuursteen" if x % 6 else "plein/plein_patroon")
		G(x, 92, "plein/plein_klinkers")
	# ingangen met paaltjes en borden
	for z in [90, 91, 92]:
		Pr(x0 * 4 + 0.5, z * 4 + 2.0, "paaltjes/paal_afzet")
		Pr((x1 + 1) * 4 - 0.5, z * 4 + 2.0, "paaltjes/paal_afzet")
	Pr(x0 * 4 + 1.0, 90 * 4 + 0.5, "borden/bord_voetpad", "W")
	Pr((x1 + 1) * 4 - 1.0, 92 * 4 + 3.5, "borden/bord_voetpad", "E")
	# winkelpanden aan beide kanten: wisselende stijlen per vier panden
	var stijlen := ["klassiek_rood", "jaren30", "klassiek_geel", "herenhuis_1900", "modern_wit", "klassiek_donker", "modern_donker", "jaren30"]
	var winkels := ["bg_bakker", "bg_cafe", "bg_kleding", "bg_boekhandel", "bg_restaurant", "bg_bloemist", "bg_juwelier", "bg_telefoon",
		"bg_ijssalon", "bg_slager", "bg_fietsenwinkel", "bg_bar", "bg_drogist", "bg_kapper", "bg_snackbar", "bg_supermarkt", "bg_dierenwinkel",
		"bg_winkel_luifel", "bg_kleding", "bg_cafe"]
	var wi := 0
	for kant in [["N", 88], ["S", 93]]:
		var voor: String = kant[0]
		var zv: int = kant[1]
		var za: int = zv + (-1 if voor == "S" else 1) * -1
		var zfront := zv + (1 if voor == "S" else 0)
		var zback := zv + (0 if voor == "S" else 1)
		for x in range(x0, x1 + 1):
			var stijl: String = stijlen[((x - x0) / 4) % stijlen.size()]
			var p := stijl + "/" + stijl + "_"
			var rand_x := x == x0 or x == x1
			var gevel := "S" if voor == "S" else "N"
			# voorste rij: winkel op de begane grond, woningen erboven
			var winkel: String = winkels[wi % winkels.size()]
			wi += 1
			if not _heeft(p + winkel):
				winkel = _eerste(p, ["bg_winkel_luifel", "bg_winkel", "bg_raam_boog", "bg_raam"])
			var fz := 89 if voor == "S" else 93
			var bz := 88 if voor == "S" else 94
			if rand_x:
				var hk := ("WS" if x == x0 else "SE") if voor == "S" else ("NW" if x == x0 else "EN")
				B(x, 0, fz, p + ("bg_raam_hoek" if _heeft(p + "bg_raam_hoek") else "blok_dicht"), hk)
				for v in range(1, 3):
					B(x, v, fz, p + ("verd_raam_hoek" if _heeft(p + "verd_raam_hoek") else "blok_dicht"), hk)
			else:
				B(x, 0, fz, p + winkel, gevel)
				for v in range(1, 3):
					var vd := ["verd_raam", "verd_balkon", "verd_raam", "verd_luiken", "verd_erker", "verd_raam_breed"]
					var nm: String = vd[(x + v) % vd.size()]
					B(x, v, fz, p + (nm if _heeft(p + nm) else _eerste(p, ["verd_raam", "verd_raam_boog", "verd_glas"])), gevel)
			# achterste rij: achtergevels met ramen en deuren
			var achter := "N" if voor == "S" else "S"
			if rand_x:
				var hk4 := ("NW" if x == x0 else "EN") if voor == "S" else ("WS" if x == x0 else "SE")
				B(x, 0, bz, p + _eerste(p, ["bg_raam_hoek", "bg_raam_boog_hoek"]), hk4)
				for v in range(1, 3):
					B(x, v, bz, p + _eerste(p, ["verd_raam_hoek", "verd_raam_boog_hoek"]), hk4)
			else:
				B(x, 0, bz, p + _eerste(p, ["bg_deur", "bg_raam"] if x % 2 else ["bg_raam", "bg_raam_boog"]), achter)
				for v in range(1, 3):
					B(x, v, bz, p + _eerste(p, ["verd_raam", "verd_raam_boog", "verd_glas"]), achter)
			# daken: plat met rand aan de straatkant, of schuine kap
			var schuin := _heeft(p + "dak_schuin")
			if schuin:
				if rand_x:
					var hk2 := ("WS" if x == x0 else "SE") if voor == "S" else ("NW" if x == x0 else "EN")
					B(x, 3, fz, p + "dak_schuin_hoek_buiten", hk2)
					var hk3 := ("NW" if x == x0 else "EN") if voor == "S" else ("WS" if x == x0 else "SE")
					B(x, 3, bz, p + "dak_schuin_hoek_buiten", hk3)
				else:
					var dv := ["dak_schuin", "dak_schuin_dakkapel", "dak_schuin", "dak_schuin_schoorsteen"]
					var dn: String = dv[x % dv.size()]
					B(x, 3, fz, p + (dn if _heeft(p + dn) else "dak_schuin"), gevel)
					B(x, 3, bz, p + "dak_schuin", "N" if voor == "S" else "S")
			else:
				B(x, 3, fz, p + "dak_plat_rand", gevel)
				B(x, 3, bz, p + "dak_plat_rand", "N" if voor == "S" else "S")
			# gevel-details boven de winkels
			var gevel_z := (fz + 1) * 4.0 if voor == "S" else fz * 4.0
			if not rand_x and x % 3 == 0:
				D(x * 4 + 2.0, gevel_z, 3.2, "ramen/bloembak", gevel)
			if not rand_x and x % 5 == 2:
				D(x * 4 + 0.5, gevel_z, 2.6, "gevel/uithangbord", gevel)
			if not rand_x and x % 7 == 4:
				D(x * 4 + 2.0, gevel_z, 6.0, "gevel/vlag_regenboog" if x % 2 else "gevel/vlag_nl", gevel)
	# straatmeubilair en terrassen in de wandelstraat
	for x in range(x0 + 1, x1, 2):
		var wx := x * 4 + 2.0
		match x % 8:
			1:
				Pr(wx, 90 * 4 + 1.5, "terras/tafel_rond_stoelen")
				Pr(wx, 90 * 4 + 1.5, "terras/parasol_rood")
			3:
				Pr(wx, 91 * 4 + 2.0, "bomen/linde")
				Pr(wx + 2.0, 91 * 4 + 2.0, "straat/bank_hout", "N")
			5:
				Pr(wx, 92 * 4 + 2.5, "terras/tafel_vierkant_stoelen")
				Pr(wx, 92 * 4 + 2.5, "terras/parasol_groen")
			7:
				Pr(wx, 91 * 4 + 2.0, "planten/plantenbak_beton")
				Pr(wx + 2.0, 91 * 4 + 1.0, "verlichting/lantaarn_klassiek")
	for x in range(x0 + 2, x1, 6):
		Pr(x * 4 + 2.0, 91 * 4 + 3.0, "straat/prullenbak_paal")
		Pr(x * 4 + 3.5, 92 * 4 + 3.0, "fietsen/fietsenrek", "E") if x % 12 == 2 else null
	Pr(78 * 4 + 2.0, 91 * 4 + 2.0, "straat/fontein")
	Pr(70 * 4 + 2.0, 90 * 4 + 1.0, "terras/stoepbord", "S")
	Pr(86 * 4 + 2.0, 92 * 4 + 3.0, "ov/reclamezuil")
	Pr(90 * 4 + 2.0, 91 * 4 + 2.0, "standbeelden/standbeeld_persoon", "S")


func _eerste(p: String, opties: Array) -> String:
	for o in opties:
		if _heeft(p + o):
			return o
	return "blok_dicht"


# ------------------------------------------------------------------ verkeerslichten: alle types in alle standen

func _kruising_met_lichten(cx: int, cz: int, ns: String, ew: String, ov_ns: String, ov_ew: String, mast_ns: String, mast_ew: String) -> void:
	# wegen: N-Z op x = cx, cx+1; O-W op z = cz, cz+1; 4 tiles lang per arm
	for i in range(-4, 6):
		if i == 0 or i == 1:
			continue
		G(cx, cz + i, "weg/rijstrook_streep_kant" if abs(i) < 3 or i == 2 else "weg/rijstrook_geen_kant", "N")
		G(cx + 1, cz + i, "weg/rijstrook_streep_kant" if abs(i) < 3 or i == 2 else "weg/rijstrook_onderbroken_kant", "S")
		G(cx + i, cz, "weg/rijstrook_streep_kant" if abs(i) < 3 or i == 2 else "weg/rijstrook_onderbroken_kant", "E")
		G(cx + i, cz + 1, "weg/rijstrook_streep_kant" if abs(i) < 3 or i == 2 else "weg/rijstrook_geen_kant", "W")
		G(cx - 1, cz + i, "stoep/stoep_rand", "E")
		G(cx + 2, cz + i, "stoep/stoep_rand", "W")
		G(cx + i, cz - 1, "stoep/stoep_rand", "S")
		G(cx + i, cz + 2, "stoep/stoep_rand", "N")
	G(cx + 1, cz + 2, "weg/rijstrook_stopstreep", "S")
	G(cx, cz - 1, "weg/rijstrook_stopstreep", "N")
	G(cx - 1, cz, "weg/rijstrook_stopstreep", "E")
	G(cx + 2, cz + 1, "weg/rijstrook_stopstreep", "W")
	for x in [cx, cx + 1]:
		for z in [cz, cz + 1]:
			G(x, z, "weg/weg_vlak")
	G(cx - 1, cz - 1, "stoep/stoep_hoek_buiten", "SE")
	G(cx + 2, cz - 1, "stoep/stoep_hoek_buiten", "WS")
	G(cx - 1, cz + 2, "stoep/stoep_hoek_buiten", "EN")
	G(cx + 2, cz + 2, "stoep/stoep_hoek_buiten", "NW")
	var vg_ns := "groen" if ns == "groen" else "rood"
	var vg_ew := "groen" if ew == "groen" else "rood"
	var L := "verkeerslichten/"
	# noordwaarts verkeer (komt van het zuiden): lichten op de zuidoosthoek, kijkend naar het zuiden
	var se := Vector2((cx + 2) * 4 + 1.0, (cz + 2) * 4 + 1.0)
	Pr(se.x, se.y, L + "auto_" + ns, "S")
	Pr(se.x + 1.5, se.y, L + "fiets_" + ns, "S")
	Pr(se.x, se.y + 1.5, L + "ov_" + ov_ns, "S")
	Pr(se.x + 1.5, se.y + 1.5, L + "voetganger_" + vg_ew, "W")
	Pr((cx + 1) * 4 + 2.0, (cz + 4) * 4 + 2.0, L + "mast_" + mast_ns, "S") if mast_ns != "" else null
	# zuidwaarts verkeer: noordwesthoek
	var nw := Vector2((cx - 1) * 4 + 3.0, (cz - 1) * 4 + 3.0)
	Pr(nw.x, nw.y, L + "auto_" + ns, "N")
	Pr(nw.x - 1.5, nw.y, L + "fiets_" + ns, "N")
	Pr(nw.x, nw.y - 1.5, L + "ov_" + ov_ns, "N")
	Pr(nw.x - 1.5, nw.y - 1.5, L + "voetganger_" + vg_ew, "E")
	# westwaarts verkeer (komt van het oosten): noordoosthoek
	var ne := Vector2((cx + 2) * 4 + 1.0, (cz - 1) * 4 + 3.0)
	Pr(ne.x, ne.y, L + "auto_" + ew, "E")
	Pr(ne.x, ne.y - 1.5, L + "fiets_" + ew, "E")
	Pr(ne.x + 1.5, ne.y, L + "ov_" + ov_ew, "E")
	Pr(ne.x + 1.5, ne.y - 1.5, L + "voetganger_" + vg_ns, "S")
	Pr((cx + 4) * 4 + 2.0, cz * 4 + 2.0, L + "mast_" + mast_ew, "E") if mast_ew != "" else null
	# oostwaarts verkeer: zuidwesthoek
	var sw := Vector2((cx - 1) * 4 + 3.0, (cz + 2) * 4 + 1.0)
	Pr(sw.x, sw.y, L + "auto_" + ew, "W")
	Pr(sw.x, sw.y + 1.5, L + "fiets_" + ew, "W")
	Pr(sw.x - 1.5, sw.y, L + "ov_" + ov_ew, "W")
	Pr(sw.x - 1.5, sw.y + 1.5, L + "voetganger_" + vg_ns, "N")
	for c in [[cx, cz - 2], [cx + 1, cz + 3], [cx - 2, cz + 1], [cx + 3, cz]]:
		G(c[0], c[1], "weg/zebrapad", "S" if c[0] <= cx + 1 and c[0] >= cx else "E")


func _verkeerslichten() -> void:
	_wijk_naam = "verkeerslichten"
	var o := _wijk(36, 14)
	vlak(o.x + 1, o.y + 1, o.x + 34, o.y + 12, "natuur/gras_kort")
	# kruising 1: noord-zuid groen, oost-west rood
	_kruising_met_lichten(o.x + 7, o.y + 6, "groen", "rood", "rijden", "stop", "groen", "rood")
	# kruising 2: noord-zuid oranje, oost-west rood
	_kruising_met_lichten(o.x + 25, o.y + 6, "oranje", "rood", "attentie", "stop", "oranje", "rood")


# ------------------------------------------------------------------ bedrijventerrein: loodsen, magazijn, fabriek

func _ind_blok(x0: int, z0: int, w: int, d: int, stijl: String, lagen: int, bg: Array, dak: String) -> void:
	var cellen := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			cellen.append(Vector2i(x, z))
	var verd := ["verd_wand", "verd_lichtstraat", "verd_wand", "verd_logo"]
	if stijl == "fabriek":
		verd = ["verd_raam_hoog"]
	_gevels(cellen, stijl, lagen, bg, verd, ["bg_dicht_hoek", "bg_roldeur_hoek", "bg_kantoor_hoek"],
		["verd_lichtstraat_hoek"] if stijl != "fabriek" else ["verd_raam_hoog_hoek"], {})
	var p := stijl + "/" + stijl + "_"
	match dak:
		"ton":
			for c in cellen:
				B(c.x, lagen, c.y, p + "dak_ton", "S")
		"shed":
			for c in cellen:
				B(c.x, lagen, c.y, p + ("dak_shed_rand" if c.y == z0 else "dak_shed"), "N" if c.y == z0 else "N")
		_:
			var soorten := {"midden": ["dak_lichtstraten", "dak_plat_midden", "dak_lichtstraten"], "rand": ["dak_plat_rand"],
				"hoek": ["dak_plat_hoek"], "tegenover": ["dak_plat_tegenover"], "eind": ["dak_plat_eind"]}
			_platte_daken(cellen, stijl, lagen, soorten, {})


func _bedrijventerrein() -> void:
	_wijk_naam = "bedrijventerrein"
	var o := _wijk(62, 26)
	vlak(o.x + 1, o.y + 1, o.x + 60, o.y + 24, "plein/plein_tegels")
	var x0 := o.x + 2
	var z0 := o.y + 2
	# grote stalen loods (10x6, 9 m hoog) met laaddocks en roldeuren
	_ind_blok(x0, z0, 10, 6, "loods_staal", 3, ["bg_dock", "bg_dock", "bg_roldeur", "bg_dock", "bg_loopdeur"], "plat")
	# loods met stenen plint en tondak
	_ind_blok(x0 + 12, z0, 6, 4, "loods_steen", 2, ["bg_roldeur", "bg_loopdeur", "bg_kantoor"], "ton")
	# magazijn met een rij laaddocks
	_ind_blok(x0 + 20, z0, 8, 6, "magazijn", 3, ["bg_dock"], "plat")
	# fabriek met sheddak en fabrieksschoorsteen
	_ind_blok(x0 + 30, z0, 8, 4, "fabriek", 2, ["bg_poort", "bg_dicht", "bg_loopdeur"], "shed")
	B(x0 + 39, 0, z0 + 1, "overig/fabrieksschoorsteen_voet", "S")
	for v in range(1, 9):
		B(x0 + 39, v, z0 + 1, "overig/fabrieksschoorsteen_segment", "S")
	B(x0 + 39, 9, z0 + 1, "overig/fabrieksschoorsteen_top", "S")
	# kleine bedrijfsunits (verschillende groottes en materialen)
	_ind_blok(x0 + 42, z0, 3, 2, "loods_staal", 1, ["bg_roldeur", "bg_loopdeur"], "plat")
	_ind_blok(x0 + 46, z0, 4, 2, "loods_steen", 2, ["bg_roldeur", "bg_kantoor"], "plat")
	_ind_blok(x0 + 51, z0, 5, 3, "magazijn", 2, ["bg_dock", "bg_kantoor", "bg_roldeur"], "plat")
	_ind_blok(x0 + 42, z0 + 4, 6, 3, "fabriek", 2, ["bg_poort", "bg_loopdeur"], "plat")
	_ind_blok(x0 + 50, z0 + 5, 6, 2, "loods_staal", 2, ["bg_kantoor", "bg_roldeur", "bg_dock"], "ton")
	# erf: containers, pallets, heftruck, silo's, tank, kabelhaspels, laadperron, hekwerk en poort
	var yz := (z0 + 8) * 4.0
	Pr((x0 + 2) * 4.0, yz + 6.0, "industrie/zeecontainer_stapel", "S")
	Pr((x0 + 8) * 4.0, yz + 4.0, "industrie/zeecontainer", "S")
	Pr((x0 + 8) * 4.0, yz + 8.0, "industrie/zeecontainer", "S")
	for i in 5:
		Pr((x0 + 12 + i) * 4.0, yz + 3.0, "industrie/pallet_stapel")
	Pr((x0 + 14) * 4.0, yz + 9.0, "industrie/heftruck", "W")
	Pr((x0 + 22) * 4.0, yz + 8.0, "industrie/silo")
	Pr((x0 + 26) * 4.0, yz + 8.0, "industrie/silo")
	Pr((x0 + 33) * 4.0, yz + 9.0, "industrie/opslagtank")
	Pr((x0 + 38) * 4.0, yz + 4.0, "industrie/kabelhaspel")
	Pr((x0 + 39) * 4.0, yz + 4.0, "industrie/kabelhaspel")
	Pr((x0 + 24) * 4.0, (z0 + 6) * 4.0 + 2.0, "industrie/laadperron", "S")
	# tweede rij: distributiecentrum (12x8) en een stenen loods, met laaddocks naar het erf
	_ind_blok(x0 + 22, z0 + 14, 14, 8, "magazijn", 4, ["bg_dock"], "plat")
	_ind_blok(x0 + 38, z0 + 15, 8, 5, "loods_steen", 3, ["bg_roldeur", "bg_dock", "bg_loopdeur"], "ton")
	_ind_blok(x0 + 48, z0 + 15, 8, 6, "loods_staal", 3, ["bg_dock", "bg_roldeur", "bg_kantoor"], "plat")
	# parkeerplaats voor personeel en een groenstrook met bomen
	for x in range(x0, x0 + 18):
		G(x, z0 + 15, "parkeren/parkeervak_haaks", "N")
		G(x, z0 + 16, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, z0 + 17, "parkeren/parkeervak_haaks", "S")
	for x in range(x0, x0 + 18):
		G(x, z0 + 19, "natuur/gras")
		G(x, z0 + 20, "natuur/gras")
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (z0 + 19) * 4 + 4.0, "bomen/populier" if x % 2 else "bomen/linde")
	for x in [x0 + 4, x0 + 9, x0 + 14]:
		Pr(x * 4.0, (z0 + 15) * 4 + 1.0, "paaltjes/laadpaal", "N")
	# meer erfinrichting: containerrijen, pallets en kabelhaspels bij de docks
	for i in 3:
		Pr((x0 + 2 + i * 6) * 4.0, (z0 + 11) * 4.0, "industrie/zeecontainer_stapel", "S")
	for i in 8:
		Pr((x0 + 22 + i * 1.5) * 4.0, (z0 + 12) * 4.0, "industrie/pallet_stapel")
	Pr((x0 + 30) * 4.0, (z0 + 12) * 4.0, "industrie/heftruck", "E")
	Pr((x0 + 44) * 4.0, (z0 + 12) * 4.0, "industrie/zeecontainer", "E")
	Pr((x0 + 50) * 4.0, (z0 + 12) * 4.0, "industrie/opslagtank")
	for x in range(o.x + 1, o.x + 60, 6):
		Pr(x * 4 + 3.0, (o.y + 25) * 4 - 0.5, "hekken/hek_industrie", "S")
	Pr((o.x + 30) * 4.0, (o.y + 25) * 4 - 1.0, "hekken/schuifpoort_industrie", "S")
	Pr((o.x + 44) * 4.0, (o.y + 25) * 4 - 1.5, "hekken/slagboom", "S")


# ------------------------------------------------------------------ tint-demo: dezelfde panden met verschillende tinten

func _tint_vlak(pos: Vector3, kleur: Color, grootte: Vector2i, helderheid := 1.0, naam := "TintVlak") -> void:
	var tv := Node3D.new()
	tv.name = naam
	tv.set_script(load("res://scripts/tint_vlak.gd"))
	tv.position = pos
	tv.set("kleur", kleur)
	tv.set("grootte", grootte)
	tv.set("helderheid", helderheid)
	tint_kaart.add_child(tv, true)


func _tint_demo() -> void:
	_wijk_naam = "tint"
	var o := _wijk(30, 18)
	vlak(o.x + 1, o.y + 1, o.x + 28, o.y + 16, "plein/plein_tegels")
	var tinten := [
		["origineel", Color(1, 1, 1), 1.0], ["warm", Color(1.0, 0.8, 0.62), 1.0], ["koel", Color(0.75, 0.86, 1.1), 1.0],
		["groenig", Color(0.82, 1.0, 0.78), 1.0], ["lichter", Color(1, 1, 1), 1.35], ["donkerder", Color(1, 1, 1), 0.65],
		["oker", Color(1.1, 0.95, 0.6), 1.0], ["rozig", Color(1.1, 0.82, 0.86), 1.0],
	]
	# rij 1: identieke klassieke panden, elk met een andere tint
	var rij := [["klassiek_rood", o.y + 2], ["modern_wit", o.y + 7], ["jaren30", o.y + 12]]
	for r in rij:
		var stijl: String = r[0]
		var z: int = r[1]
		var p := stijl + "/" + stijl + "_"
		for i in tinten.size():
			var x := o.x + 2 + i * 3
			for zz in [z, z + 1]:
				B(x, 0, zz, p + ("bg_deur" if zz == z else "bg_raam") if _heeft(p + "bg_deur") else p + _eerste(p, ["bg_raam", "bg_portiek"]), "N" if zz == z else "S")
				B(x, 1, zz, p + _eerste(p, ["verd_raam", "verd_balkon"]), "N" if zz == z else "S")
			if _heeft(p + "dak_schuin"):
				B(x, 2, z, p + "dak_schuin", "N")
				B(x, 2, z + 1, p + "dak_schuin", "S")
			else:
				B(x, 2, z, p + "dak_plat_tegenover" if _heeft(p + "dak_plat_tegenover") else p + "dak_plat_rand", "E")
				B(x, 2, z + 1, p + "dak_plat_tegenover" if _heeft(p + "dak_plat_tegenover") else p + "dak_plat_rand", "E")
			var t: Array = tinten[i]
			if t[0] != "origineel":
				_tint_vlak(Vector3(x * 4 + 2.0, 0, (z + 1) * 4.0), t[1], Vector2i(1, 2), t[2], "Tint_" + stijl + "_" + t[0])
			Pr(x * 4 + 2.0, (z + 2) * 4 + 1.0, "bomen/linde" if i % 2 else "planten/plantenbak_beton")
	# één groot tintvlak over een heel blok, inclusief de grond eronder
	var bx := o.x + 26
	for x in range(bx, bx + 2):
		for z in range(o.y + 2, o.y + 6):
			var sides := _zijden(x, z, bx, o.y + 2, 2, 4)
			for v in range(3):
				var key := _hoekpaar(sides, "W")
				if key != "" and sides.size() >= 2:
					B(x, v, z, "klassiek_geel/klassiek_geel_" + ("bg_raam_hoek" if v == 0 else "verd_raam_hoek"), HOEK[key])
				else:
					B(x, v, z, "klassiek_geel/klassiek_geel_" + ("bg_raam" if v == 0 else "verd_raam"), sides[0] if sides.size() > 0 else "S")
			B(x, 3, z, "klassiek_geel/klassiek_geel_dak_plat_midden", "S")
	_tint_vlak(Vector3(bx * 4 + 4.0, 0, (o.y + 4) * 4.0), Color(0.7, 0.85, 1.15), Vector2i(2, 4), 1.0, "Tint_blok_inclusief_grond")


# ------------------------------------------------------------------ afgeronde bochten: straten die de hoek om gaan

## Straatprofielen: delen van binnenbocht naar buitenbocht, als [tile, draaiing] voor een
## rechte weg die van zuid naar noord loopt.
const PROFIELEN := {
	"straat": [["stoep/stoep_rand", 1], ["weg/weg_vlak", 0], ["stoep/stoep_rand", 3]],
	"klinkerstraat": [["stoep/stoep_klinker_rand", 1], ["weg/straat_klinkers", 0], ["stoep/stoep_klinker_rand", 3]],
	"weg": [["stoep/stoep_goot_rand", 1], ["weg/rijstrook_geen_kant", 2], ["weg/rijstrook_onderbroken_kant", 0], ["stoep/stoep_goot_rand", 3]],
	"hoofdweg": [["stoep/stoep_goot_rand", 1], ["fietspad/fietspad_recht", 0], ["weg/rijstrook_geen_kant", 2],
		["weg/rijstrook_onderbroken_kant", 0], ["fietspad/fietspad_recht", 0], ["stoep/stoep_goot_rand", 3]],
	"tramweg": [["stoep/stoep_rand", 1], ["tram/tram_rijstrook_geen_kant", 2], ["tram/tram_rijstrook_onderbroken_kant", 0], ["stoep/stoep_rand", 3]],
	"laan": [["stoep/stoep_rand", 1], ["weg/rijstrook_onderbroken_kant", 2], ["weg/rijstrook_geen_geen", 2], ["weg/middenberm_gras", 1],
		["weg/rijstrook_geen_geen", 0], ["weg/rijstrook_onderbroken_kant", 0], ["stoep/stoep_rand", 3]],
	"fietspad": [["natuur/gras", 0], ["fietspad/fietspad_recht", 0], ["natuur/gras", 0]],
}


func _draai_offset(o: Vector2i, k: int) -> Vector2i:
	var v := o
	for i in (k % 4 + 4) % 4:
		v = Vector2i(v.y, -v.x)
	return v


## Legt een afgeronde bocht van een straatprofiel. (hx, hz) = de cel waarvan de
## noord-west hoek het middelpunt van de bocht is; k = draaiing in kwartslagen.
## De weg komt van het zuiden en buigt af naar het westen (k=0).
func bocht(hx: int, hz: int, profiel: String, k := 0, recht := 3) -> void:
	var delen: Array = PROFIELEN[profiel]
	var n: int = 1 + delen.size()
	for i in n:
		for j in n:
			var o := _draai_offset(Vector2i(i, -j), k)
			G(hx + o.x, hz + o.y, "bocht/%s_%d_%d" % [profiel, i, j], k)
	# rechte stukken: naar het zuiden (onder de bocht) en naar het westen (links)
	for d in delen.size():
		var deel: Array = delen[d]
		for r in range(1, recht + 1):
			var o1 := _draai_offset(Vector2i(1 + d, r), k)
			G(hx + o1.x, hz + o1.y, deel[0], (int(deel[1]) + k) % 4)
			var o2 := _draai_offset(Vector2i(-r, -(1 + d)), k)
			G(hx + o2.x, hz + o2.y, deel[0], (int(deel[1]) + 3 + k) % 4)


func _bochten() -> void:
	_wijk_naam = "bochten"
	var o := _wijk(92, 34)
	vlak(o.x + 1, o.y + 1, o.x + 90, o.y + 32, "natuur/gras")
	var x := o.x + 5
	var z := o.y + 12
	for profiel in ["straat", "klinkerstraat", "weg", "tramweg", "fietspad"]:
		var n: int = 1 + PROFIELEN[profiel].size()
		bocht(x, z, profiel, 0)
		x += n + 7
	# brede profielen op een tweede rij, ook een keer andersom gedraaid
	x = o.x + 6
	z = o.y + 26
	for profiel in ["hoofdweg", "laan"]:
		var n: int = 1 + PROFIELEN[profiel].size()
		bocht(x + 3, z, profiel, 0)
		x += n + 8
	bocht(x + 16, o.y + 18, "weg", 2)
	for i in 30:
		Pr((o.x + 2 + i * 3) * 4.0, (o.y + 1) * 4.0 + 1.0, ["bomen/linde", "verlichting/lantaarn_modern", "planten/struik"][i % 3])


# ------------------------------------------------------------------ dorpskern met kinderkopjes

func _dorpskern() -> void:
	_wijk_naam = "dorpskern"
	var o := _wijk(30, 20)
	vlak(o.x + 1, o.y + 1, o.x + 28, o.y + 18, "natuur/gras")
	var cx := o.x + 14
	var cz := o.y + 9
	# brink (dorpsplein) met kinderkopjes en een boom
	vlak(cx - 3, cz - 2, cx + 3, cz + 2, "plein/plein_keien")
	Pr(cx * 4 + 2.0, cz * 4 + 2.0, "bomen/linde")
	Pr((cx - 2) * 4 + 2.0, cz * 4 + 2.0, "straat/bank_hout", "E")
	Pr((cx + 2) * 4 + 2.0, cz * 4 + 2.0, "straat/bank_hout", "W")
	Pr((cx + 1) * 4 + 2.0, (cz - 1) * 4 + 2.0, "verlichting/lantaarn_klassiek")
	# keienstraten vanuit het plein, met stoepen van keien en een middengoot
	for z in range(o.y + 1, cz - 2):
		G(cx, z, "weg/straat_keien_middengoot")
		G(cx - 1, z, "stoep/stoep_keien_rand", "E")
		G(cx + 1, z, "stoep/stoep_keien_rand", "W")
	for z in range(cz + 3, o.y + 19):
		G(cx, z, "weg/straat_keien")
		G(cx - 1, z, "stoep/stoep_keien_rand", "E")
		G(cx + 1, z, "stoep/stoep_keien_rand", "W")
	for x in range(o.x + 1, cx - 3):
		G(x, cz, "weg/straat_keien", "E")
		G(x, cz - 1, "stoep/stoep_keien_rand", "S")
		G(x, cz + 1, "stoep/stoep_keien_rand", "N")
	# keienpad naar de kerk
	for x in range(cx + 4, o.x + 26):
		G(x, cz, "natuur/keienpad", "E")
	toren(o.x + 26, cz, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_klok", "toren_spits_onder", "toren_spits_boven"], "W")
	# klassieke huisjes rond de brink
	for i in range(4):
		var hx := cx - 3 + i * 2
		for zz in [cz - 4, cz + 4]:
			var naar := "S" if zz < cz else "N"
			B(hx, 0, zz, "klassiek_rood/klassiek_rood_" + ["bg_deur", "bg_raam", "bg_winkel_luifel", "bg_deur"][i], naar)
			B(hx, 1, zz, "klassiek_rood/klassiek_rood_dak_zadel", "E")
	Pr((cx - 3) * 4.0, (cz - 2) * 4.0, "paaltjes/amsterdammertje")
	Pr((cx + 4) * 4.0, (cz + 3) * 4.0, "paaltjes/amsterdammertje")
