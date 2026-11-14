extends RefCounted
## Unit tests of what a screen asks of an input event (scripts/ui/pad_input.gd): is_press,
## is_pad, direction, is_accept, is_back, and the names of the keys in the hints (label).
##   tests/run_unit_tests.sh pad_input

const PadInput = preload("res://scripts/ui/pad_input.gd")
const PadKeys = preload("res://scripts/ui/pad_keys.gd")


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


static func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_only_presses_count(test) -> void:
	test.check(PadInput.is_press(_key(KEY_ENTER)), "een toets ingedrukt: ja")
	test.check(not PadInput.is_press(_key(KEY_ENTER, false)), "losgelaten: nee")
	var echo := _key(KEY_ENTER)
	echo.echo = true
	test.check(not PadInput.is_press(echo), "een herhaling van een vastgehouden toets: nee")
	test.check(PadInput.is_press(_button(JOY_BUTTON_A)) and not PadInput.is_press(_button(JOY_BUTTON_A, false)), "ook voor een knop")


func test_is_pad_tells_where_an_event_came_from(test) -> void:
	test.check(PadInput.is_pad(_button(JOY_BUTTON_A)), "een knop: van de controller")
	test.check(PadInput.is_pad(_stick(JOY_AXIS_LEFT_X, 0.8)), "een stick: ook")
	test.check(not PadInput.is_pad(_key(KEY_E)), "een toets van het toetsenbord: niet")
	var made_key := _key(KEY_E)
	made_key.set_meta(PadKeys.FROM_PAD, true)
	test.check(PadInput.is_pad(made_key), "een toets gemaakt van een knop: wel")


func test_direction_of_arrows_wasd_and_the_dpad(test) -> void:
	test.check(PadInput.direction(_action("ui_up")) == Vector2.UP and PadInput.direction(_action("ui_down")) == Vector2.DOWN, "omhoog en omlaag")
	test.check(PadInput.direction(_action("ui_left")) == Vector2.LEFT and PadInput.direction(_action("ui_right")) == Vector2.RIGHT, "links en rechts")
	test.check(PadInput.direction(_key(KEY_UP)) == Vector2.UP and PadInput.direction(_key(KEY_RIGHT)) == Vector2.RIGHT, "de pijltjestoetsen")
	test.check(PadInput.direction(_key(KEY_W)) == Vector2.UP and PadInput.direction(_key(KEY_S)) == Vector2.DOWN
			and PadInput.direction(_key(KEY_A)) == Vector2.LEFT and PadInput.direction(_key(KEY_D)) == Vector2.RIGHT, "WASD")
	test.check(PadInput.direction(_key(KEY_W), false) == Vector2.ZERO, "zonder WASD: de W is geen richting")
	test.check(PadInput.direction(_key(KEY_UP), false) == Vector2.UP, "de pijltjes dan nog wel")
	test.check(PadInput.direction(_button(JOY_BUTTON_DPAD_LEFT)) == Vector2.LEFT and PadInput.direction(_button(JOY_BUTTON_DPAD_DOWN)) == Vector2.DOWN, "het D-pad")
	test.check(PadInput.direction(_button(JOY_BUTTON_A)) == Vector2.ZERO, "een andere knop: geen richting")
	test.check(PadInput.direction(_key(KEY_Q)) == Vector2.ZERO and PadInput.direction(_action("ui_accept")) == Vector2.ZERO, "een andere toets: geen richting")
	test.check(PadInput.direction(_key(KEY_UP, false)) == Vector2.ZERO and PadInput.direction(_button(JOY_BUTTON_DPAD_UP, false)) == Vector2.ZERO, "losgelaten: geen richting")


func test_accept_and_back(test) -> void:
	test.check(PadInput.is_accept(_key(KEY_ENTER)) and PadInput.is_accept(_key(KEY_SPACE)), "Enter en spatie: ja")
	test.check(PadInput.is_accept(_button(JOY_BUTTON_A)) and not PadInput.is_accept(_button(JOY_BUTTON_B)), "A wel, B niet")
	test.check(not PadInput.is_accept(_key(KEY_ESCAPE)) and not PadInput.is_accept(_key(KEY_ENTER, false)), "Escape niet, loslaten niet")
	test.check(PadInput.is_back(_key(KEY_ESCAPE)) and PadInput.is_back(_action("ui_cancel")), "Escape: terug")
	test.check(PadInput.is_back(_button(JOY_BUTTON_B)) and not PadInput.is_back(_button(JOY_BUTTON_A)), "B wel, A niet")
	test.check(not PadInput.is_back(_key(KEY_ENTER)) and not PadInput.is_back(_button(JOY_BUTTON_B, false)), "Enter niet, loslaten niet")


func test_label_names_the_button_while_a_controller_is_used(test) -> void:
	var was_pad: bool = PadKeys.last_was_pad
	PadKeys.last_was_pad = false
	test.check(PadInput.label("E") == "E" and PadInput.label("SPATIE") == "SPATIE", "met het toetsenbord: de toets zelf")
	PadKeys.last_was_pad = true
	test.check(PadInput.label("E") == "A" and PadInput.label("SPATIE") == "B" and PadInput.label("F") == "Y", "met een controller: zijn knop")
	test.check(PadInput.label("ESC") == "START" and PadInput.label("TAB") == "SELECT" and PadInput.label("SHIFT") == "RT", "ook Start, Select en de trekker")
	test.check(PadInput.label("enter") == "A", "hoofdletters doen er niet toe")
	test.check(PadInput.label("F4") == "F4" and PadInput.label("") == "", "een toets zonder knop blijft wat hij is")
	PadKeys.last_was_pad = was_pad
