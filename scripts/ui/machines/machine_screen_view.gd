extends Control
## How the close-up of a machine looks (the graphics layer of
## scripts/ui/machines/machine_screen.gd, which is the behaviour and has this as its child;
## machine_screen_rules.gd has the logic, machine_screen_layout.gd the sizes). It is made of
## parts, each a view of its own: the 3D scene with you at the machine
## (machine_stage_view.gd), the picture on the machine's screen with its buttons
## (machine_display_view.gd) and the panel bottom left with what came out and what you carry
## (machine_info_view.gd); over them the line with the keys, the frame of the cursor round a
## part of the machine and the CRT. In the pixel look of the HUD (UiStyle). The colours of
## the tones are in machine_look.gd.
## A machine has a view of its own that extends this one and says what the machine is: its
## colours (body_colour, trim_colour, screen_colour), its model and where its parts are
## (machine_parts) and the buttons on its screen (build_controls).
## It builds and shows what it is handed (show_...) and tells where things are in the window;
## it decides nothing: a button clicked it only passes on (button_used, option_pressed).
##   const MachineScreenView = preload("res://scripts/ui/machines/machine_screen_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MachineLook = preload("res://scripts/ui/machines/machine_look.gd")
const MachineScreenLayout = preload("res://scripts/ui/machines/machine_screen_layout.gd")
const MachineStageLayout = preload("res://scripts/ui/machines/machine_stage_layout.gd")
const MachineDisplayLayout = preload("res://scripts/ui/machines/machine_display_layout.gd")
const MachineStageView = preload("res://scripts/ui/machines/machine_stage_view.gd")
const MachineDisplayView = preload("res://scripts/ui/machines/machine_display_view.gd")
const MachineInfoView = preload("res://scripts/ui/machines/machine_info_view.gd")
const NODE_NAME := "Automaat"
const KEYS_FONT_SIZE := 15
const KEYS_SHADOW := 2
## The CRT over the whole window: how much it bends and how round its corners are.
const CRT_CURVATURE := 0.03
const CRT_CORNER := 0.02
## How much darker than the case a button without a colour of its own is.
const BUTTON_DARKER := 0.35
## No colour given: the machine's own (a button: the case, darker).
const NO_COLOUR := Color(0, 0, 0, 0)

## A button of the screen was clicked: `action` is what it does.
signal button_used(action: Callable)
## Option button `index` (add_options) was used.
signal option_pressed(index: int)

## The machine's look (a machine's own view sets them in its _init).
var body_colour := Color("#3A4250")
var trim_colour := Color("#F2B705")
var screen_colour := Color("#5FE0FF")
## The title and the text of the screen (px); a machine with a little screen shows a few
## big words. And how wide the column of the screen's buttons is (px).
var display_title_size := MachineDisplayView.TITLE_SIZE
var display_text_size := MachineDisplayView.TEXT_SIZE
var screen_controls_width := MachineDisplayLayout.CONTROLS_WIDTH
## False (the checks): nothing slides or fades, everything is where it ends at once.
var animate := true

var font_title: Font
var font_pixel: Font
var font_body: Font
## The font of the machine's screen, its buttons and the headings: Pixelify Sans, a pixel font
## with lower case that reads well at any size (Silkscreen, all capitals on an 8 px grid, was
## hard to read on the screen at the sizes it needs).
var font_screen: Font
var _parts := {}
var _stage: MachineStageView
var _display: MachineDisplayView
var _info: MachineInfoView
var _keys: Label
var _cursor_frame: Panel
var _crt_layer: CanvasLayer
var _options: Array[Button] = []


func _init() -> void:
	name = NODE_NAME
	size = MachineScreenLayout.DESIGN_SIZE
	var body := UiStyle.font(UiStyle.FONT_BODY)
	font_body = UiStyle.weighted(body, 400)
	font_pixel = UiStyle.font(UiStyle.FONT_PIXEL)
	font_title = UiStyle.weighted(UiStyle.font(UiStyle.FONT_TITLE), 700)
	font_screen = UiStyle.font(UiStyle.FONT_TITLE)
	if body is FontFile:
		var fallbacks: Array[Font] = [body]
		font_pixel.fallbacks = fallbacks


# ------------------------------------------------------------------ for the machines

## The model of the machine and where its parts are on it (metres, in the model's space: it
## stands on y = 0, centred, its front facing +z): {"mesh": Mesh, "screen": Rect2 (x and y of
## its lower left corner, its size), "front": z of its front, "screen_sunk": how far the
## screen lies behind the front (m, 0 if left out), "keys": Vector3 (the keypad),
## "slot": Vector3 (where things come out), "focus": Rect2 (what the camera comes in close
## on, else the screen), "focus_share", "hotspots": [{"name", "rect"}] (parts you can click)}.
## Without one: a box with the parts where a machine has them.
func machine_parts() -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = MachineStageLayout.BOX_SIZE
	var made := MachineStageLayout.default_parts()
	made["mesh"] = mesh
	return made


## The buttons of the machine on its screen, beside its text (a keypad, choices). Nothing:
## the screen only shows (the deposit machine: you use its hole and its BON key).
func build_controls(_box: VBoxContainer) -> void:
	pass


## A button of the machine: a hard panel, the text in the pixel font, `wide` px at least, in
## `colour` (none: the case, darker); a click passes `action` on (button_used).
func button(text: String, action: Callable, wide := 0.0, colour := NO_COLOUR) -> Button:
	var face := colour if colour.a > 0.0 else body_colour.darkened(BUTTON_DARKER)
	return _display.button(text, action, wide, face, trim_colour)


## A label as the machines write one.
func label(text: String, font: Font, font_size: int, colour := UiStyle.TEXT) -> Label:
	return MachineLook.label(text, font, font_size, colour)


## Puts `count` option buttons in `box` (the choices of a touch screen, their text to the
## left, in `colour`); what they say comes with show_options, using one gives option_pressed.
func add_options(box: VBoxContainer, count: int, colour := NO_COLOUR) -> void:
	for option_index in count:
		var option := button("", option_pressed.emit.bind(option_index), 0.0, colour)
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(option)
		_options.append(option)


# ------------------------------------------------------------------ building

## Builds everything (this node in the tree already): the black behind it, the picture of
## the screen, the scene with the wall and ground of `backdrop` (of `tiles` when they are
## there) and you (`stand_in`: {"archetype_id", "figure_scale", "coat"}), the panel with
## `tray_heading` over its tray, the machine's buttons, the line of the keys and the CRT
## (hidden until show_open).
func build(backdrop: String, tiles: Dictionary, tray_heading: String, stand_in: Dictionary) -> void:
	_parts = machine_parts()
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = MachineScreenLayout.black_rect().size
	black.position = MachineScreenLayout.black_rect().position
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	_display = MachineDisplayView.new()
	add_child(_display)
	_display.build(MachineStageLayout.screen_of(_parts).size, screen_colour, font_title, font_screen, display_title_size, display_text_size,
		screen_controls_width)
	_display.button_used.connect(func(action: Callable) -> void: button_used.emit(action))
	_stage = MachineStageView.new()
	add_child(_stage)
	_stage.build(_parts, _display.get_texture(), Vector2(_display.size), screen_colour, trim_colour, backdrop, tiles, stand_in)
	# the tray and your pockets in one panel bottom left; the buttons of the machine are on its screen
	_info = MachineInfoView.new()
	add_child(_info)
	_info.build(tray_heading, font_screen, font_title, font_body)
	build_controls(_display.controls())
	_display.finish_controls()
	_keys = label("", font_screen, KEYS_FONT_SIZE, UiStyle.TEXT)
	_keys.position = MachineScreenLayout.keys_rect().position
	_keys.size = MachineScreenLayout.keys_rect().size
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.add_theme_color_override("font_shadow_color", Color.BLACK)
	_keys.add_theme_constant_override("shadow_offset_x", KEYS_SHADOW)
	_keys.add_theme_constant_override("shadow_offset_y", KEYS_SHADOW)
	add_child(_keys)
	# the CRT over the whole window (its own layer: it bends the picture in window pixels)
	_crt_layer = CanvasLayer.new()
	_crt_layer.layer = MachineScreenLayout.CRT_LAYER
	_crt_layer.visible = false
	add_child(_crt_layer)
	_crt_layer.add_child(UiStyle.make_crt_overlay(CRT_CURVATURE, CRT_CORNER, get_viewport().get_visible_rect().size))


func is_built() -> bool:
	return _display != null


# ------------------------------------------------------------------ showing

## The machine is up (`on`) or gone: the CRT over it with it.
func show_open(on: bool) -> void:
	if _crt_layer:
		_crt_layer.visible = on


## The camera slides in close on the part you use.
func play_camera_in() -> void:
	_stage.play_camera_in(animate)


## What the machine says on its screen: a title and a text in the colour of `tone` (none:
## its own screen colour).
func show_display(title: String, text: String, tone := "") -> void:
	if _display:
		_display.show_display(title, text, MachineLook.tone_colour(tone, screen_colour))


## What came out of the machine, in the tray: a title and lines in the colour of `tone`
## (the tray shows when `shown`); `with_slip`: in the scene it slides out of the slot, else
## what lay there is gone.
func show_tray(title: String, lines: Array, tone: String, shown: bool, with_slip: bool) -> void:
	var colour := MachineLook.tone_colour(tone, UiStyle.TEXT)
	if with_slip:
		_stage.show_slip(colour, animate)
	else:
		_stage.clear_slips()
	_info.show_tray(title, lines, colour, shown, animate)


## What you carry: `heading` over `lines` ([text, tone] each).
func show_pockets(heading: String, lines: Array) -> void:
	if _info == null:
		return
	var coloured: Array = []
	for line: Array in lines:
		coloured.append([String(line[0]), MachineLook.tone_colour(String(line[1]), UiStyle.TEXT)])
	_info.show_pockets(heading, coloured)


## The line with the keys along the bottom.
func show_hints(text: String) -> void:
	if _keys:
		_keys.text = text


## A key of the machine pressed: the light at its keypad shines a moment.
func show_press() -> void:
	if _stage:
		_stage.show_press(animate)


## What the option buttons say, top to bottom; a button without a text is hidden.
func show_options(texts: Array) -> void:
	for index in _options.size():
		var shown := index < texts.size()
		_options[index].visible = shown
		_options[index].text = String(texts[index]) if shown else ""


## The cursor on a button of the screen: it gets the look of a button under the mouse.
func show_cursor_on_button(lit: Button) -> void:
	hide_cursor()
	_display.show_lit(lit)


## The cursor on a part of the machine (`rect` on its front, metres): a frame round it,
## where it is in the window.
func show_cursor_on_part(rect: Rect2) -> void:
	hide_cursor()
	var corners := _stage.window_corners(rect)
	if corners.is_empty():
		return
	if _cursor_frame == null:
		_cursor_frame = Panel.new()
		_cursor_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = trim_colour
		style.set_border_width_all(MachineScreenLayout.CURSOR_FRAME_BORDER)
		_cursor_frame.add_theme_stylebox_override("panel", style)
		add_child(_cursor_frame)
	var frame := MachineScreenLayout.cursor_frame_rect(corners)
	_cursor_frame.position = frame.position
	_cursor_frame.size = frame.size
	_cursor_frame.visible = true


## The cursor gone: no button lit, no frame.
func hide_cursor() -> void:
	if _display:
		_display.show_lit(null)
	if _cursor_frame:
		_cursor_frame.visible = false


# ------------------------------------------------------------------ what there is

## The parts of the machine as built (machine_parts, made once).
func parts() -> Dictionary:
	return _parts


func screen_rect() -> Rect2:
	return MachineStageLayout.screen_of(_parts)


func front() -> float:
	return MachineStageLayout.front_of(_parts)


## The parts of the machine you can click: {"name", "rect"} each.
func hotspots() -> Array:
	return _parts.get("hotspots", [])


func stage() -> MachineStageView:
	return _stage


func display() -> MachineDisplayView:
	return _display


func info() -> MachineInfoView:
	return _info


## The scene (for the checks): the machine's model, the stand-in, what came out, the camera,
## the picture of the screen.
func stage_parts() -> Dictionary:
	var found := _stage.stage_parts()
	found["display"] = _display
	return found


func option_buttons() -> Array[Button]:
	return _options


func hints_text() -> String:
	return _keys.text if _keys else ""


func crt_showing() -> bool:
	return _crt_layer != null and _crt_layer.visible


## The frame of the cursor round a part (null until it was shown once).
func cursor_frame() -> Panel:
	return _cursor_frame
