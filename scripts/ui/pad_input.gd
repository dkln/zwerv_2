extends RefCounted
## Input that works the same from the keyboard and a controller (a Steam Deck): what a screen
## asks of an event, so every screen can be used without a mouse.
## - direction(event): the arrows, WASD (with_wasd), the D-pad or the left stick (the ui_*
##   actions) as Vector2.UP / DOWN / LEFT / RIGHT (screen directions: y down), ZERO otherwise;
## - is_accept(event): Enter, Space (ui_accept) or A (JOY_BUTTON_A; Godot's ui_accept has no
##   controller button);
## - is_back(event): Escape (ui_cancel) or B;
## - is_pad(event): from a controller.
## Only presses count (no echo, nothing let go).
## - label(key): the name of a key in the hints, as the controller's button when it is used.
##   const PadInput = preload("res://scripts/ui/pad_input.gd")
##   if PadInput.is_accept(event): ...

const WASD := {KEY_W: Vector2.UP, KEY_S: Vector2.DOWN, KEY_A: Vector2.LEFT, KEY_D: Vector2.RIGHT}
const DIRECTIONS := {"ui_up": Vector2.UP, "ui_down": Vector2.DOWN, "ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT}
const PAD_DIRECTIONS := {JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT}
## The name of a key on a controller (pad_keys.gd), for the hints: label("E") is "A" while the
## last input came from a controller.
const PAD_LABELS := {"E": "A", "SPATIE": "B", "F": "Y", "ESC": "START", "TAB": "SELECT", "SHIFT": "RT",
	"ENTER": "A", "Q": "LB", "X": "X"}


static func is_press(event: InputEvent) -> bool:
	return event.is_pressed() and not event.is_echo()


## From a controller: its own event, or a key made of a button (pad_keys.gd, FROM_PAD).
static func is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion or event.has_meta(&"van_controller")


static func direction(event: InputEvent, with_wasd := true) -> Vector2:
	if not is_press(event):
		return Vector2.ZERO
	if event is InputEventJoypadButton:
		return PAD_DIRECTIONS.get((event as InputEventJoypadButton).button_index, Vector2.ZERO)
	for action: String in DIRECTIONS:
		if event.is_action_pressed(action):
			return DIRECTIONS[action]
	if with_wasd and event is InputEventKey and WASD.has((event as InputEventKey).physical_keycode):
		return WASD[(event as InputEventKey).physical_keycode]
	return Vector2.ZERO


static func is_accept(event: InputEvent) -> bool:
	if not is_press(event):
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	return event.is_action_pressed("ui_accept")


static func is_back(event: InputEvent) -> bool:
	if not is_press(event):
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	return event.is_action_pressed("ui_cancel")


static func label(key_name: String) -> String:
	var pad_keys: GDScript = load("res://scripts/ui/pad_keys.gd")
	if not bool(pad_keys.get("last_was_pad")):
		return key_name
	return PAD_LABELS.get(key_name.to_upper(), key_name)
