extends SceneTree
## Opens the character creation screen (scenes/karakter.tscn) headless: checks the list
## and the detail panel with their 3D figures (PlayerModel meshes, voxel faces and glowing parts), chooses
## the ufo pilot with the keys, begins, and waits until the town is open with the pilot in
## the HUD (name, portrait, the maximum of the stats). Prints "karakter ok" per step.
## usage: tools/godot.sh --headless --script tools/check/character_test.gd
##        (-- figures: only the figures, no town)

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")


func _init() -> void:
	Common.watchdog(self, 400)
	var problems := []
	for archetype_id: String in PlayerCharacter.ORDER:
		var parts := PlayerModel.parts_for(archetype_id)
		var triangles := 0
		var kinds := {}
		for part: String in parts.meshes:
			var mesh: ArrayMesh = parts.meshes[part]
			for surface in mesh.get_surface_count():
				triangles += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				kinds[mesh.surface_get_material(surface).get_class()] = true
		print("%s: delen %s, %d driehoeken, %.2f m hoog, materialen %s" % [archetype_id, parts.meshes.keys(),
				triangles, parts.height, kinds.keys()])
		for limb: String in PlayerModel.LIMBS:
			if not parts.meshes.has(limb):
				problems.append("%s heeft geen %s" % [archetype_id, limb])
		if triangles < 500:
			problems.append("%s te weinig detail" % archetype_id)
	if Common.arg(0) == "figures":
		print("karakter ok" if problems.is_empty() else "FOUT: " + str(problems))
		quit()
		return
	var screen_scene: Node = load("res://scenes/karakter.tscn").instantiate()
	get_root().add_child(screen_scene)
	current_scene = screen_scene
	await Common.wait_frames(self, 5)
	var screen := screen_scene.get_node("Scherm")
	print("in de lijst: ", screen._entries.size(), ", knop: ", screen._begin_button.text)
	if screen._entries.size() != PlayerCharacter.ORDER.size():
		problems.append("niet %d in de lijst" % PlayerCharacter.ORDER.size())
	var heights := []
	for entry: Control in screen._entries:
		heights.append(entry.size.y)
	var list_end: float = screen._entries[-1].position.y + screen._entries[-1].size.y
	print("lijst: hoogtes ", heights, ", eind ", list_end, " (detail ", screen.HEIGHT, ")")
	if screen._scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		problems.append("de lijst scrollt")
	if absf(list_end - screen.HEIGHT) > 1.0:
		problems.append("lijst niet over de hoogte van het detail verdeeld")
	screen._select(2)
	await Common.wait_frames(self, 60)
	print("loopt: ", screen._detail_figure.walking, ", moeilijkheid: ", screen._difficulty_name.text)
	if screen._detail_figure.walking < 0.5:
		problems.append("loopt niet")
	print("gekozen: ", screen._begin_button.text, ", detail ", screen._detail_name.text, " / ",
			screen._detail_subtitle.text, ", lijst scrollt: ", screen._scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED)
	if screen._detail_name.text != "Ufo Piloot" or screen._detail_figure.archetype_id != "ufo_piloot":
		problems.append("detail toont de keuze niet")
	screen.begin()
	var waited := 0
	while waited < 4000:
		await process_frame
		waited += 1
		if current_scene != null and current_scene.name == "Stad":
			break
	if current_scene == null or current_scene.name != "Stad":
		problems.append("de stad ging niet open")
	else:
		print("karakter ok: stad geopend")
		await Common.wait_frames(self, 5)
		var hud := current_scene.get_node("HUD")
		print("HUD: ", hud.player_name, ", leven ", hud.get_stat("gezondheid"), ", stamina ",
				hud.get_stat("uithoudingsvermogen"), ", honger ", hud.get_stat("honger"), ", portret ",
				hud._portrait.archetype_id)
		if hud.player_name != "Ufo Piloot" or hud.get_stat("gezondheid") != Vector2(150, 150) \
				or hud._portrait.archetype_id != "ufo_piloot":
			problems.append("HUD heeft de keuze niet")
	print("karakter ok" if problems.is_empty() else "FOUT: " + str(problems))
	quit()
