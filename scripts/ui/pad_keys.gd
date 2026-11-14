extends Node
## The controller (a Steam Deck, any gamepad) for the whole game: its buttons become the keys
## the screens already know, so every screen works with it. An autoload ("Controller").
## What a button means depends on where you are (menu_context):
## - in a menu (the game paused: the game menu, the story box, a reward, the shop, the pause
##   menu; or outside the town: the intro, the main menu, the character choice):
##     D-pad / left stick  arrows      A  Enter      B  Escape      X  X (drop an item)
##     LB / RB             Q / E (tabs)               Start  Escape  Back  Tab
## - in the town:
##     D-pad  arrows (walking; the left stick walks itself: PlayerController reads it, move_vector)
##     A  E (talk, go in)   B  Space (jump)   Y  F (eat)   X  E too
##     right trigger or L3  Shift (run)       Start  Escape (pause)   Back  Tab (game menu)
##     right stick left / right  Z / X (turn the view, when it is turned by hand: CameraTurning)
##     right stick pressed (R3)  C (the view back to the usual one)
##     right stick up / down     + / - (zoom in / out, when the view is turned by hand)
## A key made from a button carries the meta FROM_PAD, so a screen can tell (PadInput.is_pad).
## What handles the controller itself (the machines' cursor: machine_screen.gd) takes the
## button first, and then nothing is made of it here. Godot's own ui_* actions lose their
## controller buttons at the start (_ready), so a button is never taken twice (by an ui_*
## action and as the key made of it).
## `last_was_pad` (static): whether the last input came from a controller, for the hints
## (ActionPrompts shows A instead of E: PadInput.label).

const FROM_PAD := &"van_controller"
## How far the stick or a trigger must go to count as pressed, and back to count as let go.
const PRESS_AT := 0.55
const LET_GO_AT := 0.35
## The left stick in the town: below this it stands still.
const STICK_DEAD_ZONE := 0.22

const MENU_BUTTONS := {
	JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE, JOY_BUTTON_X: KEY_X,
	JOY_BUTTON_LEFT_SHOULDER: KEY_Q, JOY_BUTTON_RIGHT_SHOULDER: KEY_E,
	JOY_BUTTON_START: KEY_ESCAPE, JOY_BUTTON_BACK: KEY_TAB,
	JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
	JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
}
const TOWN_BUTTONS := {
	JOY_BUTTON_A: KEY_E, JOY_BUTTON_X: KEY_E, JOY_BUTTON_B: KEY_SPACE, JOY_BUTTON_Y: KEY_F,
	JOY_BUTTON_LEFT_STICK: KEY_SHIFT, JOY_BUTTON_RIGHT_STICK: KEY_C, JOY_BUTTON_START: KEY_ESCAPE, JOY_BUTTON_BACK: KEY_TAB,
	JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
	JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
}
## The ui_* actions whose controller buttons are taken out (they come as keys from here).
const UI_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "ui_select",
	"ui_focus_next", "ui_focus_prev", "ui_page_up", "ui_page_down"]

static var last_was_pad := false

var _held := {}          # button or stick direction -> the key made of it, held down now
var _stick_pressed := {} # "x-" / "x+" / "y-" / "y+" -> held (the stick as arrows in a menu)
var _trigger_held := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in UI_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)


## True in a menu (see the top), false in the town.
func menu_context() -> bool:
	var tree := get_tree()
	if tree.paused:
		return true
	var scene := tree.current_scene
	return scene == null or scene.get_node_or_null("Speler") == null


## The left stick as a direction to walk (x right, y down as the arrows), its length 0..1;
## ZERO inside STICK_DEAD_ZONE. Any connected controller.
static func move_vector() -> Vector2:
	var strongest := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if stick.length() > strongest.length():
			strongest = stick
	return stick_move(strongest)


## What a left stick at `stick` (both axes -1..1) asks: ZERO inside STICK_DEAD_ZONE, else its
## direction, at most 1 long (the corners of a stick reach further).
static func stick_move(stick: Vector2) -> Vector2:
	if stick.length() < STICK_DEAD_ZONE:
		return Vector2.ZERO
	return stick.limit_length(1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if not event.has_meta(FROM_PAD):
			last_was_pad = false
		return
	if event is InputEventJoypadButton:
		last_was_pad = true
		_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_motion(event as InputEventJoypadMotion)


func _button(event: InputEventJoypadButton) -> void:
	var button := event.button_index
	if event.pressed:
		var mapping := MENU_BUTTONS if menu_context() else TOWN_BUTTONS
		if not mapping.has(button) or _held.has(button):
			return
		_held[button] = mapping[button]
		_send(mapping[button], true)
	elif _held.has(button):
		_send(_held[button], false)
		_held.erase(button)


func _motion(event: InputEventJoypadMotion) -> void:
	var value := event.axis_value
	if event.axis == JOY_AXIS_TRIGGER_RIGHT:
		if not _trigger_held and value > PRESS_AT and not menu_context():
			_trigger_held = true
			last_was_pad = true
			_send(KEY_SHIFT, true)
		elif _trigger_held and value < LET_GO_AT:
			_trigger_held = false
			_send(KEY_SHIFT, false)
		return
	if event.axis == JOY_AXIS_RIGHT_Y:
		# the right stick up and down zooms (in the town)
		for side: String in ["-", "+"]:
			var direction := "ry" + side
			var pushed := (value < -PRESS_AT) if side == "-" else (value > PRESS_AT)
			var released := (value > -LET_GO_AT) if side == "-" else (value < LET_GO_AT)
			if pushed and not _stick_pressed.get(direction, false) and not menu_context():
				_stick_pressed[direction] = true
				last_was_pad = true
				_send(KEY_EQUAL if side == "-" else KEY_MINUS, true)
			elif released and _stick_pressed.get(direction, false):
				_stick_pressed[direction] = false
				_send(KEY_EQUAL if side == "-" else KEY_MINUS, false)
		return
	if event.axis == JOY_AXIS_RIGHT_X:
		# the right stick turns the view (in the town)
		for side: String in ["-", "+"]:
			var direction := "r" + side
			var pushed := (value < -PRESS_AT) if side == "-" else (value > PRESS_AT)
			var released := (value > -LET_GO_AT) if side == "-" else (value < LET_GO_AT)
			if pushed and not _stick_pressed.get(direction, false) and not menu_context():
				_stick_pressed[direction] = true
				last_was_pad = true
				_send(KEY_Z if side == "-" else KEY_X, true)
			elif released and _stick_pressed.get(direction, false):
				_stick_pressed[direction] = false
				_send(KEY_Z if side == "-" else KEY_X, false)
		return
	if event.axis != JOY_AXIS_LEFT_X and event.axis != JOY_AXIS_LEFT_Y:
		return
	if absf(value) > PRESS_AT:
		last_was_pad = true
	# the stick as arrows only in a menu: in the town it walks by itself (move_vector)
	var axis_name := "x" if event.axis == JOY_AXIS_LEFT_X else "y"
	for side: String in ["-", "+"]:
		var direction := axis_name + side
		var pushed := (value < -PRESS_AT) if side == "-" else (value > PRESS_AT)
		var released := (value > -LET_GO_AT) if side == "-" else (value < LET_GO_AT)
		if pushed and not _stick_pressed.get(direction, false) and menu_context():
			_stick_pressed[direction] = true
			_send(_stick_key(direction), true)
		elif released and _stick_pressed.get(direction, false):
			_stick_pressed[direction] = false
			_send(_stick_key(direction), false)


static func _stick_key(direction: String) -> Key:
	return {"x-": KEY_LEFT, "x+": KEY_RIGHT, "y-": KEY_UP, "y+": KEY_DOWN}[direction]


## The key `keycode` pressed or let go, as from the keyboard (Input knows it held, as a poll of
## is_physical_key_pressed sees), marked FROM_PAD.
func _send(keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = pressed
	key.set_meta(FROM_PAD, true)
	Input.parse_input_event(key)
