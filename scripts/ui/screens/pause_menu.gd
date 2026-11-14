extends Control
## The pause menu (Escape; the node "Pauze" of the HUD): a panel in the middle over the
## game standing still, with VERDER SPELEN, INSTELLINGEN, HOOFDMENU and AFSLUITEN; up/down,
## Enter, Escape (back to the game) or the mouse. INSTELLINGEN shows the settings in the same
## panel (as in the main menu: anti-aliasing, render scale, the CRT look, how the camera
## turns), changed at once; TERUG or Escape back.
## The HUD opens and closes it (GameHud.set_paused: the tree paused, the mouse handed to the
## HUD's picture) and gives it the keys (handle_input); the menu asks for what is not its
## own: going on with the game (resume_wanted) and the CRT look of the HUD (crt_changed).
##   const PauseMenu = preload("res://scripts/ui/screens/pause_menu.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const CameraTurning = preload("res://scripts/camera/camera_turning.gd")
## The items of the menu: what it says and what it does (_do).
const ITEMS := [["VERDER SPELEN", "resume"], ["INSTELLINGEN", "settings"], ["HOOFDMENU", "menu"], ["AFSLUITEN", "quit"]]
const MAIN_MENU_SCENE := "res://scenes/hoofdmenu.tscn"
const WIDTH := 300.0
## How much wider the buttons of the settings are (their values beside their names).
const SETTINGS_WIDER := 100.0

## VERDER SPELEN, or Escape on the menu: the game goes on.
signal resume_wanted
## The CRT look was switched on or off in the settings.
signal crt_changed(on: bool)

var _buttons: Array[Button] = []
var _selected := 0
var _column: VBoxContainer
## What the panel shows now: per item {"label": Callable -> String, "do": Callable}; the
## menu itself or the settings (show_page).
var _entries: Array[Dictionary] = []
var _in_settings := false
var _font_title_medium: Font


func _init() -> void:
	name = "Pauze"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var fonts := UiStyle.fonts()
	_font_title_medium = fonts.title_medium
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel().add_child(column)
	var title := UiStyle.label("— PAUZE —", fonts.pixel, 12, UiStyle.ACCENT, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	column.add_child(_column)
	var keys := UiStyle.label("[↑↓] KIEZEN   [ENTER] KIES   [ESC] TERUG", fonts.pixel, 10, UiStyle.MUTED)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys)
	show_page(false)


# ------------------------------------------------------------------ for the HUD

## Opens the menu (on its first page) or closes it; a sound when that changes something.
func set_open(on: bool) -> void:
	if on != visible:
		UiSounds.play(self, "doe" if on else "terug")
	visible = on
	if on:
		show_page(false)


func is_open() -> bool:
	return visible


## Whether the settings are shown in place of the menu itself.
func in_settings() -> bool:
	return _in_settings


## The buttons of the page shown now, top to bottom.
func buttons() -> Array[Button]:
	return _buttons


## The index of the item of ITEMS that does `action` ("resume", "settings", ...); -1: none.
static func item_index(action: String) -> int:
	for index in ITEMS.size():
		if ITEMS[index][1] == action:
			return index
	return -1


## A key while the menu is open: up/down, Enter, Escape (the settings: back to the menu;
## the menu: on with the game). True when it was one of those.
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("ui_cancel"):
		if _in_settings:
			UiSounds.play(self, "terug")
			show_page(false)
		else:
			resume_wanted.emit()
	elif event.is_action_pressed("ui_down"):
		select(next_index(_selected, 1, _entries.size()))
	elif event.is_action_pressed("ui_up"):
		select(next_index(_selected, -1, _entries.size()))
	elif event.is_action_pressed("ui_accept"):
		choose(_selected)
	else:
		return false
	return true


## The item `step` (1: down, -1: up) from `index` of `count`, round at the ends.
static func next_index(index: int, step: int, count: int) -> int:
	return posmod(index + step, count) if count > 0 else 0


## The menu itself, or (`settings`) the settings in its place.
func show_page(settings: bool) -> void:
	_in_settings = settings
	_entries = _settings_entries() if settings else _menu_entries()
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for index in _entries.size():
		_buttons.append(_button(index, WIDTH + (SETTINGS_WIDER if settings else 0.0)))
	_selected = -1
	select(0)


## Puts the arrow on item `index` (its look, and every label anew: a setting may have changed).
func select(index: int) -> void:
	if index != _selected and visible:
		UiSounds.play(self, "kies")
	_selected = index
	for button_index in _buttons.size():
		_style_button(_buttons[button_index], button_index == index, String((_entries[button_index].label as Callable).call()))


## Does what item `index` stands for.
func choose(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var page_before := _in_settings
	await (_entries[index].do as Callable).call()
	# a setting changed: its label again (a page that changed is drawn anew already)
	if is_inside_tree() and _in_settings == page_before and visible:
		select(_selected)


# ------------------------------------------------------------------ the pages

func _menu_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item: Array in ITEMS:
		var label_text: String = item[0]
		entries.append({"label": func() -> String: return label_text, "do": _do.bind(String(item[1]))})
	return entries


func _settings_entries() -> Array[Dictionary]:
	return [
		{"label": func() -> String: return "ANTI-ALIASING: %s" % GraphicsSettings.anti_aliasing(),
			"do": func() -> void: GraphicsSettings.next_anti_aliasing(get_tree())},
		{"label": func() -> String: return "RENDERSCHAAL: %s" % GraphicsSettings.render_scale_text(),
			"do": func() -> void: GraphicsSettings.next_render_scale(get_tree())},
		{"label": func() -> String: return "CRT-BEELD: %s" % ("AAN" if crt_on() else "UIT"), "do": _toggle_crt},
		{"label": CameraTurning.label, "do": _toggle_camera_turning},
		{"label": func() -> String: return "TERUG", "do": func() -> void: show_page(false)},
	]


func _do(action: String) -> void:
	if action != "resume":   # going on sounds as closing the menu (set_open)
		UiSounds.play(self, "doe")
	match action:
		"resume":
			resume_wanted.emit()
		"settings":
			show_page(true)
		"menu":
			# the swipe (the one transition of the game) over it, then the menu
			await SwipeTransition.swipe(get_tree()).covered
			get_tree().paused = false
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		"quit":
			get_tree().quit()


## Whether the CRT look is on (the setting of the main menu too).
static func crt_on() -> bool:
	var config := ConfigFile.new()
	config.load(MainMenu.SETTINGS_PATH)
	return bool(config.get_value("beeld", "crt", true))


## The CRT look on or off (the setting of the main menu too), at once (crt_changed).
func _toggle_crt() -> void:
	var on := not crt_on()
	var config := ConfigFile.new()
	config.load(MainMenu.SETTINGS_PATH)
	config.set_value("beeld", "crt", on)
	config.save(MainMenu.SETTINGS_PATH)
	crt_changed.emit(on)


## The camera turning by itself or by hand (CameraTurning), at once for the follow camera.
func _toggle_camera_turning() -> void:
	CameraTurning.set_manual(not CameraTurning.is_manual())
	var follow := get_tree().current_scene.get_node_or_null("Volgcamera") if get_tree().current_scene else null
	if follow and follow.has_method("set_manual_turning"):
		follow.set_manual_turning(CameraTurning.is_manual())


# ------------------------------------------------------------------ building

func _panel() -> PanelContainer:
	var box := PanelContainer.new()
	var style := UiStyle.box_style(Color(UiStyle.INK, 0.94), UiStyle.BORDER, 3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	box.add_theme_stylebox_override("panel", style)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)
	return box


func _button(index: int, width: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(width, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font_title_medium)
	button.add_theme_font_size_override("font_size", 22)
	button.mouse_entered.connect(func() -> void: select(index))
	button.pressed.connect(func() -> void: choose(index))
	_column.add_child(button)
	return button


static func _style_button(button: Button, on: bool, text: String) -> void:
	var style := UiStyle.menu_item_style(on)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(colour_name, UiStyle.INK if on else UiStyle.TEXT)
	button.text = ("→  " if on else "    ") + text
