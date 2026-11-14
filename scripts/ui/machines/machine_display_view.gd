extends SubViewport
## The picture on a machine's screen (a graphics layer of the close-up of a machine,
## scripts/ui/machines/machine_screen.gd; machine_screen_view.gd has this as its child and
## lays it on the model's screen in the scene, machine_stage_view.gd, as on a little CRT;
## machine_display_layout.gd has its sizes): what the machine says (a title and a text on
## dark glass: show_display) and, on a machine with a touch screen, the column of its
## buttons beside them (controls, button). It builds and styles them and shows what it is
## handed; it decides nothing: a button clicked it only passes on (button_used). A mouse
## event of the window is carried into the picture by push_mouse.
##   const MachineDisplayView = preload("res://scripts/ui/machines/machine_display_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MachineLook = preload("res://scripts/ui/machines/machine_look.gd")
const MachineDisplayLayout = preload("res://scripts/ui/machines/machine_display_layout.gd")
const NODE_NAME := "Schermbeeld"
const CONTROLS_NAME := "Knoppen"
const GLASS := Color("#0A1410")
const GLASS_EDGE := Color("#1A1C22")
## The size of the title and the text unless the machine says otherwise (a machine with a
## little screen shows a few big words), and of the text of a button as it is made and as it
## is on the screen.
const TITLE_SIZE := 28
const TEXT_SIZE := 20
const BUTTON_TEXT_SIZE := 16
const SCREEN_BUTTON_TEXT_SIZE := 18
## How much lighter the text is than the title, how much darker than the case a button
## without a colour of its own is, how much lighter a button under the mouse and how much
## darker its border.
const TEXT_LIGHTER := 0.15
const BUTTON_DARKER := 0.35
const HOVER_LIGHTER := 0.15
const BORDER_DARKER := 0.45
## The meta of a button the cursor is on: its own look, to give back.
const NORMAL_STYLE_META := "normal_style"

## A button of the screen was clicked: `action` is what it does (the behaviour calls it,
## unless the machine is busy).
signal button_used(action: Callable)

var _title: Label
var _text: Label
var _column: VBoxContainer
var _controls: VBoxContainer
var _font_buttons: Font
var _lit: Button


func _init() -> void:
	name = NODE_NAME
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR


## Builds the picture for a screen `screen_size` (metres) big: the glass, the title in
## `font_title` and the text in `font_text` (both in `ink`, `title_size` and `text_size` px),
## and the empty column of buttons `controls_width` wide.
func build(screen_size: Vector2, ink: Color, font_title: Font, font_text: Font, title_size := TITLE_SIZE, text_size := TEXT_SIZE,
		controls_width := MachineDisplayLayout.CONTROLS_WIDTH) -> void:
	size = MachineDisplayLayout.picture_size(screen_size)
	_font_buttons = font_text
	var glass := PanelContainer.new()
	var glass_style := UiStyle.box_style(GLASS, GLASS_EDGE, MachineDisplayLayout.GLASS_BORDER)
	glass_style.content_margin_left = MachineDisplayLayout.GLASS_MARGIN.x
	glass_style.content_margin_right = MachineDisplayLayout.GLASS_MARGIN.x
	glass_style.content_margin_top = MachineDisplayLayout.GLASS_MARGIN.y
	glass_style.content_margin_bottom = MachineDisplayLayout.GLASS_MARGIN.y
	glass.add_theme_stylebox_override("panel", glass_style)
	glass.size = Vector2(size)
	add_child(glass)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", MachineDisplayLayout.TITLE_SEPARATION)
	_title = MachineLook.label("", font_title, title_size, ink)
	_text = MachineLook.label("", font_text, text_size, ink)
	_column.add_child(_title)
	# the text, and on a touch screen the column of its buttons beside it
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", MachineDisplayLayout.BODY_SEPARATION)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_text)
	_controls = VBoxContainer.new()
	_controls.name = CONTROLS_NAME
	_controls.add_theme_constant_override("separation", MachineDisplayLayout.CONTROLS_SEPARATION)
	_controls.custom_minimum_size.x = controls_width
	body.add_child(_controls)
	_column.add_child(body)
	glass.add_child(_column)


## Writes the title and the text on the screen, the title in `ink`, the text a little lighter.
func show_display(title: String, text: String, ink: Color) -> void:
	if _title == null:
		return
	_title.text = title
	_text.text = text
	_title.add_theme_color_override("font_color", ink)
	_text.add_theme_color_override("font_color", ink.lerp(Color.WHITE, TEXT_LIGHTER))


func title_text() -> String:
	return _title.text if _title else ""


func body_text() -> String:
	return _text.text if _text else ""


## The colour the title is written in now.
func ink() -> Color:
	return _title.get_theme_color("font_color") if _title else Color.BLACK


## The column of the screen's buttons (right of its text); a machine puts its buttons in it.
func controls() -> VBoxContainer:
	return _controls


## The column the title and the body stand in (a machine may put something of its own over them).
func column() -> VBoxContainer:
	return _column


func has_controls() -> bool:
	return _controls != null and _controls.get_child_count() > 0


## A button of the machine: a hard panel in `face` (its border in `edge` under the mouse),
## at least `wide` px wide; a click passes `action` on (button_used).
func button(text: String, action: Callable, wide: float, face: Color, edge: Color) -> Button:
	var made := Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.custom_minimum_size = MachineDisplayLayout.button_size(wide)
	made.add_theme_font_override("font", _font_buttons if _font_buttons else UiStyle.font(UiStyle.FONT_TITLE))
	made.add_theme_font_size_override("font_size", BUTTON_TEXT_SIZE)
	for state in ["normal", "pressed", "hover", "focus", "disabled"]:
		var style := UiStyle.box_style(face.lightened(HOVER_LIGHTER) if state == "hover" else face,
			edge if state == "hover" else face.darkened(BORDER_DARKER), MachineDisplayLayout.BUTTON_BORDER)
		style.shadow_color = Color.BLACK
		style.shadow_size = 0
		style.shadow_offset = MachineDisplayLayout.button_shadow(state == "pressed")
		style.content_margin_left = MachineDisplayLayout.BUTTON_MARGIN
		style.content_margin_right = MachineDisplayLayout.BUTTON_MARGIN
		made.add_theme_stylebox_override(state, style)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		made.add_theme_color_override(colour_name, UiStyle.TEXT)
	made.pressed.connect(func() -> void: button_used.emit(action))
	return made


## The buttons are in the column: it shows when it has any, and they get a size to be read
## on the screen.
func finish_controls() -> void:
	_controls.visible = has_controls()
	_size_for_screen(_controls)


func _size_for_screen(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			(child as Button).add_theme_font_size_override("font_size", SCREEN_BUTTON_TEXT_SIZE)
			(child as Button).custom_minimum_size.y = MachineDisplayLayout.SCREEN_BUTTON_HEIGHT
			(child as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_size_for_screen(child)


## Every button of the screen that shows and can be pressed, top to bottom: {"button", "uv":
## its middle in the picture (0..1, y down)} each.
func button_spots() -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	if _controls == null:
		return spots
	var picture := Vector2(size)
	for found in _controls.find_children("*", "Button", true, false):
		var button_found := found as Button
		if button_found.is_visible_in_tree() and not button_found.disabled:
			spots.append({"button": button_found, "uv": button_found.get_global_rect().get_center() / picture})
	return spots


## Gives `lit` the look of a button under the mouse (the cursor is on it), the one that had
## it its own look back; null: none has it.
func show_lit(lit: Button) -> void:
	if is_instance_valid(_lit):
		_lit.remove_theme_stylebox_override("normal")
		_lit.add_theme_stylebox_override("normal", _lit.get_meta(NORMAL_STYLE_META))
	_lit = lit
	if lit == null:
		return
	if not lit.has_meta(NORMAL_STYLE_META):
		lit.set_meta(NORMAL_STYLE_META, lit.get_theme_stylebox("normal"))
	lit.add_theme_stylebox_override("normal", lit.get_theme_stylebox("hover"))


## The button that has the look of the cursor now (null: none).
func lit_button() -> Button:
	return _lit if is_instance_valid(_lit) else null


## Carries a mouse event of the window into the picture, at `point` (px of the picture).
func push_mouse(event: InputEventMouse, point: Vector2) -> void:
	var carried := event.duplicate() as InputEventMouse
	carried.position = point
	carried.global_position = point
	push_input(carried, true)
