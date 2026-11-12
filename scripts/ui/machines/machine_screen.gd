extends CanvasLayer
## The close-up of a machine (a scene of its own, as the lift ride and being thrown out): the
## swipe, and the whole screen is the front of the machine, standing against a wall, drawn in
## the pixel look of the HUD (UiStyle: hard panels, the pixel fonts, the CRT over it). In the
## middle the housing in the machine's house colours (`body_colour`, `trim_colour`, its name
## in `brand`) with its display (show_display: a title and lines of text in `screen_colour`
## on dark glass) and under it what the machine has (build_controls: a keypad, buttons, the
## slots); left a panel where things come out (the bon, the money, the card: `tray`); right
## what you carry (pocket_lines) and the keys. The game is paused meanwhile. Esc leaves
## (cancel), then the swipe back and `finished`.
## The machines: DepositMachineScreen (statiegeld, the supermarkets), OvMachineScreen
## (OV-chipkaart, Den Haag Centraal and tram stops), CashMachineScreen (the cash machines in
## the town); their sounds are MachineSounds.
##   CashMachineScreen.show_for(player)       # each has its own show_for
## `animate` false (the checks): no swipe, no waiting, the steps at once.

signal finished

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const MachineSounds = preload("res://scripts/ui/machines/machine_sounds.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")

const NODE_NAME := "Automaatscherm"
const DESIGN_SIZE := Vector2(1280, 720)
const LAYER := 90
const HOUSING_RECT := Rect2(400, 28, 480, 664)
const TRAY_RECT := Rect2(40, 200, 320, 360)
const POCKETS_RECT := Rect2(920, 200, 320, 360)
const WALL := Color("#2A2438")
const PAVEMENT := Color("#4A4652")
const GLASS := Color("#0A1410")
const WARNING := Color("#FF5D73")
const GOOD := Color("#3CE06A")

## The machine's look (set by the machine before it is shown).
var brand := "AUTOMAAT"
var body_colour := Color("#3A4250")
var trim_colour := Color("#F2B705")
var screen_colour := Color("#5FE0FF")
var place_name := ""
var player: Node
var animate := true

var font_title: Font
var font_pixel: Font
var font_body: Font
var _root: Control
var _housing: Panel
var _display_title: Label
var _display_text: Label
var _controls: VBoxContainer
var _tray: VBoxContainer
var _tray_title: Label
var _pockets: VBoxContainer
var _keys_label: Label
var _was_paused := false
var _closing := false
var _busy := false
var _crt_layer: CanvasLayer


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
	var body := UiStyle.font(UiStyle.FONT_BODY)
	font_body = UiStyle.weighted(body, 400)
	font_pixel = UiStyle.font(UiStyle.FONT_PIXEL)
	font_title = UiStyle.weighted(UiStyle.font(UiStyle.FONT_TITLE), 700)
	if body is FontFile:
		var fallbacks: Array[Font] = [body]
		for font: Font in [font_pixel]:
			font.fallbacks = fallbacks
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()


func _begin() -> void:
	var swipe: Node = SwipeTransition.swipe(get_tree()) if animate else null
	if swipe:
		await swipe.covered
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_crt_layer.visible = true
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
	_crt_layer.visible = false
	get_tree().paused = _was_paused
	finished.emit()
	queue_free()


func is_closing() -> bool:
	return _closing


# ------------------------------------------------------------------ for the machines

## Called when the machine is up (show the first display).
func _opened() -> void:
	pass


## The controls of the machine under its display (a keypad, buttons).
func build_controls(_box: VBoxContainer) -> void:
	pass


## A key pressed (physical keycode); true if the machine used it. Esc is cancel.
func _key(_keycode: Key) -> bool:
	return false


## Esc: leave (a machine may first give back a card or print a bon).
func cancel() -> void:
	close()


## What the panel on the right lists: [text, colour].
func pocket_lines() -> Array:
	return [["GELD  € " + _money_text(_money()), UiStyle.TEXT]]


## The key hints along the bottom.
func key_hints() -> String:
	return "[ESC] WEG"


func show_display(title: String, lines: Array, colour := Color(0, 0, 0, 0)) -> void:
	if _display_title == null:
		return
	_display_title.text = title
	_display_text.text = "\n".join(lines)
	var ink := screen_colour if colour.a == 0.0 else colour
	_display_title.add_theme_color_override("font_color", ink)
	_display_text.add_theme_color_override("font_color", ink.lerp(Color.WHITE, 0.15))


## What came out of the machine, in the tray on the left: a title and lines.
func show_tray(title: String, lines: Array, colour := UiStyle.TEXT) -> void:
	for child in _tray.get_children():
		if child != _tray_title:
			child.queue_free()
	_tray_title.text = title
	for line: String in lines:
		_tray.add_child(label(line, font_body, 15, colour))
	if animate:
		_tray.modulate.a = 0.0
		_tray.position.y = -40.0
		var slide := _tray.create_tween().set_parallel()
		slide.tween_property(_tray, "modulate:a", 1.0, 0.35)
		slide.tween_property(_tray, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func clear_tray() -> void:
	show_tray("", [])


func refresh_pockets() -> void:
	if _pockets == null:
		return
	for child in _pockets.get_children():
		child.queue_free()
	_pockets.add_child(label("JE ZAKKEN", font_pixel, 14, UiStyle.ACCENT))
	for line: Array in pocket_lines():
		_pockets.add_child(label(String(line[0]), font_body, 15, line[1]))
	_keys_label.text = key_hints()


## Waits `seconds` (not in the checks).
func pause_for(seconds: float) -> void:
	if animate and is_inside_tree():
		await get_tree().create_timer(seconds, true).timeout


func sound(sound_name: String, softer_db := 0.0) -> void:
	MachineSounds.play(self, sound_name, softer_db)


func label(text: String, font: Font, size: int, colour := UiStyle.TEXT) -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_font_override("font", font)
	made.add_theme_font_size_override("font_size", size)
	made.add_theme_color_override("font_color", colour)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A button of the machine: a hard panel, the text in the pixel font; `action` on a click.
func button(text: String, action: Callable, wide := 0.0, colour := Color(0, 0, 0, 0)) -> Button:
	var made := Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.custom_minimum_size = Vector2(wide, 40)
	made.add_theme_font_override("font", font_pixel)
	made.add_theme_font_size_override("font_size", 14)
	var face := colour if colour.a > 0.0 else body_colour.darkened(0.35)
	for state in ["normal", "pressed", "hover", "focus", "disabled"]:
		var style := UiStyle.box_style(face.lightened(0.15) if state == "hover" else face,
			trim_colour if state == "hover" else face.darkened(0.45), 3)
		style.shadow_color = Color.BLACK
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO if state == "pressed" else Vector2(3, 3)
		style.content_margin_left = 10
		style.content_margin_right = 10
		made.add_theme_stylebox_override(state, style)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		made.add_theme_color_override(colour_name, UiStyle.TEXT)
	made.pressed.connect(func() -> void:
		if not _busy and not _closing:
			action.call())
	return made


static func euros(amount: float) -> String:
	return "€ " + _money_text(amount)


func _money() -> float:
	return float(player.get("money")) if player and player.get("money") != null else 0.0


func _inventory() -> Dictionary:
	return player.get("inventory") if player and player.get("inventory") != null else {}


static func _money_text(amount: float) -> String:
	var cents := roundi(amount * 100.0)
	return "%d,%02d" % [cents / 100, cents % 100]


# ------------------------------------------------------------------ building

func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo or _busy:
			return
		if key_event.physical_keycode == KEY_ESCAPE:
			cancel()
		else:
			_key(key_event.physical_keycode)


func _fit() -> void:
	var window := get_viewport().get_visible_rect().size
	var scale_factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	transform = Transform2D(0.0, Vector2(scale_factor, scale_factor), 0.0, (window - DESIGN_SIZE * scale_factor) * 0.5)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.size = DESIGN_SIZE * 4.0
	backdrop.position = -DESIGN_SIZE * 1.5
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_root = Control.new()
	_root.name = "Automaat"
	_root.size = DESIGN_SIZE
	add_child(_root)
	# the wall the machine stands against, bricks in rows, the pavement under it
	var wall := ColorRect.new()
	wall.color = WALL
	wall.size = DESIGN_SIZE
	_root.add_child(wall)
	for row in 30:
		var joint := ColorRect.new()
		joint.color = WALL.darkened(0.25)
		joint.position = Vector2(0, row * 24)
		joint.size = Vector2(DESIGN_SIZE.x, 3)
		joint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(joint)
		for column in 22:
			var upright := ColorRect.new()
			upright.color = joint.color
			upright.position = Vector2(column * 64 + (32 if row % 2 == 1 else 0), row * 24)
			upright.size = Vector2(3, 24)
			upright.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_root.add_child(upright)
	var pavement := ColorRect.new()
	pavement.color = PAVEMENT
	pavement.position = Vector2(0, DESIGN_SIZE.y - 40)
	pavement.size = Vector2(DESIGN_SIZE.x, 40)
	_root.add_child(pavement)
	# the housing
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.55)
	shadow.position = HOUSING_RECT.position + Vector2(10, 10)
	shadow.size = HOUSING_RECT.size
	_root.add_child(shadow)
	_housing = Panel.new()
	_housing.position = HOUSING_RECT.position
	_housing.size = HOUSING_RECT.size
	_housing.add_theme_stylebox_override("panel", UiStyle.box_style(body_colour, body_colour.darkened(0.5), 6))
	_root.add_child(_housing)
	var column := VBoxContainer.new()
	column.position = Vector2(18, 14)
	column.size = HOUSING_RECT.size - Vector2(36, 28)
	column.add_theme_constant_override("separation", 12)
	_housing.add_child(column)
	var header := PanelContainer.new()
	var header_style := UiStyle.box_style(trim_colour, trim_colour.darkened(0.35), 3)
	header_style.content_margin_top = 4
	header_style.content_margin_bottom = 4
	header.add_theme_stylebox_override("panel", header_style)
	var brand_label := label(brand, font_title, 30, body_colour.darkened(0.6))
	brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(brand_label)
	column.add_child(header)
	if place_name != "":
		var place := label(place_name, font_pixel, 11, body_colour.lightened(0.6) if body_colour.get_luminance() < 0.5 else body_colour.darkened(0.6))
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(place)
	var glass := PanelContainer.new()
	var glass_style := UiStyle.box_style(GLASS, Color("#1A1C22"), 8)
	glass_style.content_margin_left = 16
	glass_style.content_margin_right = 16
	glass_style.content_margin_top = 12
	glass_style.content_margin_bottom = 12
	glass.add_theme_stylebox_override("panel", glass_style)
	glass.custom_minimum_size = Vector2(0, 200)
	var glass_column := VBoxContainer.new()
	glass_column.add_theme_constant_override("separation", 8)
	_display_title = label("", font_pixel, 20, screen_colour)
	_display_text = label("", font_pixel, 14, screen_colour)
	glass_column.add_child(_display_title)
	glass_column.add_child(_display_text)
	glass.add_child(glass_column)
	column.add_child(glass)
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 8)
	column.add_child(_controls)
	build_controls(_controls)
	# the tray on the left, your pockets on the right
	_tray = _side_panel(TRAY_RECT, "UIT DE AUTOMAAT")
	_tray_title = label("", font_pixel, 16, UiStyle.ACCENT)
	_tray.add_child(_tray_title)
	_pockets = _side_panel(POCKETS_RECT, "")
	_keys_label = label("", font_pixel, 11, UiStyle.MUTED)
	_keys_label.position = Vector2(0, DESIGN_SIZE.y - 32)
	_keys_label.size = Vector2(DESIGN_SIZE.x, 24)
	_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_keys_label)
	# the CRT over the whole window (its own layer: it bends the picture in window pixels)
	_crt_layer = CanvasLayer.new()
	_crt_layer.layer = LAYER + 1
	_crt_layer.visible = false
	add_child(_crt_layer)
	_crt_layer.add_child(UiStyle.make_crt_overlay(0.03, 0.02, UiStyle.SCANLINE_STRENGTH, get_viewport().get_visible_rect().size))


func _side_panel(rect: Rect2, heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, 3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color.BLACK
	style.shadow_offset = Vector2(UiStyle.SHADOW_OFFSET, UiStyle.SHADOW_OFFSET)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = rect.position
	panel.size = rect.size
	panel.custom_minimum_size = rect.size
	panel.clip_contents = true
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	if heading != "":
		column.add_child(label(heading, font_pixel, 11, UiStyle.MUTED))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 6)
	column.add_child(contents)
	return contents
