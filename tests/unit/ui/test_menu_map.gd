extends RefCounted
## Unit tests of the living map behind the main menu (scripts/ui/menu/menu_map.gd) without
## the map itself (it is big and loads in the background): the camera gliding and swaying,
## how bad it has got (the chaos), two vehicles touching, where the sun and the moon are on
## their arcs, the curve the helicopter flies in on, and the small things it makes (a sky
## disc, its halo, the shade on the left).
##   tests/run_unit_tests.sh menu_map

const MenuMap = preload("res://scripts/ui/menu/menu_map.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_hermite_curve(test) -> void:
	var from := Vector3(0, 10, 0)
	var to := Vector3(100, 20, -50)
	test.check(MenuMap._hermite(from, Vector3(30, 0, 0), to, Vector3(0, 0, -30), 0.0).is_equal_approx(from), "aan het begin: het beginpunt")
	test.check(MenuMap._hermite(from, Vector3(30, 0, 0), to, Vector3(0, 0, -30), 1.0).is_equal_approx(to), "aan het eind: het eindpunt")
	test.check(MenuMap._hermite(from, Vector3.ZERO, to, Vector3.ZERO, 0.5).is_equal_approx((from + to) * 0.5), "zonder raaklijnen halverwege: het midden")
	var straight := MenuMap._hermite(from, to - from, to, to - from, 0.25)
	test.check(straight.is_equal_approx(from.lerp(to, 0.25)), "raaklijnen langs de lijn: een rechte lijn")
	var leaving := MenuMap._hermite(Vector3.ZERO, Vector3(10, 0, 0), Vector3(0, 0, 10), Vector3.ZERO, 0.1)
	test.check(leaving.x > 0.0 and leaving.x > leaving.z, "vlak na het begin gaat hij de kant van de eerste raaklijn op (%s)" % leaving)


func test_touching(test) -> void:
	test.check(MenuMap.touching(Vector3(3.0, 0, 0), 8.0), "achter elkaar, dichter dan de halve lengtes samen: ze raken")
	test.check(not MenuMap.touching(Vector3(4.0, 0, 0), 8.0), "precies de halve lengtes: nog net niet")
	test.check(MenuMap.touching(Vector3(-3.0, 5.0, 2.0), 8.0), "de andere kant op, een beetje opzij, hoogte telt niet")
	test.check(not MenuMap.touching(Vector3(1.0, 0, 2.2), 8.0) and not MenuMap.touching(Vector3(1.0, 0, -3.0), 8.0), "op een andere baan: niet")
	var menu := MenuMap.new()
	var first := Node3D.new()
	var second := Node3D.new()
	tree.root.add_child(first)
	tree.root.add_child(second)
	second.position = Vector3(4.5, 0, 0)
	test.check(not menu._touch(first, second), "twee voertuigen (4 m lang als niets bekend is) 4,5 m uit elkaar: niet")
	second.position = Vector3(3.9, 0, 0)
	test.check(menu._touch(first, second), "op 3,9 m raken ze wel")
	second.position = Vector3(5.0, 0, 0)
	test.check(not menu._touch(first, second), "op 5 m niet")
	first.set_meta("lengte", 9.0)
	test.check(menu._touch(first, second) and menu._touch(second, first), "een lange (9 m) en een korte op 5 m: ze raken, van beide kanten gezien")
	test.check(menu._speed_of(first) == Vector3.ZERO, "zonder snelheid: stil")
	first.set_meta("snelheid", Vector3(6, 0, 0))
	test.check(menu._speed_of(first) == Vector3(6, 0, 0), "zijn snelheid")
	first.free()
	second.free()
	menu.free()


func test_day_and_night_share(test) -> void:
	test.check(is_equal_approx(MenuMap.day_share_at(5.5, 5.5, 22.0), 0.0) and is_equal_approx(MenuMap.day_share_at(22.0, 5.5, 22.0), 1.0), "de zon: 0 bij opkomst, 1 bij ondergang")
	test.check(is_equal_approx(MenuMap.day_share_at(13.75, 5.5, 22.0), 0.5), "halverwege de dag: op zijn hoogst")
	test.check(MenuMap.day_share_at(3.0, 5.5, 22.0) < 0.0 and MenuMap.day_share_at(23.0, 5.5, 22.0) > 1.0, "voor opkomst en na ondergang: onder")
	test.check(is_equal_approx(MenuMap.night_share_at(22.0, 5.5, 22.0), 0.0), "de maan: 0 bij zonsondergang")
	test.check(is_equal_approx(MenuMap.night_share_at(1.75, 5.5, 22.0), 0.5), "midden in de nacht (over middernacht heen): op zijn hoogst")
	test.check(is_equal_approx(MenuMap.night_share_at(5.5, 5.5, 22.0), 1.0), "1 bij zonsopkomst")
	test.check(MenuMap.night_share_at(12.0, 5.5, 22.0) > 1.0, "overdag: onder")


func test_arc_direction(test) -> void:
	var forward := Vector3(0, 0, -1)
	var rise := MenuMap.arc_direction(forward, 0.0, -14.0, 22.0, 11.0)
	var high := MenuMap.arc_direction(forward, 0.5, -14.0, 22.0, 11.0)
	var set_down := MenuMap.arc_direction(forward, 1.0, -14.0, 22.0, 11.0)
	test.check(is_equal_approx(rise.length(), 1.0) and is_equal_approx(high.length(), 1.0), "een richting van lengte 1")
	test.check(rise.x < 0.0 and set_down.x > 0.0, "op links, onder rechts (de camera kijkt langs -z)")
	test.check(rise.y < 0.0 and set_down.y < 0.0 and high.y > rise.y, "op en onder net onder de horizon, halverwege hoger")
	test.check(is_equal_approx(high.y, sin(deg_to_rad(10.0))), "op zijn hoogst: 11 graden min één (%.4f)" % high.y)
	test.check(is_equal_approx(rad_to_deg(atan2(rise.x, -rise.z)), -14.0) and is_equal_approx(rad_to_deg(atan2(set_down.x, -set_down.z)), 22.0),
		"van 14 graden links tot 22 graden rechts")
	var sideways := MenuMap.arc_direction(Vector3(1, 0, 0), 0.5, -10.0, 10.0, 20.0)
	test.check(is_equal_approx(sideways.z, 0.0) and sideways.x > 0.9 and sideways.y > 0.0, "met een camera die een andere kant op kijkt: daar voor")


func test_chaos_grows_to_one(test) -> void:
	var menu := MenuMap.new()
	test.check(menu._chaos() == 0.0, "aan het begin: rustig")
	menu._menu_seconds = MenuMap.CHAOS_SECONDS * 0.5
	test.check(is_equal_approx(menu._chaos(), 0.5), "halverwege: half")
	menu._menu_seconds = MenuMap.CHAOS_SECONDS * 3.0
	test.check(menu._chaos() == 1.0, "erna: niet erger dan 1")
	menu._spread_fires()
	test.check(menu._fires.is_empty(), "zonder vuur op de kaart komt er geen bij")
	var shares: Array = MenuMap.FIRE_AT
	var sorted_shares := shares.duplicate()
	sorted_shares.sort()
	test.check(shares == sorted_shares and float(shares[0]) > 0.0 and float(shares[-1]) < 1.0, "de vuren komen er een voor een bij, tussen 0 en 1")
	menu.free()


func test_the_camera_glides_and_starts_over_after_a_period(test) -> void:
	var menu := MenuMap.new()
	menu._drift(1.0)
	test.check(menu._panned == 0.0, "zonder kaart glijdt er niets")
	var camera := Camera3D.new()
	menu._map_camera = camera
	menu._camera_start = Transform3D(Basis.IDENTITY, Vector3(10, 30, 50))
	menu._period = 100.0
	menu.pan_speed = 2.5
	menu._drift(4.0)
	test.check(is_equal_approx(menu._panned, 10.0) and camera.transform.origin.is_equal_approx(Vector3(0, 30, 50)), "na 4 s: 10 m opzij (naar -x), verder niets")
	menu._drift(38.0)
	test.check(is_equal_approx(menu._panned, 5.0) and camera.transform.origin.is_equal_approx(Vector3(5, 30, 50)), "na een hele periode begint hij ongezien opnieuw (%.1f)" % menu._panned)
	test.check(camera.transform.basis.is_equal_approx(Basis.IDENTITY), "hij blijft dezelfde kant op kijken")
	camera.free()
	menu.free()


func test_without_a_period_the_camera_sways(test) -> void:
	var menu := MenuMap.new()
	var camera := Camera3D.new()
	menu._map_camera = camera
	menu._camera_start = Transform3D(Basis.IDENTITY, Vector3(0, 30, 0))
	menu._drift(MenuMap.SWAY_SECONDS * 0.25)
	test.check(camera.transform.origin.is_equal_approx(Vector3(MenuMap.SWAY_METRES, 30, 0)), "na een kwart: helemaal naar één kant")
	menu._drift(MenuMap.SWAY_SECONDS * 0.5)
	test.check(camera.transform.origin.is_equal_approx(Vector3(-MenuMap.SWAY_METRES, 30, 0)), "een halve slag later: de andere kant")
	menu._drift(MenuMap.SWAY_SECONDS * 0.25)
	test.check(absf(camera.transform.origin.x) < 0.001, "na een hele slag: weer in het midden")
	camera.free()
	menu.free()


func test_the_column_kinds_are_complete(test) -> void:
	for kind: String in MenuMap.COLUMN_KINDS:
		var column: Dictionary = MenuMap.COLUMN_KINDS[kind]
		test.check((column.every as Vector2).x <= (column.every as Vector2).y and (column.first as Vector2).x <= (column.first as Vector2).y,
			"%s: de wachttijden van-tot" % kind)
		test.check((column.count as Vector2i).x >= 1 and (column.count as Vector2i).x <= (column.count as Vector2i).y, "%s: minstens één voertuig" % kind)
		test.check(float(column.spacing) > 0.0 and float(column.speed) > 0.0 and column.bob is bool, "%s: afstand, snelheid, hobbelen" % kind)


func test_sky_disc_halo_and_shade(test) -> void:
	var disc := MenuMap._sky_disc("Maan", 40.0, Color("#F2E8C9"), 0.6)
	var body := disc.get_node("Schijf") as MeshInstance3D
	var halo := disc.get_node("Gloed") as MeshInstance3D
	test.check(disc.name == "Maan" and body != null and halo != null, "een schijf met een gloed erachter")
	test.check((body.mesh as SphereMesh).radius == 40.0 and (body.mesh as SphereMesh).height == 80.0, "de schijf: een bol van die straal")
	var body_material := (body.mesh as SphereMesh).material as StandardMaterial3D
	test.check(body_material.albedo_color == Color("#F2E8C9") and body_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and body_material.disable_fog,
		"in zijn kleur, zonder schaduw of mist")
	var halo_material := (halo.mesh as QuadMesh).material as StandardMaterial3D
	test.check((halo.mesh as QuadMesh).size == Vector2.ONE * 280.0 and is_equal_approx(halo_material.albedo_color.a, 0.6)
		and halo_material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED, "de gloed: zeven keer zo groot, zo sterk als gevraagd, naar de camera")
	disc.free()
	var texture := MenuMap._halo_texture()
	test.check(texture.fill == GradientTexture2D.FILL_RADIAL and texture.gradient.get_color(0).a == 1.0
		and texture.gradient.get_color(texture.gradient.get_point_count() - 1).a == 0.0, "de gloed: rond, wit in het midden, weg aan de rand")
	var shade := MenuMap._left_shade()
	var shade_gradient := (shade.texture as GradientTexture2D).gradient
	test.check(shade.name == "Schaduw" and is_equal_approx(shade.anchor_right, 0.7) and shade.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"de schaduw over het linkerdeel, vangt geen muis")
	test.check(shade_gradient.get_color(0).a > shade_gradient.get_color(shade_gradient.get_point_count() - 1).a
		and shade_gradient.get_color(shade_gradient.get_point_count() - 1).a == 0.0, "donker links, niets rechts")
	shade.free()
