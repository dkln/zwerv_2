extends "res://tests/integration/support/town_test.gd"
## Walking into a snack bar (scripts/world/interiors/interiors.gd, scripts/world/interiors/interior.gd): the snack
## bars are found with a door each (one by the deer camp in the Koekamp, close to Centraal),
## at a door "[E] Naar binnen" shows, going in swipes into the interior (dressed: its name,
## the one behind the counter, people at the tables), the camera follows at once and does not
## turn round buildings inside, a kroket bought there ticks off mission 1, and "[E] Naar
## buiten" takes you back onto the pavement before the door.
##   tests/run_integration_tests.sh interior


## The snack bars near the deer camp in the Koekamp (within 6 m of the place on the map).
func _bars_by_the_deer_camp() -> Array:
	var places: Dictionary = scene.get_meta("places")
	var deer_camp: Vector2 = places.get("snackbar_hertenkamp", Vector2.INF)
	return interiors.snack_bars().filter(func(bar: Dictionary) -> bool: return Vector2(bar.door.x, bar.door.z).distance_to(deer_camp) < 6.0)


## The snack bar the tests go into: the one by the deer camp (else the first).
func _the_bar() -> Dictionary:
	var near_deer := _bars_by_the_deer_camp()
	return near_deer[0] if not near_deer.is_empty() else interiors.snack_bars()[0]


## The ambience plays the sound of `place` ("winkel", "straat").
func _ambience_is(place: String) -> bool:
	return interiors._ambience.place == place and interiors._ambience._player != null and interiors._ambience._player.playing


## The town has snack bars with a door each, one by the deer camp and a Jan Blammage among them.
func test_snack_bars_have_a_door(test) -> void:
	var bars: Array = interiors.snack_bars()
	print("snackbars: %d" % bars.size())
	for bar: Dictionary in bars:
		print("  %-22s deur %s" % [bar.name, bar.door.snapped(Vector3.ONE * 0.1)])
	test.check(bars.size() >= 8, "snackbars met een deur (%d)" % bars.size())
	test.check(not _bars_by_the_deer_camp().is_empty(), "een snackbar bij het hertenkamp")
	test.check(bars.any(func(bar: Dictionary) -> bool: return bar.name == "Jan Blammage"), "een Jan Blammage")
	var station: Vector2 = (scene.get_meta("places") as Dictionary).centraal
	var door: Vector3 = _the_bar().door
	print("van Centraal naar de snackbar: %.0f m" % Vector2(door.x, door.z).distance_to(station))


## At the door [E] Naar binnen, then a swipe into the interior: the shop's murmur, the
## player inside, the camera with them at once, zoomed in and not turning round buildings.
func test_going_in_at_the_door_swipes_inside(test) -> void:
	var bar := _the_bar()
	var follow: Node = scene.get_node("Volgcamera")
	await stand_at(bar.door)
	test.check(prompts() == [["E", "Naar binnen"]], "bij de deur: [E] Naar binnen")
	use_prompt()
	# straight into the swipe (no walk through the door shown first)
	var swiped := await wait_until(func() -> bool: return tree.root.has_node("Swipe"), 6.0)
	test.check(swiped, "met een swipe")
	await wait_until(func() -> bool: return interiors.is_inside(), 6.0)
	await seconds(0.8)
	var interior: Node3D = interiors._interior
	test.check(interiors.is_inside() and interior != null, "binnen")
	if interior == null:
		return
	test.check(_ambience_is("winkel"), "binnen het geroezemoes van de winkel")
	test.check(player.global_position.distance_to(interior.global_position) < 8.0, "de speler is binnen (%.1f m van het midden)" % player.global_position.distance_to(interior.global_position))
	test.check(follow._view_focus.distance_to(player.global_position) < 3.0, "de camera is meteen mee")
	test.check(not follow.turn_round_buildings, "binnen draait de camera niet om gebouwen")
	test.check(is_equal_approx(follow._zoom, follow.indoor_zoom), "binnen verder ingezoomd (%.1f m in beeld)" % follow._zoom)


## The interior is dressed as this snack bar: its name, one keeper behind the counter,
## guests at the tables, and room for the player to stand.
func test_inside_is_this_snack_bar_with_keeper_and_guests(test) -> void:
	var bar := _the_bar()
	await interiors.enter(bar)
	await frames(30)
	var interior: Node3D = interiors._interior
	test.check(interiors.is_inside() and interior != null, "binnen")
	if interior == null:
		return
	test.check(String(interior.snack_bar_name) == String(bar.name), "de naam van deze snackbar binnen (%s)" % interior.snack_bar_name)
	var people: Array = interior.people()
	var keepers := people.filter(func(person: Node) -> bool: return person.role == "snackbarhouder")
	var guests := people.filter(func(person: Node) -> bool: return person.role == "klant")
	test.check(keepers.size() == 1, "iemand achter de toonbank")
	test.check(guests.size() >= 1, "mensen aan de tafeltjes (%d)" % guests.size())
	test.check(player._fits(player.global_position), "binnen staat de speler vrij")


## Talking to the keeper opens the shop screen with the menu, and a kroket bought there
## (€ 2) finishes mission 1.
func test_kroket_bought_at_the_counter_and_eaten_ticks_off_mission_1(test) -> void:
	await interiors.enter(_the_bar())
	await frames(30)
	var interior: Node3D = interiors._interior
	var keepers: Array = interior.people().filter(func(person: Node) -> bool: return person.role == "snackbarhouder") if interior else []
	test.check(keepers.size() == 1, "iemand achter de toonbank")
	if keepers.is_empty():
		return
	player.add_money(5.0)
	var story: Node = scene.get_node("Verhaal")
	for step_id in ["blikjes", "statiegeld", "bedelen"]:
		story.complete_step("missie_1_lege_maag", step_id)
	player.talk_to(keepers[0])
	await frames(1)
	test.check(hud.is_showing_shop(), "praten met de snackbarhouder: het winkelscherm")
	var shop: Control = hud._shop_screen
	var goods: Array = shop._rows.filter(func(row: Dictionary) -> bool: return row.kind == "kopen")
	print("snackbarhouder: ", shop.spoken_text(), "  ", goods.map(func(row: Dictionary) -> String: return row.item))
	test.check(goods.size() >= 3 and String(goods[0].item) == "kroket", "de kaart om te bestellen")
	var money_before: float = player.money
	var krokets_before := int(player.inventory.get("kroket", 0))
	print("  ", shop.buy(0), ": ", shop.spoken_text())
	test.check(is_equal_approx(player.money, money_before - 2.0) and int(player.inventory.get("kroket", 0)) == krokets_before + 1, "een kroket gekocht (€ 2)")
	test.check(not story.step_done("missie_1_lege_maag", "kroket"), "gekocht, nog niet gegeten: de stap staat nog open")
	test.check(player.eat_something() and story.step_done("missie_1_lege_maag", "kroket"), "de kroket opgegeten (F): de stap is klaar")


## At the door inside [E] Naar buiten puts you back before the door outside: the street's
## murmur again, the camera turning round buildings again.
func test_going_out_puts_you_before_the_door(test) -> void:
	var bar := _the_bar()
	var follow: Node = scene.get_node("Volgcamera")
	await interiors.enter(bar)
	await frames(30)
	test.check(interiors.is_inside(), "binnen")
	if not interiors.is_inside():
		return
	await stand_at((interiors._exit as Node3D).global_position)
	test.check(prompts() == [["E", "Naar buiten"]], "bij de deur binnen: [E] Naar buiten")
	await use_door()
	test.check(not interiors.is_inside() and player.global_position.distance_to(bar.door) < 2.0, "weer buiten voor de deur")
	test.check(_ambience_is("straat"), "buiten weer het geroezemoes van de straat")
	test.check(follow.turn_round_buildings, "buiten draait de camera weer om gebouwen")
