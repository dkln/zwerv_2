extends "res://tests/integration/support/town_test.gd"
## The start of the game (scripts/camera/follow_camera.gd, arrival): the view starts high in
## the sky, comes down onto the player through the clouds (scripts/effects/cloud_shroud.gd:
## thickest high up, thinning out on the way down, gone at the end), and then follows as
## usual at zoom_still. The town as the game starts it (not woken, the arrival not skipped),
## so a world of its own.
##   tests/run_integration_tests.sh arrival


static func world_options() -> Dictionary:
	return {"wake": false, "without": ["DetailNiveau", "Rook", "Verhaal"]}


## The whole arrival, from the first frame: high up in a layer of clouds, ever lower, the
## clouds thinning and gone at the end, then close to the player.
func test_the_view_comes_down_through_the_clouds_onto_the_player(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	test.check(camera.is_arriving(), "het spel begint met de afdaling")
	test.check(camera._zoom > camera.zoom_still * 4.0, "hoog in de lucht (%.0f m in beeld)" % camera._zoom)
	var clouds: Node = camera._clouds
	test.check(clouds != null and clouds.is_inside_tree(), "met een wolkenlaag")
	var thickest := 0.0
	var thinning := true
	var cover_then := INF
	var zoom_then := INF
	var going_down := true
	var waited := 0.0
	while camera.is_arriving() and waited < camera.arrival_seconds + 3.0:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
		if camera._clouds:
			thickest = maxf(thickest, camera._clouds.cover)
			if camera._clouds.cover > cover_then + 0.001:
				thinning = false
			cover_then = camera._clouds.cover
		if camera._zoom > zoom_then + 0.01:
			going_down = false
		zoom_then = camera._zoom
	test.check(not camera.is_arriving(), "de afdaling is klaar")
	test.check(going_down, "steeds lager")
	test.check(thickest > 0.95, "hoog in de wolken (dekking %.2f)" % thickest)
	test.check(thinning, "de wolken worden dunner naarmate hij zakt")
	test.check(camera._clouds == null, "daarna zijn de wolken weg")
	await frames(30)
	test.check(absf(camera._zoom - camera.zoom_still) < camera.zoom_still * 0.15, "dan dichtbij de speler (%.1f m in beeld)" % camera._zoom)
