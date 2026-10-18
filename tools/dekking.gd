extends SceneTree
## Toont welke tiles in de kaart in context gebruikt worden (alles behalve de catalogus).
## gebruik: Godot --headless --script tools/dekking.gd
func _init():
	var sc: Node = load("res://scenes/wereld.tscn").instantiate()
	var grens: float = sc.get_meta("catalogus_start_m", 400.0)
	var totaal := 0
	var gebruikt_totaal := 0
	for naam in ["Grond", "Gebouwen", "Details", "Props"]:
		var gm: GridMap = sc.get_node(naam)
		var cel := gm.cell_size.z
		var gebruikt := {}
		for c in gm.get_used_cells():
			if c.z * cel < grens:
				gebruikt[gm.get_cell_item(c)] = true
		var lib := gm.mesh_library
		var groepen := {}
		for id in lib.get_item_list():
			if not gebruikt.has(id):
				var g: String = lib.get_item_name(id).split("/")[0]
				groepen[g] = groepen.get(g, 0) + 1
				if groepen[g] <= 3:
					print("  ongebruikt: ", lib.get_item_name(id))
		var n := lib.get_item_list().size()
		totaal += n
		gebruikt_totaal += gebruikt.size()
		print("%s: %d van %d gebruikt; ongebruikt per groep: %s" % [naam, gebruikt.size(), n, groepen])
	print("TOTAAL %d van %d" % [gebruikt_totaal, totaal])
	sc.free()
	quit()
