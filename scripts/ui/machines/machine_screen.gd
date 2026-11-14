extends CanvasLayer
## The close-up of a machine, a 3D scene of its own (as the lift ride): the swipe, and you see
## yourself (a stand-in of your character) standing at the machine, its voxel model against
## a wall over the pavement or the floor of the shop (`backdrop`), the camera over your
## shoulder sliding in close as it opens, the plain light of the portraits and the glow of
## its screen. On that screen what the machine says (show_display: a title and lines, as on
## a little CRT) and, on a machine with a touch screen, its buttons beside them: you click
## them on the screen itself (the click is carried from the 3D screen into its picture).
## Parts of the machine itself can be clicked too (the view's machine_parts "hotspots": the
## hole of the deposit machine, its BON key; hotspot_pressed). A key pressed lights up at
## its keypad (press_feedback); what comes out (the bon, the money, the card: show_tray)
## slides out of its slot as a little thing of its own, and is listed in the one small panel
## bottom left, under it what you carry (pocket_lines); the keys along the bottom. The game
## is paused meanwhile (the scene keeps moving). Esc leaves (cancel), then the swipe back and
## `finished`.
## Without a mouse (a controller, the Steam Deck): a cursor over everything you can use, the
## buttons on its screen and its parts (hotspots): the arrows, WASD, the D-pad or the left stick
## move it to the nearest one that way (in the plane of the machine's front), A (ui_accept,
## also Enter and Space once the cursor shows) uses it, B (ui_cancel) leaves. The button under
## it gets its hover look, a part a frame round it. The mouse hides it again.
## This is the behaviour layer: up and gone (the pause, the swipe), the keys, the mouse and
## the cursor, the choices of a touch screen (set_options), what the machine is busy with.
## machine_screen_rules.gd has the logic (the texts, where the cursor goes, where the mouse
## is on the machine), machine_screen_layout.gd the sizes, machine_screen_view.gd builds the
## scene, the screen and the panel and shows what it is handed (`view`).
## The machines extend this script, each with a view that extends the view:
## DepositMachineScreen (statiegeld, the supermarkets), OvMachineScreen (OV-chipkaart, Den
## Haag Centraal and tram stops), CashMachineScreen (the cash machines in the town); their
## sounds are MachineSounds.
##   CashMachineScreen.show_for(player)       # each has its own show_for
## `animate` false (the checks): no swipe, no waiting, the steps at once.

signal finished

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const PadInput = preload("res://scripts/ui/pad_input.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const MachineSounds = preload("res://scripts/ui/machines/machine_sounds.gd")
const MachineScreenRules = preload("res://scripts/ui/machines/machine_screen_rules.gd")
const MachineScreenLayout = preload("res://scripts/ui/machines/machine_screen_layout.gd")
const MachineScreenView = preload("res://scripts/ui/machines/machine_screen_view.gd")

const NODE_NAME := "Automaatscherm"
const LAYER := MachineScreenLayout.LAYER
## The tones of what the machine says (the view has their colours).
const WARNING := MachineScreenRules.TONE_WARNING
const GOOD := MachineScreenRules.TONE_GOOD
## How much softer the key sound of the cursor moving is (dB).
const CURSOR_SOUND_SOFTER := -6.0

## The name on the machine (set by the machine before it is shown).
var brand := "AUTOMAAT"
var place_name := ""
var player: Node
var animate := true
## The wall and ground behind it (MachineScreenRules.BACKDROP_TILES): the street, a
## supermarket, the station.
var backdrop := MachineScreenRules.DEFAULT_BACKDROP
## How it looks (machine_screen_view.gd, or the machine's own view that extends it: a machine
## makes it in its _init; a plain machine gets the plain view when it comes into the tree).
var view: MachineScreenView
## The machine is doing something that takes a while: keys and clicks wait.
var busy := false

var _was_paused := false
var _closing := false
## The cursor (see the top): what it is on ({"button": Button} or {"hotspot": name}; empty =
## not shown) and its spot in the plane of the machine's front (metres) to find the next one from.
var _cursor := {}
var _cursor_at := Vector2.ZERO
## What the choices of the touch screen do now, top to bottom (set_options).
var _option_actions: Array[Callable] = []


## Puts `screen` (a machine, set up) up for `player`: the swipe, then the machine. Nothing
## if a machine is up already. The screen is returned (null if not shown).
static func present(screen: CanvasLayer, for_player: Node, with_animation := true) -> CanvasLayer:
	if for_player == null or not for_player.is_inside_tree():
		return null
	var tree := for_player.get_tree()
	if tree.root.has_node(NODE_NAME):
		return null
	screen.set("player", for_player)
	screen.set("animate", with_animation)
	screen.name = NODE_NAME
	tree.root.add_child(screen)
	screen.call("_begin")
	return screen


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	if view == null:
		view = MachineScreenView.new()
	view.animate = animate
	add_child(view)
	view.build(MachineScreenRules.known_backdrop(backdrop), MachineScreenRules.backdrop_tiles(backdrop, place_name),
		MachineScreenRules.tray_heading(place_name), _stand_in())
	view.button_used.connect(_on_button_used)
	view.option_pressed.connect(choose_option)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _begin() -> void:
	var swipe: Node = SwipeTransition.swipe(get_tree()) if animate else null
	if swipe:
		await swipe.covered
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	view.show_open(true)
	view.play_camera_in()
	_opened()
	refresh_pockets()


## Leaves the machine: the swipe, the game going on, `finished`.
func close() -> void:
	if _closing:
		return
	_closing = true
	UiSounds.play(self, "terug")
	var swipe: Node = SwipeTransition.swipe(get_tree()) if animate else null
	if swipe:
		await swipe.covered
	visible = false
	view.show_open(false)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().paused = _was_paused
	finished.emit()
	queue_free()


func is_closing() -> bool:
	return _closing


# ------------------------------------------------------------------ for the machines

## Called when the machine is up (show the first display).
func _opened() -> void:
	pass


## The model of the machine and where its parts are on it (the view's machine_parts, as built).
func machine_parts() -> Dictionary:
	return view.parts() if view else {}


## A key of the machine pressed: the light at its keypad shines a moment.
func press_feedback() -> void:
	view.show_press()


## A part of the machine clicked (machine_parts "hotspots": its "name").
func hotspot_pressed(_hotspot: String) -> void:
	pass


## A key pressed (physical keycode); true if the machine used it. Esc is cancel.
func _key(_keycode: Key) -> bool:
	return false


## Esc: leave (a machine may first give back a card or print a bon).
func cancel() -> void:
	close()


## What the panel bottom left lists of your pockets: [text, tone] each.
func pocket_lines() -> Array:
	return MachineScreenRules.pocket_lines(_money())


## The key hints along the bottom.
func key_hints() -> String:
	return MachineScreenRules.KEY_HINTS


## The hints along the bottom with a controller connected (the cursor: see the top).
func pad_hints() -> String:
	return MachineScreenRules.PAD_HINTS


## What the machine says on its screen: a title and lines, in `tone` (none: its own colour).
func show_display(title: String, lines: Array, tone := MachineScreenRules.TONE_SCREEN) -> void:
	view.show_display(title, MachineScreenRules.display_text(lines), tone)


## What came out of the machine, in the tray on the left: a title and lines in `tone`; and in
## the scene it slides out of the slot (nothing when the title is empty).
func show_tray(title: String, lines: Array, tone := MachineScreenRules.TONE_TEXT) -> void:
	view.show_tray(title, lines, tone, MachineScreenRules.tray_shows(title, lines), MachineScreenRules.slip_shows(title))


func clear_tray() -> void:
	show_tray("", [])


func refresh_pockets() -> void:
	view.show_pockets(MachineScreenRules.POCKETS_HEADING, pocket_lines())
	view.show_hints(MachineScreenRules.hints(not Input.get_connected_joypads().is_empty(), key_hints(), pad_hints()))


## Waits `seconds` (not in the checks).
func pause_for(seconds: float) -> void:
	if animate and is_inside_tree():
		await get_tree().create_timer(seconds, true).timeout


func sound(sound_name: String, softer_db := 0.0) -> void:
	MachineSounds.play(self, sound_name, softer_db)


## The choices of the touch screen (the view's option buttons), top to bottom: [text, what
## it does (a Callable)] each; the buttons without a choice are hidden.
func set_options(choices: Array) -> void:
	var texts: Array = []
	_option_actions.clear()
	for choice: Array in choices:
		texts.append(String(choice[0]))
		_option_actions.append(choice[1])
	view.show_options(texts)


## Choice `index` of the touch screen used (its button, or its key): the key sound and what it does.
func choose_option(index: int) -> void:
	if MachineScreenRules.option_usable(index, _option_actions.size(), view.option_buttons().size()):
		sound("toets")
		_option_actions[index].call()


## What the choices say now, top to bottom (for the checks).
func option_texts() -> Array:
	var texts: Array = []
	for option in view.option_buttons():
		if option.visible:
			texts.append(option.text)
	return texts


## The scene (for the checks): the machine's model, the stand-in, what came out, the camera,
## the picture of the screen.
func stage_parts() -> Dictionary:
	return view.stage_parts()


## The title and the text on the machine's screen now.
func display_title() -> String:
	return view.display().title_text()


func display_text() -> String:
	return view.display().body_text()


func _money() -> float:
	return float(player.get("money")) if player and player.get("money") != null else 0.0


func _inventory() -> Dictionary:
	return player.get("inventory") if player and player.get("inventory") != null else {}


## You as you stand at the machine: your character, as big as you are, with or without coat.
func _stand_in() -> Dictionary:
	return {"archetype_id": PlayerCharacter.current_id(),
		"figure_scale": float(player.get("FIGURE_SCALE")) if player and player.get("FIGURE_SCALE") != null else MachineScreenRules.STAND_IN_SCALE,
		"coat": player.wears_coat() if player and player.has_method("wears_coat") else MachineScreenRules.STAND_IN_COAT}


## A button of the screen clicked: the light and what it does, unless the machine is busy.
func _on_button_used(action: Callable) -> void:
	if not busy and not _closing:
		press_feedback()
		action.call()


func _fit() -> void:
	transform = MachineScreenLayout.fit_transform(get_viewport().get_visible_rect().size)


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event is InputEventMouse:
		if event is InputEventMouseMotion and not _cursor.is_empty():
			_show_cursor({})   # the mouse takes over
		_mouse(event as InputEventMouse)
		return
	if _cursor_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo or busy:
			return
		if key_event.physical_keycode == KEY_ESCAPE:
			cancel()
		elif _key(key_event.physical_keycode):
			press_feedback()


## The cursor's share of the input (see the top): true when it used `event`.
func _cursor_input(event: InputEvent) -> bool:
	var direction := PadInput.direction(event)
	if direction != Vector2.ZERO:
		if not busy:
			move_cursor(direction)
		return true
	var from_pad := PadInput.is_pad(event)
	if PadInput.is_accept(event) and (from_pad or not _cursor.is_empty()):
		if not busy:
			use_cursor()
		return true
	if from_pad and PadInput.is_back(event):
		if not busy:
			cancel()
		return true
	return false


## The mouse over the machine: on its screen the event goes into the screen's picture (its
## buttons), on a part (hotspots) a click uses it; the hand over both.
func _mouse(event: InputEventMouse) -> void:
	var design := transform.affine_inverse() * event.position
	var on_screen := _screen_point(design)
	var hotspot := _hotspot_at(design)
	var has_controls := view.display().has_controls()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if MachineScreenRules.shows_hand(on_screen.x >= 0.0, has_controls, hotspot) else Input.CURSOR_ARROW)
	if on_screen.x >= 0.0 and has_controls:
		view.display().push_mouse(event, on_screen)
		get_viewport().set_input_as_handled()
	elif hotspot != "" and event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		get_viewport().set_input_as_handled()
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not busy:
			press_feedback()
			hotspot_pressed(hotspot)


## Where the ray of the camera through `design` (a point of the window, in design pixels)
## meets the plane at `z` (the scene's metres), in the space of the machine's model; null
## when it does not.
func _on_machine(design: Vector2, z: float) -> Variant:
	var way := view.stage().ray_way(design)
	if way == Vector3.ZERO:
		return null
	var hit: Variant = MachineScreenRules.ray_to_plane(view.stage().ray_origin(design), way, z)
	return null if hit == null else (hit as Vector3) - view.stage().model_origin()


## The pixel of the screen's picture under `design` (a point of the window), the bulge of
## its glass taken into account; (-1, -1) when it is not on it.
func _screen_point(design: Vector2) -> Vector2:
	var local: Variant = _on_machine(design, view.stage().display_z())
	if local == null:
		return MachineScreenRules.OFF_PICTURE
	return MachineScreenRules.picture_point(local, view.screen_rect(), view.stage().curvature(), Vector2(view.display().size))


## The name of the part of the machine (machine_parts "hotspots") under `design`, or "".
func _hotspot_at(design: Vector2) -> String:
	if view.hotspots().is_empty():
		return ""
	var local: Variant = _on_machine(design, view.stage().model_origin().z + view.front())
	if local == null:
		return ""
	return MachineScreenRules.hotspot_at(view.hotspots(), Vector2((local as Vector3).x, (local as Vector3).y))


# ------------------------------------------------------------------ the cursor

## What the cursor can be on now: every button on the screen that shows and can be pressed,
## and every part (hotspot); each with its spot in the plane of the machine's front (metres,
## y up), to go from one to the next.
func cursor_targets() -> Array[Dictionary]:
	return MachineScreenRules.cursor_targets(view.display().button_spots(), view.hotspots(), view.screen_rect())


## The cursor to the nearest target that way (`direction` as on the screen: Vector2.DOWN is
## down); the first time onto the first one (the top button, else the first part).
func move_cursor(direction: Vector2) -> void:
	var targets := cursor_targets()
	if targets.is_empty():
		return
	if not _cursor_is_valid(targets):
		_show_cursor(targets[0])
		return
	var best := MachineScreenRules.nearest_target(targets, _cursor_at, direction)
	if not best.is_empty():
		_show_cursor(best)
		sound("toets", CURSOR_SOUND_SOFTER)


## Uses what the cursor is on: the button pressed, or the part (as a click on it).
func use_cursor() -> void:
	var targets := cursor_targets()
	if not _cursor_is_valid(targets):
		move_cursor(Vector2.DOWN)
		return
	if _cursor.has("button"):
		(_cursor.button as Button).pressed.emit()
	elif _cursor.has("hotspot"):
		press_feedback()
		hotspot_pressed(String(_cursor.hotspot))


## What the cursor is on (for the checks): the button's text or the part's name, "" when hidden.
func cursor_label() -> String:
	if _cursor.has("button") and is_instance_valid(_cursor.button):
		return (_cursor.button as Button).text
	return String(_cursor.get("hotspot", ""))


## Whether the cursor is still on one of `targets`; its spot is that target's, then.
func _cursor_is_valid(targets: Array[Dictionary]) -> bool:
	var found := MachineScreenRules.matching_target(targets, _cursor)
	if found.is_empty():
		return false
	_cursor_at = found.at
	return true


## Shows the cursor on `target` (empty: hidden): a button gets its hover look, a part the frame.
func _show_cursor(target: Dictionary) -> void:
	_cursor = target
	view.hide_cursor()
	if target.is_empty():
		return
	_cursor_at = target.at
	if target.has("button"):
		view.show_cursor_on_button(target.button as Button)
	else:
		_frame_hotspot(String(target.hotspot))


## The frame round the part `hotspot_name`, where it is in the window now.
func _frame_hotspot(hotspot_name: String) -> void:
	var rect: Variant = MachineScreenRules.hotspot_rect(view.hotspots(), hotspot_name)
	if rect != null:
		view.show_cursor_on_part(rect)


func _process(_delta: float) -> void:
	# the buttons change (another page of choices): the cursor stays on what is still there,
	# else goes to the nearest; a part's frame follows the camera sliding in
	if _cursor.is_empty() or not visible:
		return
	var targets := cursor_targets()
	if targets.is_empty():
		_show_cursor({})
	elif not _cursor_is_valid(targets):
		_show_cursor(MachineScreenRules.closest_target(targets, _cursor_at))
	elif _cursor.has("hotspot"):
		_frame_hotspot(String(_cursor.hotspot))
