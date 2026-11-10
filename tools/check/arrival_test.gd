extends SceneTree
## The start of the game (scripts/camera/follow_camera.gd, arrival): the view starts high in
## the sky, comes down onto the player through the clouds (scripts/effects/cloud_shroud.gd:
## thickest high up, thinning out on the way down, gone at the end), and then follows as usual at zoom_still.
## usage: tools/godot.sh --headless --script tools/check/arrival_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	PlayerCharacter.choose("jos")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var camera: Node = scene.get_node("Volgcamera")
	await process_frame
	await process_frame
	_check(camera.is_arriving(), "het spel begint met de afdaling")
	_check(camera._zoom > camera.zoom_still * 10.0, "hoog in de lucht (%.0f m in beeld)" % camera._zoom)
	var clouds: Node = camera._clouds
	_check(clouds != null and clouds.is_inside_tree(), "met een wolkenlaag")
	var thickest := 0.0
	var thinning := true
	var cover_then := INF
	var zoom_then := INF
	var going_down := true
	var started := Time.get_ticks_msec()
	while camera.is_arriving() and Time.get_ticks_msec() - started < (camera.arrival_seconds + 3.0) * 1000.0:
		await process_frame
		if camera._clouds:
			thickest = maxf(thickest, camera._clouds.cover)
			if camera._clouds.cover > cover_then + 0.001:
				thinning = false
			cover_then = camera._clouds.cover
		if camera._zoom > zoom_then + 0.01:
			going_down = false
		zoom_then = camera._zoom
	_check(not camera.is_arriving(), "de afdaling is klaar")
	_check(going_down, "steeds lager")
	_check(thickest > 0.95, "hoog in de wolken (dekking %.2f)" % thickest)
	_check(thinning, "de wolken worden dunner naarmate hij zakt")
	_check(camera._clouds == null, "daarna zijn de wolken weg")
	for frame_index in 30:
		await process_frame
	_check(absf(camera._zoom - camera.zoom_still) < camera.zoom_still * 0.15, "dan dichtbij de speler (%.1f m in beeld)" % camera._zoom)
	print("aankomst ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
