extends SceneTree
## Walking into a snack bar (scripts/world/interiors.gd, scripts/world/interior.gd): the snack
## bars are found with a door each (one by the deer camp in the Koekamp, close to Centraal),
## at a door "[E] Naar binnen" shows, going in swipes into the interior (dressed: its name,
## the one behind the counter, people at the tables), the camera follows at once and does not
## turn round buildings inside, a kroket bought there ticks off mission 1, and "[E] Naar
## buiten" takes you back onto the pavement before the door.
## usage: tools/godot.sh --headless --script tools/check/interior_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var hud: Node = scene.get_node("HUD")
	var follow: Node = scene.get_node("Volgcamera")
	follow._end_arrival()
	for frame_index in 600:
		await physics_frame
		if player._placed and not player._sleeping:
			break
	player._wake_up()
	# getting up takes a moment (wake_time): real seconds, headless frames go faster
	for attempt in 40:
		if not player._sleeping:
			break
		await create_timer(0.1, true).timeout
	# the story's prologue out of the way
	for frame_index in 120:
		await process_frame
		if hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
	var interiors: Node = scene.get_node("Binnenruimtes")
	var bars: Array = interiors.snack_bars()
	print("snackbars: %d" % bars.size())
	for bar: Dictionary in bars:
		print("  %-22s deur %s" % [bar.name, bar.door.snapped(Vector3.ONE * 0.1)])
	_check(bars.size() >= 8, "snackbars met een deur (%d)" % bars.size())
	var places: Dictionary = scene.get_meta("places")
	var deer_camp: Vector2 = places.get("snackbar_hertenkamp", Vector2.INF)
	var near_deer := bars.filter(func(bar: Dictionary) -> bool: return Vector2(bar.door.x, bar.door.z).distance_to(deer_camp) < 6.0)
	_check(not near_deer.is_empty(), "een snackbar bij het hertenkamp")
	_check(bars.any(func(bar: Dictionary) -> bool: return bar.name == "Jan Blammage"), "een Jan Blammage")
	var bar: Dictionary = near_deer[0] if not near_deer.is_empty() else bars[0]
	var station: Vector2 = places.centraal
	print("van Centraal naar de snackbar: %.0f m" % Vector2(bar.door.x, bar.door.z).distance_to(station))
	# at the door: the action, then in
	player.teleport(bar.door, 0.0)
	for frame_index in 4:
		await physics_frame
	_check(hud._action_prompts.visible and hud._action_prompts.actions() == [["E", "Naar binnen"]], "bij de deur: [E] Naar binnen")
	player._talk_partner.go_through()
	await create_timer(0.4, true).timeout
	_check(get_root().has_node("Swipe"), "met een swipe")
	await create_timer(0.8, true).timeout
	var interior: Node3D = interiors._interior
	_check(interiors.is_inside() and interior != null, "binnen")
	_check(interiors._ambience.place == "winkel" and interiors._ambience._player != null and interiors._ambience._player.playing,
			"binnen het geroezemoes van de winkel")
	_check(player.global_position.distance_to(interior.global_position) < 8.0, "de speler is binnen (%.1f m van het midden)" % player.global_position.distance_to(interior.global_position))
	_check(follow._view_focus.distance_to(player.global_position) < 3.0, "de camera is meteen mee")
	_check(not follow.turn_round_buildings, "binnen draait de camera niet om gebouwen")
	_check(is_equal_approx(follow._zoom, follow.indoor_zoom), "binnen verder ingezoomd (%.1f m in beeld)" % follow._zoom)
	_check(String(interior.snack_bar_name) == String(bar.name), "de naam van deze snackbar binnen (%s)" % interior.snack_bar_name)
	var people: Array = interior.people()
	var keeper := people.filter(func(person: Node) -> bool: return person.role == "snackbarhouder")
	var guests := people.filter(func(person: Node) -> bool: return person.role == "klant")
	_check(keeper.size() == 1, "iemand achter de toonbank")
	_check(guests.size() >= 1, "mensen aan de tafeltjes (%d)" % guests.size())
	for frame_index in 30:
		await physics_frame
	_check(player._fits(player.global_position), "binnen staat de speler vrij")
	# order a kroket: the money, the step of the mission
	player.add_money(5.0)
	var story: Node = scene.get_node("Verhaal")
	story.complete_step("missie_1_kroket", "kleingeld")
	# talking to the one behind the counter: the shop screen, the kroket bought there
	player.talk_to(keeper[0])
	await process_frame
	_check(hud.is_showing_shop(), "praten met de snackbarhouder: het winkelscherm")
	var shop: Control = hud._shop_screen
	var goods: Array = shop._rows.filter(func(row: Dictionary) -> bool: return row.kind == "kopen")
	print("snackbarhouder: ", shop.spoken_text(), "  ", goods.map(func(row: Dictionary) -> String: return row.item))
	_check(goods.size() >= 3 and String(goods[0].item) == "kroket", "de kaart om te bestellen")
	var money_before: float = player.money
	print("  ", shop.buy(0), ": ", shop.spoken_text())
	_check(is_equal_approx(player.money, money_before - 2.0) and int(player.inventory.get("kroket", 0)) == 1, "een kroket gekocht (€ 2)")
	_check(story.step_done("missie_1_kroket", "kroket") and story.is_finished("missie_1_kroket"), "kroket gekocht: missie 1 klaar")
	for attempt in 3:
		if hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
		await process_frame
	shop._close()
	await process_frame
	# out again
	var exit: Node3D = interiors._exit
	player.teleport(exit.global_position, 0.0)
	for frame_index in 4:
		await physics_frame
	_check(hud._action_prompts.actions() == [["E", "Naar buiten"]], "bij de deur binnen: [E] Naar buiten")
	player._talk_partner.go_through()
	await create_timer(1.2, true).timeout
	_check(not interiors.is_inside() and player.global_position.distance_to(bar.door) < 2.0, "weer buiten voor de deur")
	_check(interiors._ambience.place == "straat" and interiors._ambience._player != null and interiors._ambience._player.playing,
			"buiten weer het geroezemoes van de straat")
	_check(follow.turn_round_buildings, "buiten draait de camera weer om gebouwen")
	print("binnenruimte ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)
