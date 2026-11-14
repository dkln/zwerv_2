extends RefCounted
## Unit tests of the controller made into keys (scripts/ui/pad_keys.gd): the buttons by where
## you are (menu_context), the sticks and the trigger with their dead zones,
## move_vector/stick_move and `last_was_pad`.
##   tests/run_unit_tests.sh pad_keys

const PadKeys = preload("res://scripts/ui/pad_keys.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


static func _key(keycode: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


static func _button(button: JoyButton, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


static func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


## Whether Input holds `keycode` down now (as a poll of the keyboard sees a key made of a button).
static func _held(keycode: Key) -> bool:
	Input.flush_buffered_events()
	return Input.is_physical_key_pressed(keycode)


## A controller node in the tree (as the autoload "Controller" is in the game).
func _pad_keys() -> PadKeys:
	var pad_keys := PadKeys.new()
	tree.root.add_child(pad_keys)
	return pad_keys


## A town as PadKeys knows it: the current scene with a "Speler" in it.
func _enter_town() -> Node:
	var town := Node.new()
	var player := Node.new()
	player.name = "Speler"
	town.add_child(player)
	tree.root.add_child(town)
	tree.current_scene = town
	return town


func _leave_town(town: Node) -> void:
	tree.current_scene = null
	town.free()


func test_stick_move_has_a_dead_zone_and_a_longest(test) -> void:
	test.check(PadKeys.stick_move(Vector2.ZERO) == Vector2.ZERO, "de stick in rust: niets")
	test.check(PadKeys.stick_move(Vector2(0.15, 0.1)) == Vector2.ZERO, "binnen de dode zone: niets")
	test.check(PadKeys.stick_move(Vector2(PadKeys.STICK_DEAD_ZONE + 0.01, 0.0)) == Vector2(PadKeys.STICK_DEAD_ZONE + 0.01, 0.0), "net buiten de dode zone: de stick zelf")
	test.check(PadKeys.stick_move(Vector2(-0.5, 0.25)) == Vector2(-0.5, 0.25), "half geduwd: half zo hard")
	var corner := PadKeys.stick_move(Vector2(1.0, 1.0))
	test.check(is_equal_approx(corner.length(), 1.0) and is_equal_approx(corner.x, corner.y), "in de hoek: schuin, niet langer dan 1 (%s)" % corner)
	if Input.get_connected_joypads().is_empty():
		test.check(PadKeys.move_vector() == Vector2.ZERO, "zonder controller: move_vector is niets")
	else:
		test.check(PadKeys.move_vector().length() <= 1.0, "move_vector is nooit langer dan 1")


func test_ui_actions_lose_their_controller_buttons(test) -> void:
	var pad_keys := _pad_keys()
	var left := 0
	for action: String in PadKeys.UI_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				left += 1
	test.check(left == 0, "geen knop of stick meer op een ui_*-actie (%d)" % left)
	test.check(InputMap.action_get_events("ui_accept").size() > 0, "de toetsen staan er nog op")
	test.check(pad_keys.process_mode == Node.PROCESS_MODE_ALWAYS, "het werkt ook als het spel stilstaat")
	pad_keys.free()


func test_menu_context(test) -> void:
	var pad_keys := _pad_keys()
	test.check(pad_keys.menu_context(), "buiten de stad (geen scene met een speler): een menu")
	var town := _enter_town()
	test.check(not pad_keys.menu_context(), "in de stad: geen menu")
	tree.paused = true
	test.check(pad_keys.menu_context(), "het spel op pauze: een menu")
	tree.paused = false
	town.get_node("Speler").free()
	test.check(pad_keys.menu_context(), "een scene zonder speler: een menu")
	_leave_town(town)
	pad_keys.free()


func test_last_was_pad_follows_the_last_input(test) -> void:
	var pad_keys := _pad_keys()
	var was_pad: bool = PadKeys.last_was_pad
	pad_keys._input(_button(JOY_BUTTON_Y))
	test.check(PadKeys.last_was_pad, "een knop: de controller")
	pad_keys._input(_button(JOY_BUTTON_Y, false))
	var made_key := _key(KEY_E)
	made_key.set_meta(PadKeys.FROM_PAD, true)
	pad_keys._input(made_key)
	test.check(PadKeys.last_was_pad, "een toets gemaakt van een knop verandert dat niet")
	pad_keys._input(_key(KEY_E))
	test.check(not PadKeys.last_was_pad, "een echte toets: het toetsenbord")
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, 0.3))
	test.check(not PadKeys.last_was_pad, "een stick die nauwelijks beweegt telt niet")
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, 0.9))
	test.check(PadKeys.last_was_pad, "een stick die geduwd wordt wel")
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, 0.0))
	var click := InputEventMouseButton.new()
	click.pressed = true
	pad_keys._input(click)
	test.check(not PadKeys.last_was_pad, "een muisklik: weer het toetsenbord")
	PadKeys.last_was_pad = was_pad
	pad_keys.free()


func test_buttons_become_menu_keys_in_a_menu(test) -> void:
	var pad_keys := _pad_keys()
	var was_pad: bool = PadKeys.last_was_pad
	pad_keys._input(_button(JOY_BUTTON_A))
	test.check(_held(KEY_ENTER), "A: Enter ingedrukt")
	pad_keys._input(_button(JOY_BUTTON_A))
	test.check(pad_keys._held.size() == 1, "nog een keer indrukken zonder loslaten: geen tweede toets")
	pad_keys._input(_button(JOY_BUTTON_A, false))
	test.check(not _held(KEY_ENTER) and pad_keys._held.is_empty(), "losgelaten: Enter ook")
	for pair: Array in [[JOY_BUTTON_B, KEY_ESCAPE], [JOY_BUTTON_START, KEY_ESCAPE], [JOY_BUTTON_BACK, KEY_TAB],
			[JOY_BUTTON_LEFT_SHOULDER, KEY_Q], [JOY_BUTTON_RIGHT_SHOULDER, KEY_E], [JOY_BUTTON_DPAD_DOWN, KEY_DOWN]]:
		pad_keys._input(_button(pair[0]))
		var pressed := _held(pair[1])
		pad_keys._input(_button(pair[0], false))
		test.check(pressed and not _held(pair[1]), "knop %d: toets %s" % [pair[0], OS.get_keycode_string(pair[1])])
	pad_keys._input(_button(JOY_BUTTON_Y))
	test.check(pad_keys._held.is_empty() and not _held(KEY_F), "Y doet niets in een menu")
	pad_keys._input(_button(JOY_BUTTON_Y, false))
	PadKeys.last_was_pad = was_pad
	pad_keys.free()


func test_buttons_become_town_keys_in_the_town(test) -> void:
	var pad_keys := _pad_keys()
	var was_pad: bool = PadKeys.last_was_pad
	var town := _enter_town()
	for pair: Array in [[JOY_BUTTON_A, KEY_E], [JOY_BUTTON_X, KEY_E], [JOY_BUTTON_B, KEY_SPACE], [JOY_BUTTON_Y, KEY_F],
			[JOY_BUTTON_LEFT_STICK, KEY_SHIFT], [JOY_BUTTON_RIGHT_STICK, KEY_C], [JOY_BUTTON_START, KEY_ESCAPE], [JOY_BUTTON_BACK, KEY_TAB]]:
		pad_keys._input(_button(pair[0]))
		var pressed := _held(pair[1])
		pad_keys._input(_button(pair[0], false))
		test.check(pressed and not _held(pair[1]), "knop %d: toets %s" % [pair[0], OS.get_keycode_string(pair[1])])
	pad_keys._input(_button(JOY_BUTTON_LEFT_SHOULDER))
	test.check(pad_keys._held.is_empty(), "LB doet niets in de stad")
	# pressed in the town, let go in a menu (a conversation started): the key made then is let go
	pad_keys._input(_button(JOY_BUTTON_A))
	tree.paused = true
	pad_keys._input(_button(JOY_BUTTON_A, false))
	tree.paused = false
	test.check(not _held(KEY_E) and not _held(KEY_ENTER) and pad_keys._held.is_empty(), "loslaten laat de toets los die bij het indrukken gemaakt is")
	_leave_town(town)
	PadKeys.last_was_pad = was_pad
	pad_keys.free()


func test_the_left_stick_is_the_arrows_in_a_menu_only(test) -> void:
	var pad_keys := _pad_keys()
	var was_pad: bool = PadKeys.last_was_pad
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, -0.9))
	test.check(_held(KEY_LEFT) and not _held(KEY_RIGHT), "naar links geduwd: pijl links")
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, -0.45))
	test.check(_held(KEY_LEFT), "een beetje terug (boven LET_GO_AT): nog steeds")
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, -0.2))
	test.check(not _held(KEY_LEFT), "voorbij LET_GO_AT: losgelaten")
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, 0.5))
	test.check(not _held(KEY_RIGHT), "minder dan PRESS_AT: nog geen pijl")
	pad_keys._input(_stick(JOY_AXIS_LEFT_Y, 0.9))
	test.check(_held(KEY_DOWN), "omlaag geduwd: pijl omlaag")
	pad_keys._input(_stick(JOY_AXIS_LEFT_Y, -0.9))
	test.check(_held(KEY_UP) and not _held(KEY_DOWN), "in één keer naar boven: omlaag los, omhoog ingedrukt")
	pad_keys._input(_stick(JOY_AXIS_LEFT_Y, 0.0))
	test.check(not _held(KEY_UP), "terug in het midden: los")
	var town := _enter_town()
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, 0.9))
	test.check(not _held(KEY_RIGHT), "in de stad maakt de stick geen pijlen (hij loopt zelf)")
	pad_keys._input(_stick(JOY_AXIS_LEFT_X, 0.0))
	_leave_town(town)
	PadKeys.last_was_pad = was_pad
	pad_keys.free()


func test_trigger_and_right_stick_work_in_the_town_only(test) -> void:
	var pad_keys := _pad_keys()
	var was_pad: bool = PadKeys.last_was_pad
	pad_keys._input(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.9))
	pad_keys._input(_stick(JOY_AXIS_RIGHT_X, 0.9))
	pad_keys._input(_stick(JOY_AXIS_RIGHT_Y, 0.9))
	test.check(not _held(KEY_SHIFT) and not _held(KEY_X) and not _held(KEY_MINUS), "in een menu: niets")
	pad_keys._input(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	pad_keys._input(_stick(JOY_AXIS_RIGHT_X, 0.0))
	pad_keys._input(_stick(JOY_AXIS_RIGHT_Y, 0.0))
	var town := _enter_town()
	PadKeys.last_was_pad = false
	pad_keys._input(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.9))
	test.check(_held(KEY_SHIFT) and PadKeys.last_was_pad, "de rechter trekker: Shift (rennen)")
	pad_keys._input(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.45))
	test.check(_held(KEY_SHIFT), "half losgelaten: nog steeds")
	pad_keys._input(_stick(JOY_AXIS_TRIGGER_RIGHT, 0.1))
	test.check(not _held(KEY_SHIFT), "los: Shift ook")
	pad_keys._input(_stick(JOY_AXIS_RIGHT_X, -0.9))
	test.check(_held(KEY_Z) and not _held(KEY_X), "de rechter stick naar links: Z (het beeld draaien)")
	pad_keys._input(_stick(JOY_AXIS_RIGHT_X, 0.9))
	test.check(_held(KEY_X) and not _held(KEY_Z), "naar rechts: X")
	pad_keys._input(_stick(JOY_AXIS_RIGHT_X, 0.0))
	test.check(not _held(KEY_X), "in het midden: los")
	pad_keys._input(_stick(JOY_AXIS_RIGHT_Y, -0.9))
	test.check(_held(KEY_EQUAL) and not _held(KEY_MINUS), "omhoog: + (inzoomen)")
	pad_keys._input(_stick(JOY_AXIS_RIGHT_Y, 0.9))
	test.check(_held(KEY_MINUS) and not _held(KEY_EQUAL), "omlaag: - (uitzoomen)")
	pad_keys._input(_stick(JOY_AXIS_RIGHT_Y, 0.0))
	test.check(not _held(KEY_MINUS), "in het midden: los")
	pad_keys._input(_stick(JOY_AXIS_TRIGGER_LEFT, 0.9))
	test.check(not _held(KEY_SHIFT), "de linker trekker doet niets")
	_leave_town(town)
	PadKeys.last_was_pad = was_pad
	pad_keys.free()
