extends SceneTree
## The terraces (scripts/world/terraces.gd): on the café tables of the Plein and the Grote Markt
## people sit (on a chair: by a table, facing it, at seat height), you can talk to them, and
## the terraces have fewer parasols than plain tables.
## usage: tools/godot.sh --headless --script tools/check/terrace_test.gd

const Common = preload("res://tools/tool_common.gd")
const Conversations = preload("res://scripts/story/conversations.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	await process_frame
	var terraces: Node = scene.get_node_or_null("Terrassen")
	_check(terraces != null, "de node Terrassen")
	var guests: Array = terraces.guests() if terraces else []
	print("terrasgasten: %d" % guests.size())
	_check(guests.size() >= 8, "mensen op de terrasjes (%d)" % guests.size())
	var places: Dictionary = scene.get_meta("places")
	for place_key in ["plein", "grote_markt"]:
		var place: Vector2 = places.get(place_key, Vector2.INF)
		var near := guests.filter(func(guest: Node3D) -> bool: return Vector2(guest.global_position.x, guest.global_position.z).distance_to(place) < 40.0)
		_check(near.size() >= 2, "op het terras bij %s (%d)" % [place_key, near.size()])
	var props: GridMap = scene.get_node("Props")
	var parasols := 0
	var plain := 0
	for cell in props.get_used_cells():
		var item_name := props.mesh_library.get_item_name(props.get_cell_item(cell))
		if item_name.begins_with("terras/terras_set_parasol"):
			parasols += 1
		elif item_name == "terras/terras_set" or item_name.begins_with("terras/tafel_"):
			plain += 1
	print("terrastafels: %d met parasol, %d zonder" % [parasols, plain])
	_check(plain > parasols * 1.5, "minder parasols dan tafeltjes")
	if not guests.is_empty():
		var guest: Node3D = guests[0]
		_check(guest.sitting and guest.is_in_group("aanspreekbaar"), "ze zitten en zijn aan te spreken")
		var talk := Conversations.new(guest, null, null)
		_check(not (talk.opening()[0] as Dictionary).get("choices", []).is_empty(), "een gesprek met een terrasgast")
	print("terras ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)
