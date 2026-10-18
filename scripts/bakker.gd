extends RefCounted
## Voegt de tiles van een GridMap samen tot grote meshes (chunks) en laat daarbij
## de zijden weg die tegen een dichte buurcel liggen, plus alle onderkanten.
## Minder driehoeken en veel minder draw calls. De importer groepeert de
## driehoeken per celzijde (meta "vlakken" en "dicht", zie vox_mesher.gd).

const Mesher = preload("res://addons/vox_tiles/vox_mesher.gd")
const VLAG := "res://addons/vox_tiles/materials/voxel_vlag.tres"
const WIND := "res://addons/vox_tiles/materials/voxel_wind.tres"
const DRIJF := "res://addons/vox_tiles/materials/voxel_drijf.tres"

## chunkgrootte in cellen
const CHUNK := 8
## ophogen als de uitkomst verandert (maakt de cache in user://samengevoegd ongeldig)
const VERSIE := 3
## rekentijd per frame; de rest gebeurt in volgende frames
const BUDGET_USEC := 6000


## Bakt de GridMap met de gegeven bibliotheek. boven_verbergen: bovenkanten
## mogen wegvallen als er een dichte cel bovenop staat (cellen even hoog als de tiles).
static func bak(gm: GridMap, lib: MeshLibrary, naam: String, boven_verbergen: bool) -> Node3D:
	var uit := Node3D.new()
	uit.name = naam
	uit.transform = gm.transform
	var cache := {}   # mesh -> [{mat, groepen: [[v, n, c] x 7]}]
	var dicht := {}   # item -> bitmasker
	var chunks := {}  # Vector3i(chunk x, chunk z, schaduw) -> {materiaal: [v, n, c]}
	var schaduw := {}
	var los := []     # cellen met vlaggen of wind: als losse mesh
	var basis_cache := {}
	var start := Time.get_ticks_usec()
	var teller := 0
	for c: Vector3i in gm.get_used_cells():
		teller += 1
		if teller % 64 == 0 and Time.get_ticks_usec() - start > BUDGET_USEC:
			await Engine.get_main_loop().process_frame
			start = Time.get_ticks_usec()
		var id := gm.get_cell_item(c)
		var mesh := lib.get_item_mesh(id) as ArrayMesh
		if mesh == null:
			continue
		var o := gm.get_cell_item_orientation(c)
		var b: Basis = basis_cache.get(o, Basis())
		if not basis_cache.has(o):
			b = gm.get_basis_with_orthogonal_index(o)
			basis_cache[o] = b
		var xf := Transform3D(b, gm.map_to_local(c)) * lib.get_item_mesh_transform(id)
		if not cache.has(mesh):
			cache[mesh] = _splits(mesh)
		var delen: Array = cache[mesh]
		if delen.is_empty():
			los.append([mesh, xf])
			continue
		# welke zijden zijn verborgen?
		var weg: int = 1 << Mesher.ONDER
		if mesh.has_meta("vlakken"):
			for g in 6:
				if g == Mesher.ONDER or (g == Mesher.BOVEN and not boven_verbergen):
					continue
				var w := Vector3i((b * Vector3(Mesher.RICHTINGEN[g])).round())
				var buur := c + w
				var bid := gm.get_cell_item(buur)
				if bid < 0:
					continue
				var bm := lib.get_item_mesh(bid)
				if bm == null or not bm.has_meta("dicht"):
					continue
				var bb := gm.get_basis_with_orthogonal_index(gm.get_cell_item_orientation(buur))
				var lokaal := Vector3i((bb.inverse() * Vector3(-w)).round())
				var bg: int = Mesher.RICHTINGEN.find(lokaal)
				if bg >= 0 and (int(bm.get_meta("dicht")) >> bg) & 1:
					weg |= 1 << g
		if not schaduw.has(id):
			schaduw[id] = lib.get_item_mesh_cast_shadow(id) if lib.has_method("get_item_mesh_cast_shadow") else 1
		var sleutel := Vector3i(floori(c.x / float(CHUNK)), floori(c.z / float(CHUNK)), schaduw[id])
		var chunk: Dictionary = chunks.get(sleutel, {})
		chunks[sleutel] = chunk
		var rot := Transform3D(xf.basis, Vector3.ZERO)
		for deel in delen:
			var mat: Material = deel.mat
			var doel: Array = chunk.get(mat, [])
			if doel.is_empty():
				doel = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
				chunk[mat] = doel
			for g in Mesher.GROEPEN:
				if (weg >> g) & 1:
					continue
				var gr: Array = deel.groepen[g]
				if gr[0].is_empty():
					continue
				doel[0].append_array(xf * gr[0])
				doel[1].append_array(rot * gr[1])
				doel[2].append_array(gr[2])
	for sleutel in chunks:
		var chunk: Dictionary = chunks[sleutel]
		var mesh := ArrayMesh.new()
		for mat in chunk:
			var d: Array = chunk[mat]
			if d[0].is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = d[0]
			arrays[Mesh.ARRAY_NORMAL] = d[1]
			arrays[Mesh.ARRAY_COLOR] = d[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		if mesh.get_surface_count() == 0:
			continue
		if Time.get_ticks_usec() - start > BUDGET_USEC:
			await Engine.get_main_loop().process_frame
			start = Time.get_ticks_usec()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = sleutel.z
		uit.add_child(mi)
	for l in los:
		var mi := MeshInstance3D.new()
		mi.mesh = l[0]
		mi.transform = l[1]
		uit.add_child(mi)
	return uit


## Splitst een mesh per oppervlak in de 7 groepen; leeg als de mesh los moet blijven.
static func _splits(mesh: ArrayMesh) -> Array:
	var delen := []
	var vlakken: Array = mesh.get_meta("vlakken", [])
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		# vlag-, wind- en drijf-shaders rekenen in lokale coördinaten: die tiles blijven los
		if mat == null or mat.resource_path in [VLAG, WIND, DRIJF]:
			return []
		var a := mesh.surface_get_arrays(s)
		if a[Mesh.ARRAY_INDEX] != null or a[Mesh.ARRAY_COLOR] == null:
			return []
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var k: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var grens: PackedInt32Array
		if s < vlakken.size():
			grens = vlakken[s]
		else:
			grens = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, v.size()])
		var groepen := []
		for g in Mesher.GROEPEN:
			groepen.append([v.slice(grens[g], grens[g + 1]), n.slice(grens[g], grens[g + 1]), k.slice(grens[g], grens[g + 1])])
		delen.append({"mat": mat, "groepen": groepen})
	return delen
