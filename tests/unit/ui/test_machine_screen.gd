extends RefCounted
## Unit tests of the close-up of a machine (scripts/ui/machines/machine_screen.gd, the base of
## the three machines) on its own, without the swipe (animate off) and with a stand-in player:
## putting it up and leaving it (the pause, `finished`, only one at a time), its display, the
## tray and the pockets, its labels and buttons, Escape, and the pure calculations (the
## close-up of the camera, the cursor's next target, the bulge of the glass, the fit in the
## window).
##   tests/run_unit_tests.sh machine_screen

const MachineScreen = preload("res://scripts/ui/machines/machine_screen.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A wallet and pockets, as a machine reads them of the player.
class TestPlayer:
	extends Node
	var money := 12.5
	var inventory := {}


## Counts `finished` and the presses of a button.
class Listener:
	var finished_calls := 0
	var presses := 0

	func on_finished() -> void:
		finished_calls += 1

	func on_press() -> void:
		presses += 1


func _player() -> TestPlayer:
	var player := TestPlayer.new()
	tree.root.add_child(player)
	return player


## A plain machine up for `player` (no swipe, no waiting); null when it could not be shown.
static func _present(player: Node) -> Node:
	return MachineScreen.present(MachineScreen.new(), player, false)


## The screen gone at once (close only queues it; a next machine needs its name free).
static func _gone(screen: Node) -> void:
	if is_instance_valid(screen):
		screen.free()


static func _texts(box: Node) -> Array:
	var texts := []
	for child in box.get_children():
		if child is Label and not child.is_queued_for_deletion():
			texts.append((child as Label).text)
	return texts


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func test_close_up_takes_its_share_of_the_view(test) -> void:
	var focus := Rect2(-0.25, 1.0, 0.5, 0.32)
	var close: Array = MachineScreen.close_up_of(focus, 0.6)
	var camera_at: Vector3 = close[0]
	var look: Vector3 = close[1]
	var distance := camera_at.z - look.z
	var view_height := 2.0 * distance * tan(deg_to_rad(MachineScreen.CAMERA_FOV * 0.5))
	test.check(is_equal_approx(focus.size.y / view_height, 0.6), "het deel neemt 60%% van de hoogte (%.3f)" % (focus.size.y / view_height))
	test.check(is_equal_approx(look.y, focus.get_center().y) and is_equal_approx(camera_at.y, look.y) and is_equal_approx(camera_at.x, look.x),
		"de camera recht voor het midden in de hoogte")
	test.check(look.x < focus.get_center().x, "het midden rechts van het midden van het venster: de camera kijkt er links van")
	var metres_per_pixel := view_height / MachineScreen.DESIGN_SIZE.y
	test.check(is_equal_approx((focus.get_center().x - look.x) / metres_per_pixel, MachineScreen.FOCUS_CENTRE_X - MachineScreen.DESIGN_SIZE.x * 0.5),
		"zijn midden op FOCUS_CENTRE_X in het venster")
	var wide: Array = MachineScreen.close_up_of(Rect2(-1.0, 1.0, 2.0, 0.1), 0.6)
	var wide_distance: float = (wide[0] as Vector3).z - (wide[1] as Vector3).z
	var wide_view_width := 2.0 * wide_distance * tan(deg_to_rad(MachineScreen.CAMERA_FOV * 0.5)) * MachineScreen.DESIGN_SIZE.x / MachineScreen.DESIGN_SIZE.y
	test.check(is_equal_approx(2.0 / wide_view_width, MachineScreen.FOCUS_WIDTH_SHARE), "een breed deel: hooguit FOCUS_WIDTH_SHARE van de breedte")
	test.check((MachineScreen.close_up_of(focus, 0.3)[0] as Vector3).z > camera_at.z, "een kleiner aandeel: verder weg")


func test_nearest_target_goes_the_way_asked(test) -> void:
	var targets: Array[Dictionary] = [
		{"hotspot": "midden", "at": Vector2(0.0, 1.0)},
		{"hotspot": "boven", "at": Vector2(0.0, 1.4)},
		{"hotspot": "ver_boven", "at": Vector2(0.0, 1.9)},
		{"hotspot": "rechts", "at": Vector2(0.3, 1.0)},
		{"hotspot": "schuin", "at": Vector2(0.3, 1.2)},
		{"hotspot": "onder", "at": Vector2(0.05, 0.5)},
	]
	var from := Vector2(0.0, 1.0)
	test.check(MachineScreen.nearest_target(targets, from, Vector2.UP).hotspot == "boven", "omhoog: de dichtstbijzijnde erboven (y loopt omhoog)")
	test.check(MachineScreen.nearest_target(targets, from, Vector2.DOWN).hotspot == "onder", "omlaag: eronder")
	test.check(MachineScreen.nearest_target(targets, from, Vector2.RIGHT).hotspot == "rechts", "rechts: rechtdoor telt zwaarder dan schuin")
	test.check(MachineScreen.nearest_target(targets, from, Vector2.LEFT).is_empty(), "links is er niets")
	test.check(MachineScreen.nearest_target(targets, Vector2(0.0, 1.9), Vector2.UP).is_empty(), "bovenaan omhoog: niets (geen rondje)")
	var none: Array[Dictionary] = []
	test.check(MachineScreen.nearest_target(none, from, Vector2.UP).is_empty(), "zonder doelen: niets")


func test_bulged_uv_keeps_the_middle_and_pushes_the_edges_out(test) -> void:
	test.check(MachineScreen.bulged_uv(Vector2(0.5, 0.5), 0.2).is_equal_approx(Vector2(0.5, 0.5)), "het midden blijft")
	test.check(MachineScreen.bulged_uv(Vector2(0.3, 0.8), 0.0).is_equal_approx(Vector2(0.3, 0.8)), "vlak glas: niets verandert")
	test.check(MachineScreen.bulged_uv(Vector2(1.0, 0.5), 0.2).is_equal_approx(Vector2(1.0, 0.5)), "midden op een rand: blijft op de rand")
	var corner := MachineScreen.bulged_uv(Vector2(1.0, 1.0), 0.2)
	test.check(corner.x > 1.0 and corner.y > 1.0, "een hoek valt buiten het beeld (%s)" % corner)
	var near_corner := MachineScreen.bulged_uv(Vector2(0.9, 0.9), 0.2)
	test.check(near_corner.x > 0.9 and near_corner.y > 0.9, "bij de hoek schuift het naar buiten")
	var mirrored := MachineScreen.bulged_uv(Vector2(0.1, 0.1), 0.2)
	test.check(is_equal_approx(mirrored.x, 1.0 - near_corner.x) and is_equal_approx(mirrored.y, 1.0 - near_corner.y), "gespiegeld aan de andere kant")


func test_fit_transform_scales_and_centres_the_design(test) -> void:
	var same := MachineScreen.fit_transform(MachineScreen.DESIGN_SIZE)
	test.check(same.get_scale().is_equal_approx(Vector2.ONE) and same.origin.is_equal_approx(Vector2.ZERO), "het ontwerp zelf: 1 op 1")
	var double := MachineScreen.fit_transform(MachineScreen.DESIGN_SIZE * 2.0)
	test.check(double.get_scale().is_equal_approx(Vector2(2, 2)) and double.origin.is_equal_approx(Vector2.ZERO), "twee keer zo groot: schaal 2")
	var wide := MachineScreen.fit_transform(Vector2(2560, 720))
	test.check(wide.get_scale().is_equal_approx(Vector2.ONE) and wide.origin.is_equal_approx(Vector2(640, 0)), "een breed venster: gecentreerd, balken links en rechts")
	var tall := MachineScreen.fit_transform(Vector2(640, 720))
	test.check(tall.get_scale().is_equal_approx(Vector2(0.5, 0.5)) and tall.origin.is_equal_approx(Vector2(0, 180)), "een smal venster: kleiner, balken boven en onder")


func test_present_needs_a_player_in_the_tree_and_shows_only_one(test) -> void:
	var loose := TestPlayer.new()
	var unshown := MachineScreen.new()
	test.check(MachineScreen.present(unshown, null, false) == null, "zonder speler: niets")
	test.check(MachineScreen.present(unshown, loose, false) == null, "een speler buiten de boom: niets")
	unshown.free()
	loose.free()
	var player := _player()
	var was_paused := tree.paused
	var screen := _present(player)
	test.check(screen != null and screen.visible and tree.paused, "de automaat staat er, het spel staat stil")
	test.check(screen.name == MachineScreen.NODE_NAME and screen.get_parent() == tree.root, "onder de root, met zijn vaste naam")
	test.check(screen.player == player and not screen.animate and screen._crt_layer.visible, "met de speler, zonder animatie, de CRT erover")
	var second := MachineScreen.new()
	test.check(MachineScreen.present(second, player, false) == null and not second.is_inside_tree(), "een tweede automaat tegelijk: niet")
	second.free()
	screen.close()
	test.check(tree.paused == was_paused, "dicht: de pauze terug")
	_gone(screen)
	tree.paused = was_paused
	player.free()


func test_the_stage_and_the_default_parts(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen := _present(player)
	var parts: Dictionary = screen.machine_parts()
	test.check(parts.mesh is BoxMesh and parts.screen is Rect2 and parts.keys is Vector3 and parts.slot is Vector3, "zonder model: een doos met scherm, toetsen en gleuf")
	test.check(is_equal_approx(float(parts.front), (parts.mesh as BoxMesh).size.z * 0.5), "de voorkant op de helft van de diepte")
	var stage: Dictionary = screen.stage_parts()
	test.check(stage.machine != null and stage.camera != null and stage.display != null and stage.stand_in != null, "de scène: automaat, camera, schermbeeld, jij")
	test.check(not (stage.stand_in as Node3D).visible, "zonder animatie staat de camera al dichtbij: jij uit beeld")
	test.check((stage.came_out as Array).is_empty(), "er is nog niets uitgekomen")
	var close: Array = MachineScreen.close_up_of(parts.screen, MachineScreen.FOCUS_SHARE)
	test.check((stage.camera as Camera3D).position.is_equal_approx(close[0]), "de camera op de close-up van het scherm")
	test.check(screen.cursor_targets().is_empty() and screen.cursor_label() == "", "geen knoppen of onderdelen: geen cursor")
	screen.move_cursor(Vector2.DOWN)
	screen.use_cursor()
	test.check(screen.cursor_label() == "", "bewegen en gebruiken doen dan niets")
	screen.close()
	_gone(screen)
	tree.paused = was_paused
	player.free()


func test_display_tray_and_pockets(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen := _present(player)
	screen.screen_colour = Color("#5FE0FF")
	screen.show_display("WELKOM", ["Regel een", "Regel twee"])
	test.check(screen._display_title.text == "WELKOM" and screen._display_text.text == "Regel een\nRegel twee", "titel en regels op het scherm")
	test.check(screen._display_title.get_theme_color("font_color") == Color("#5FE0FF"), "in de kleur van het scherm")
	screen.show_display("FOUT", [], MachineScreen.WARNING)
	test.check(screen._display_title.get_theme_color("font_color") == MachineScreen.WARNING and screen._display_text.text == "", "of in een eigen kleur, zonder regels")
	test.check(not screen._tray_section.visible and not screen._info_rule.visible, "het bakje is leeg: niet te zien")
	screen.show_tray("BON", ["2 × BLIKJE", "TOTAAL"], MachineScreen.GOOD)
	test.check(screen._tray_section.visible and screen._info_rule.visible and screen._tray_title.text == "BON", "er komt iets uit: het bakje met zijn titel")
	test.check(_texts(screen._tray) == ["BON", "2 × BLIKJE", "TOTAAL"], "en de regels (%s)" % [_texts(screen._tray)])
	test.check((screen.stage_parts().came_out as Array).size() == 1, "in de scène schuift er iets uit de gleuf")
	var slip := (screen.stage_parts().came_out as Array)[0] as Node3D
	var slot: Vector3 = screen.machine_parts().slot
	test.check(is_equal_approx(slip.position.z, slot.z + MachineScreen.SLIDE_OUT), "zonder animatie meteen uitgeschoven")
	screen.show_tray("GELD", ["€ 20,00"])
	test.check(_texts(screen._tray) == ["GELD", "€ 20,00"] and (screen.stage_parts().came_out as Array).size() == 1, "iets nieuws vervangt het vorige")
	screen.clear_tray()
	test.check(not screen._tray_section.visible and (screen.stage_parts().came_out as Array).is_empty(), "leeggemaakt: weg")
	test.check(screen.pocket_lines() == [["GELD  € 12,50", UiStyle.TEXT]], "je zakken: je geld (%s)" % [screen.pocket_lines()])
	player.money = 3.0
	screen.refresh_pockets()
	test.check(_texts(screen._pockets) == ["Je zakken", "GELD  € 3,00"], "bijgewerkt in het paneel (%s)" % [_texts(screen._pockets)])
	test.check(screen.key_hints() == "[ESC] WEG" and screen.pad_hints().contains("[B] WEG"), "de toetsen onderaan")
	test.check(screen._keys_label.text == (screen.key_hints() if Input.get_connected_joypads().is_empty() else screen.pad_hints()), "staan in beeld")
	screen.close()
	_gone(screen)
	tree.paused = was_paused
	player.free()


func test_labels_and_buttons(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen := _present(player)
	var listener := Listener.new()
	var made: Label = screen.label("Hallo", screen.font_body, 14, UiStyle.MUTED)
	test.check(made.text == "Hallo" and made.get_theme_font_size("font_size") == 14 and made.get_theme_color("font_color") == UiStyle.MUTED, "een label: tekst, grootte, kleur")
	test.check(made.mouse_filter == Control.MOUSE_FILTER_IGNORE and made.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "vangt geen muis, breekt af op woorden")
	var button: Button = screen.button("OK", listener.on_press, 92.0, Color("#2E9A48"))
	test.check(button.text == "OK" and button.custom_minimum_size == Vector2(92, 40) and button.focus_mode == Control.FOCUS_NONE, "een knop: tekst en maat")
	test.check((button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Color("#2E9A48"), "in zijn eigen kleur")
	test.check((button.get_theme_stylebox("hover") as StyleBoxFlat).border_color == screen.trim_colour, "onder de muis: de rand in de kleur van de automaat")
	var plain: Button = screen.button("1", listener.on_press)
	test.check((plain.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == (screen.body_colour as Color).darkened(0.35), "zonder kleur: die van de kast, donkerder")
	button.pressed.emit()
	test.check(listener.presses == 1, "een klik doet zijn actie")
	test.check(screen._press_light.light_energy == 0.0, "het lampje van de toetsen is (zonder animatie) meteen weer uit")
	screen._busy = true
	button.pressed.emit()
	test.check(listener.presses == 1, "terwijl de automaat bezig is: niets")
	screen._busy = false
	screen.close()
	button.pressed.emit()
	test.check(listener.presses == 1, "terwijl hij sluit: ook niets")
	made.free()
	button.free()
	plain.free()
	_gone(screen)
	tree.paused = was_paused
	player.free()


func test_escape_leaves_once_and_finished_fires(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen := _present(player)
	var listener := Listener.new()
	screen.finished.connect(listener.on_finished)
	test.check(not screen.is_closing(), "eerst open")
	test.check(not screen._key(KEY_1), "een gewone automaat gebruikt geen toetsen")
	screen._input(_key(KEY_1))
	test.check(not screen.is_closing(), "een andere toets: hij blijft staan")
	var released := _key(KEY_ESCAPE)
	released.pressed = false
	screen._input(released)
	test.check(not screen.is_closing(), "Escape loslaten doet niets")
	screen._input(_key(KEY_ESCAPE))
	test.check(screen.is_closing() and not screen.visible and listener.finished_calls == 1, "Escape: weg, finished")
	test.check(tree.paused == was_paused and screen.is_queued_for_deletion() and not screen._crt_layer.visible, "het spel gaat door, het scherm ruimt zichzelf op")
	screen.close()
	screen.cancel()
	screen._input(_key(KEY_ESCAPE))
	test.check(listener.finished_calls == 1, "nog een keer sluiten: maar een keer finished")
	_gone(screen)
	tree.paused = was_paused
	player.free()


func test_the_hooks_of_a_plain_machine_do_nothing(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen := _present(player)
	var box := VBoxContainer.new()
	screen.build_controls(box)
	screen.hotspot_pressed("gat")
	screen.press_feedback()
	screen.pause_for(5.0)
	screen.sound("toets")
	test.check(box.get_child_count() == 0 and not screen._controls.visible, "geen knoppen op het scherm")
	test.check(screen.visible and not screen.is_closing(), "een onderdeel, het lampje, wachten en een geluid: hij staat er nog")
	test.check(screen._money() == 12.5 and screen._inventory() == {}, "het geld en de zakken van de speler")
	screen.player = null
	test.check(screen._money() == 0.0 and screen._inventory() == {}, "zonder speler: niets")
	box.free()
	screen.close()
	_gone(screen)
	tree.paused = was_paused
	player.free()
