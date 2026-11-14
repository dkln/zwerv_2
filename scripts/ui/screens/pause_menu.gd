extends Control
## The pause menu (Escape; the node "Pauze" of the HUD): a panel in the middle over the
## game standing still, with VERDER SPELEN, INSTELLINGEN, HOOFDMENU and AFSLUITEN; up/down,
## Enter, Escape (back to the game) or the mouse. INSTELLINGEN shows the settings in the same
## panel (as in the main menu: anti-aliasing, render scale, the CRT look, how the camera
## turns), changed at once; TERUG or Escape back.
## The HUD opens and closes it (GameHud.set_paused: the tree paused, the mouse handed to the
## HUD's picture) and gives it the keys (handle_input); the menu asks for what is not its
## own: going on with the game (resume_wanted) and the CRT look of the HUD (crt_changed).
## This is the behaviour layer: open and closed, the keys, which item is selected, what
## the items do, the settings read and written. pause_menu_rules.gd has the logic (the
## items, the next item, how a setting reads), pause_menu_layout.gd the sizes,
## pause_menu_view.gd builds the panel and its buttons and shows what it is handed.
##   const PauseMenu = preload("res://scripts/ui/screens/pause_menu.gd")

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const CameraTurning = preload("res://scripts/camera/camera_turning.gd")
const PauseMenuRules = preload("res://scripts/ui/screens/pause_menu_rules.gd")
const PauseMenuLayout = preload("res://scripts/ui/screens/pause_menu_layout.gd")
const PauseMenuView = preload("res://scripts/ui/screens/pause_menu_view.gd")
const MAIN_MENU_SCENE := "res://scenes/hoofdmenu.tscn"

## VERDER SPELEN, or Escape on the menu: the game goes on.
signal resume_wanted
## The CRT look was switched on or off in the settings.
signal crt_changed(on: bool)

var _view: PauseMenuView
var _selected := 0
## What the panel shows now: per item {"label": Callable -> String, "do": Callable}; the
## menu itself or the settings (show_page).
var _entries: Array[Dictionary] = []
var _in_settings := false


func _init() -> void:
	name = "Pauze"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_view = PauseMenuView.new()
	_view.entry_hovered.connect(select)
	_view.entry_pressed.connect(choose)
	add_child(_view)
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
	return _view.buttons()


## The index of the item of the menu that does `action` ("resume", "settings", ...); -1:
## none (PauseMenuRules.item_index, here for whoever has the menu at hand: the HUD's tests).
static func item_index(action: String) -> int:
	return PauseMenuRules.item_index(action)


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
		select(PauseMenuRules.next_index(_selected, 1, _entries.size()))
	elif event.is_action_pressed("ui_up"):
		select(PauseMenuRules.next_index(_selected, -1, _entries.size()))
	elif event.is_action_pressed("ui_accept"):
		choose(_selected)
	else:
		return false
	return true


## The menu itself, or (`settings`) the settings in its place.
func show_page(settings: bool) -> void:
	_in_settings = settings
	_entries = _settings_entries() if settings else _menu_entries()
	_view.show_entries(_labels(), PauseMenuLayout.button_width(settings))
	_selected = -1
	select(0)


## Puts the arrow on item `index` (its look, and every label anew: a setting may have changed).
func select(index: int) -> void:
	if index != _selected and visible:
		UiSounds.play(self, "kies")
	_selected = index
	_view.show_selected(index, _labels())


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

## What every entry of the page says now (a setting may have changed), top to bottom.
func _labels() -> Array[String]:
	var labels: Array[String] = []
	for entry in _entries:
		labels.append(String((entry.label as Callable).call()))
	return labels


func _menu_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var labels := PauseMenuRules.item_labels()
	var actions := PauseMenuRules.item_actions()
	for index in labels.size():
		var label_text := labels[index]
		entries.append({"label": func() -> String: return label_text, "do": _do.bind(actions[index])})
	return entries


func _settings_entries() -> Array[Dictionary]:
	return [
		{"label": func() -> String: return PauseMenuRules.anti_aliasing_label(GraphicsSettings.anti_aliasing()),
			"do": func() -> void: GraphicsSettings.next_anti_aliasing(get_tree())},
		{"label": func() -> String: return PauseMenuRules.render_scale_label(GraphicsSettings.render_scale_text()),
			"do": func() -> void: GraphicsSettings.next_render_scale(get_tree())},
		{"label": func() -> String: return PauseMenuRules.crt_label(crt_on()), "do": _toggle_crt},
		{"label": CameraTurning.label, "do": _toggle_camera_turning},
		{"label": func() -> String: return PauseMenuRules.BACK_LABEL, "do": func() -> void: show_page(false)},
	]


func _do(action: String) -> void:
	if PauseMenuRules.action_sounds(action):   # going on sounds as closing the menu (set_open)
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
