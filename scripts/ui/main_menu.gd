class_name MainMenu
extends "res://scripts/ui/menu/menu_map.gd"
## The title screen before the town opens (scenes/hoofdmenu.tscn, the main scene), after
## the design "Titelscherm" in the style of the HUD (scripts/ui/hud.gd): at once the night
## colour; meanwhile the small 3D map of the skyline round Centraal at night loads in the
## background (scenes/menu_kaart.scn, baked
## by tools/build/build_menu_map.gd from scenes/menu_kaart_bron.tscn, which you edit) and
## fades in over it, shaded towards the left where the text is. Then the title, the menu, a footer with the keys and the
## version, and the CRT look over all of it (UiStyle.make_crt_overlay).
## The menu (keys up/down, Enter, Escape; or the mouse):
## - VERDERGAAN and LADEN: greyed out and skipped until there are saved games;
## - NIEUW SPEL: opens the character creation screen (scenes/karakter.tscn, its own step:
##   choose the archetype there, then the town opens);
## - INSTELLINGEN: the CRT effect and the scanlines on or off (user://instellingen.cfg, read
##   by the HUD);
## - CREDITS: who made it, rolling (every role, the same name);
## - AFSLUITEN: quits.
## The design is laid out at 1280 x 720 and scales with the window.
## The living 3D map behind it (columns, tram, helicopter, moon) is in its base,
## scripts/ui/menu/menu_map.gd; this file is the menu itself and its panels.

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")

const CHARACTER_SCENE := "res://scenes/karakter.tscn"
## The music of the menu (its own piece, "Nachtstad", not the intro's theme going on),
## played whole and looped, at full volume from the first moment
## the menu opens (no fade in: it starts with a bang); its volume (dB) and the seconds it
## fades out when the town opens.
const MUSIC := "res://assets/audio/muziek/nachtstad_menu_loop.ogg"
const MUSIC_VOLUME_DB := -9.5
const MUSIC_FADE_OUT := 2.0
const DESIGN_SIZE := Vector2(1280, 720)
const VERSION := "v0.1.0"
## Settings shared with the HUD (GameHud reads them in _ready).
const SETTINGS_PATH := "user://instellingen.cfg"

const SKY := Color("#0E1130")
## Star colours (the intro draws its stars with them).
const STAR_BRIGHT := Color("#F2E8C9")
const STAR_DIM := Color("#8A90C0")
const TITLE_COLOUR := Color("#F4EEDD")
const SOFT_TEXT := Color("#C9CCE6")

## The menu: label, whether it can be chosen now, and what it does.
const ITEMS := [
	["VERDERGAAN", false, "continue"],
	["NIEUW SPEL", true, "new_game"],
	["LADEN", false, "load"],
	["INSTELLINGEN", true, "settings"],
	["CREDITS", true, "credits"],
	["AFSLUITEN", true, "quit"],
]

var _design: Control             # everything laid out at DESIGN_SIZE, scaled to the window
var _buttons: Array[Button] = []
var _selected := 1
var _panel: Control              # the open settings or credits panel, if any
var _font_title: Font
var _font_title_medium: Font
var _font_pixel: Font
var _font_body: Font
var _crt: ColorRect
var _map_loading := false
var _music: AudioStreamPlayer

var _title_column: Control
var _menu_box: Control
var _footer: Array = []


func _ready() -> void:
	_opened_on_frame = Engine.get_process_frames()
	_load_fonts()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# the night colour shows at once; the 3D map loads meanwhile (it is big) and fades in
	# over it when it is there (_process, _show_map)
	_sky = ColorRect.new()
	_sky.color = SKY
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_design = Control.new()
	_design.name = "Ontwerp"
	_design.size = DESIGN_SIZE
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design)
	_backdrop = Control.new()
	_backdrop.name = "Achtergrond"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_backdrop)
	if ResourceLoader.exists(MAP_SCENE):
		# the intro has loaded it already, as a rule: then it is there at once
		if ResourceLoader.load_threaded_get_status(MAP_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(MAP_SCENE)
		_map_loading = true
	_build_title()
	_build_menu()
	_build_footer()
	var settings := _read_settings()
	_crt = UiStyle.make_crt_overlay(0.05 if settings.crt else 0.0, 0.035 if settings.crt else 0.0,
			0.1 if settings.scanlines else 0.0, get_viewport().get_visible_rect().size)
	add_child(_crt)
	# now and then the picture is disturbed (a rolling band, VHS tracking)
	_crt.add_child(load("res://scripts/ui/crt_disturbance.gd").new())
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_select(_selected, false)
	_play_entrance()
	_start_music()


## Fades the menu music out as the menu is left: it moves to the root of the tree (which
## stays when the town opens), fades there, and is freed when silent.
func _fade_out_music() -> void:
	if _music == null or not _music.playing:
		return
	var music := _music
	_music = null
	music.reparent(get_tree().root)
	var fade := get_tree().create_tween()
	fade.tween_property(music, "volume_db", -60.0, MUSIC_FADE_OUT)
	fade.tween_callback(music.queue_free)


## Plays the menu music, looped as a whole, at once at full volume (imported by the editor; if it has not
## been imported yet, read straight from the file).
func _start_music() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(MUSIC):
		stream = load(MUSIC)
	elif FileAccess.file_exists(MUSIC):
		stream = AudioStreamOggVorbis.load_from_file(MUSIC)
	if stream == null:
		push_warning("main menu: no music at %s" % MUSIC)
		return
	# the loop is seamless over the whole file (tools/music/README.md)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
		(stream as AudioStreamOggVorbis).loop_offset = 0.0

	_music = AudioStreamPlayer.new()
	_music.name = "Muziek"
	_music.stream = stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()


## The menu comes in, slowly, in two parts: first the logo (the title column) slides in from
## the left as it fades in (TITLE_SECONDS); when it is nearly there (MENU_AFTER) the items
## follow one by one (ENTRANCE_ITEM_DELAY apart), then the footer; the picture loses its
## tracking for a moment as if the tape just started. The menu works at once (keys during it
## count).
const ENTRANCE_SLIDE := 40.0


const TITLE_SECONDS := 2.4


const MENU_AFTER := 1.8


const ENTRANCE_SECONDS := 1.6


const ENTRANCE_ITEM_DELAY := 0.22


func _play_entrance() -> void:
	var entrance := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var title_at := _title_column.position
	_title_column.position = title_at - Vector2(ENTRANCE_SLIDE, 0)
	_title_column.modulate.a = 0.0
	entrance.tween_property(_title_column, "position", title_at, TITLE_SECONDS)
	entrance.tween_property(_title_column, "modulate:a", 1.0, TITLE_SECONDS)
	var menu_at := _menu_box.position
	_menu_box.position = menu_at - Vector2(ENTRANCE_SLIDE, 0)
	_menu_box.modulate.a = 0.0
	entrance.tween_property(_menu_box, "modulate:a", 1.0, 0.3).set_delay(MENU_AFTER)
	entrance.tween_property(_menu_box, "position", menu_at, ENTRANCE_SECONDS + ENTRANCE_ITEM_DELAY * _buttons.size()).set_delay(MENU_AFTER)
	for index in _buttons.size():
		_buttons[index].modulate.a = 0.0
		entrance.tween_property(_buttons[index], "modulate:a", 1.0, ENTRANCE_SECONDS * 0.8).set_delay(MENU_AFTER + ENTRANCE_ITEM_DELAY * index)
	for footer_label: CanvasItem in _footer:
		footer_label.modulate.a = 0.0
		entrance.tween_property(footer_label, "modulate:a", 1.0, ENTRANCE_SECONDS).set_delay(MENU_AFTER + 0.3 + ENTRANCE_ITEM_DELAY * _buttons.size())
	# the tape starting: a short loss of tracking that settles
	var material := _crt.material as ShaderMaterial
	material.set_shader_parameter("tracking", 0.8)
	entrance.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), 0.8, 0.0, 1.6)


func _process(delta: float) -> void:
	_drift(delta)
	_drive_columns(delta)
	_ride_tram(delta)
	_place_helicopter_circle()
	_fly_helicopter_entry(delta)
	if _map_loading:
		var status := ResourceLoader.load_threaded_get_status(MAP_SCENE)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_map_loading = false
			_show_map(ResourceLoader.load_threaded_get(MAP_SCENE) as PackedScene)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_map_loading = false   # no map: the drawn backdrop stays


# ------------------------------------------------------------------ the sun and the moon

func _unhandled_input(event: InputEvent) -> void:
	if _loading:
		return
	if _panel != null:
		# a sub menu works as the main one: up/down, Enter, Escape (back)
		if event.is_action_pressed("ui_cancel"):
			_close_panel()
		elif event.is_action_pressed("ui_down"):
			_select_in_panel(posmod(_panel_selected + 1, _panel_buttons.size()))
		elif event.is_action_pressed("ui_up"):
			_select_in_panel(posmod(_panel_selected - 1, _panel_buttons.size()))
		elif event.is_action_pressed("ui_accept"):
			_choose_in_panel(_panel_selected)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		return
	elif event.is_action_pressed("ui_down"):
		_select(_next_choosable(_selected, 1))
	elif event.is_action_pressed("ui_up"):
		_select(_next_choosable(_selected, -1))
	elif event.is_action_pressed("ui_accept"):
		_choose(_selected)
	else:
		return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ the menu

func _next_choosable(from: int, step: int) -> int:
	var index := from
	for _attempt in ITEMS.size():
		index = posmod(index + step, ITEMS.size())
		if ITEMS[index][1]:
			return index
	return from


func _select(index: int, audible := true) -> void:
	if audible and index != _selected:
		UiSounds.play(self, "kies")
	_selected = index
	for button_index in _buttons.size():
		_style_button(_buttons[button_index], button_index == index, ITEMS[button_index][1])


func _choose(index: int) -> void:
	if not ITEMS[index][1] or _loading:
		return
	UiSounds.play(self, "doe")
	match ITEMS[index][2]:
		"new_game":
			_open_character_creation()
		"settings":
			_open_settings()
		"credits":
			_open_credits()
		"quit":
			_fade_out_music()
			_loading = true
			await get_tree().create_timer(MUSIC_FADE_OUT * 0.6).timeout
			get_tree().quit()


## Opens the character creation screen (the town opens after it): "LADEN…" on the item,
## the 3D map freed first, then the screen. (The 3D map is baked, scenes/menu_kaart.scn,
## and shares nothing with the town: with the town's tile libraries in the menu, starting
## the town crashed Godot; it is gone before the town loads.)
func _open_character_creation() -> void:
	_loading = true
	_buttons[1].text = _caret(true) + "LADEN…"
	if _map_loading:
		# the 3D map is still loading in the background: let it finish first, so no
		# background load runs while the town starts
		ResourceLoader.load_threaded_get(MAP_SCENE)
		_map_loading = false
	await _play_exit()
	# the 3D map goes first, wholly: with it still in memory while the town loads its huge
	# tile libraries, the memory ran out ("mem is null") and Godot crashed
	_free_map()
	for frame_index in 3:
		await get_tree().process_frame
	get_tree().change_scene_to_file(CHARACTER_SCENE)


## Frees the 3D map and everything that holds on to it (camera, sun and moon, trams).
func _free_map() -> void:
	var map := get_parent().get_node_or_null("Menukaart")
	_map_camera = null
	_moon = null
	_sun_disc = null
	_day_cycle = null
	_trams.clear()
	_columns.clear()
	_wrecks.clear()
	if map:
		map.queue_free()


## The menu goes: the items fade out one by one, the title slides off to the left, and the
## picture goes into a wave (WarpTransition, ending in ink, the colour of the town's loading
## screen, which comes out of it). Awaited before the town is opened.
const EXIT_SECONDS := 0.9


const WARP_SECONDS := 1.6


func _play_exit() -> void:
	var exit := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_out_music()
	for index in _buttons.size():
		exit.tween_property(_buttons[index], "modulate:a", 0.0, EXIT_SECONDS * 0.7).set_delay(ENTRANCE_ITEM_DELAY * 0.6 * index)
	exit.tween_property(_title_column, "position", _title_column.position - Vector2(ENTRANCE_SLIDE * 2.0, 0), EXIT_SECONDS)
	exit.tween_property(_title_column, "modulate:a", 0.0, EXIT_SECONDS)
	for footer_label: CanvasItem in _footer:
		exit.tween_property(footer_label, "modulate:a", 0.0, EXIT_SECONDS * 0.6)
	await WarpTransition.leave(get_tree(), WARP_SECONDS).covered


static func _caret(on: bool) -> String:
	return "▶  " if on else "    "


func _style_button(button: Button, on: bool, choosable: bool) -> void:
	var label: String = ITEMS[_buttons.find(button)][0]
	_style_menu_button(button, on, choosable, label)


## The look of an item of a menu: amber with a hard shadow and a caret when chosen, else
## plain text (dimmed when it cannot be chosen); `label` its text.
func _style_menu_button(button: Button, on: bool, choosable: bool, label: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.ACCENT if on else Color(0, 0, 0, 0)
	style.shadow_color = Color.BLACK if on else Color(0, 0, 0, 0)
	style.shadow_offset = Vector2(4, 4) if on else Vector2.ZERO
	style.shadow_size = 0
	style.anti_aliasing = false
	style.content_margin_left = 12
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	var colour := UiStyle.INK if on else (UiStyle.TEXT if choosable else UiStyle.BORDER.lightened(0.15))
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(colour_name, colour)
	if not (_loading and on):
		button.text = _caret(on) + label


func _build_menu() -> void:
	var menu := VBoxContainer.new()
	menu.name = "Menu"
	menu.position = Vector2(96, 360)
	menu.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	menu.add_theme_constant_override("separation", 4)
	_design.add_child(menu)
	_menu_box = menu
	for index in ITEMS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(MENU_WIDTH, MENU_ITEM_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", _font_title_medium)
		button.add_theme_font_size_override("font_size", 22)
		button.disabled = not ITEMS[index][1]
		button.mouse_entered.connect(func() -> void:
			if ITEMS[index][1] and _panel == null and not _loading:
				_select(index))
		button.pressed.connect(func() -> void:
			_select(index)
			_choose(index))
		menu.add_child(button)
		_buttons.append(button)


# ------------------------------------------------------------------ panels

func _open_settings() -> void:
	var settings := _read_settings()
	var column := _open_panel("INSTELLINGEN")
	for entry: Array in [["CRT-BEELD", "crt"], ["SCANLIJNEN", "scanlines"]]:
		var setting: String = entry[1]
		var label := func() -> String: return "%s: %s" % [entry[0], "AAN" if settings[setting] else "UIT"]
		_add_panel_item(column, label, func() -> void:
			settings[setting] = not settings[setting]
			_write_settings(settings)
			_apply_crt(settings))
	_add_panel_item(column, func() -> String: return "TERUG", _close_panel)
	_select_in_panel(0, false)


## The credits roll: every role in the making of the game, each with the same name under
## it, rolling up through a window of the panel (CREDITS_HEIGHT high) at CREDITS_SPEED
## pixels a second, over and over; the fonts and the engine at the end.
const CREDITS_NAME := "Diederick Lawson"


const CREDITS_ROLES := [
	"Bedacht door", "Geschreven door", "Regie", "Spelontwerp", "Programmering",
	"Voxelkunst", "Stadsplanning", "Tramdienstregeling", "Verkeerslichten",
	"Trekkerchoreografie", "Politie-inzet", "Brandweer en blusmiddelen", "Meeuwengedrag",
	"Muziekkeuze", "Geluidseffecten", "Plat Haags", "Statiegeldadministratie",
	"Winkelwagenonderhoud", "Stuntzwerver", "Catering (broodjes bal)", "Kwaliteitscontrole",
	"Koffie", "Met dank aan",
]


const CREDITS_HEIGHT := 240.0


const CREDITS_SPEED := 28.0


func _open_credits() -> void:
	var column := _open_panel("CREDITS")
	_panel.position.y = 250   # higher than the settings: the roll is tall
	var window := Control.new()
	window.custom_minimum_size = Vector2(PANEL_WIDTH, CREDITS_HEIGHT)
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(window)
	var roll := VBoxContainer.new()
	roll.add_theme_constant_override("separation", 4)
	roll.position = Vector2(0, CREDITS_HEIGHT)
	roll.size = Vector2(PANEL_WIDTH, 0)
	window.add_child(roll)
	for role: String in CREDITS_ROLES:
		roll.add_child(_credits_line(role.to_upper(), _font_pixel, 11, MUTED_TEXT))
		roll.add_child(_credits_line(CREDITS_NAME, _font_body, 15, SOFT_TEXT))
		roll.add_child(_credits_gap(14))
	for line in ["Lettertypen: Silkscreen, Pixelify Sans,", "JetBrains Mono (SIL Open Font License)",
			"Engine: Godot (MIT-licentie)"]:
		roll.add_child(_credits_line(line, _font_body, 12, MUTED_TEXT))
	_add_panel_item(column, func() -> String: return "TERUG", _close_panel)
	_select_in_panel(0, false)
	# once laid out (its height known): roll it from under the window to above it, again
	# and again, as long as the panel is open (the tween goes with the roll)
	await get_tree().process_frame
	if not is_instance_valid(roll):
		return
	var travel := CREDITS_HEIGHT + roll.get_combined_minimum_size().y
	var rolling := roll.create_tween().set_loops()
	rolling.tween_property(roll, "position:y", -roll.get_combined_minimum_size().y, travel / CREDITS_SPEED).from(CREDITS_HEIGHT)


func _credits_line(line: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = line
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _credits_gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


## A panel beside the menu (as the save preview of the design): a bordered ink box with a
## hard shadow and a title; returns the column to fill.
func _open_panel(title: String) -> VBoxContainer:
	_close_panel()
	_panel_selected = 0
	var holder := Control.new()
	holder.position = Vector2(500, 360)
	_design.add_child(holder)
	var shadow := ColorRect.new()
	shadow.color = Color.BLACK
	shadow.position = Vector2(6, 6)
	holder.add_child(shadow)
	var box := PanelContainer.new()
	var style := UiStyle.box_style(Color(11.0 / 255.0, 13.0 / 255.0, 26.0 / 255.0, 0.92), UiStyle.BORDER, 3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = Vector2(340, 0)
	holder.add_child(box)
	box.resized.connect(func() -> void: shadow.size = box.size)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	box.add_child(column)
	column.add_child(_small(title, MUTED_TEXT))
	_panel = holder
	return column


const MUTED_TEXT := Color("#9AA0C8")


func _close_panel() -> void:
	if _panel:
		UiSounds.play(self, "terug")
		_panel.queue_free()
		_panel = null
		_panel_buttons.clear()
		_panel_labels.clear()
		_panel_actions.clear()


# ------------------------------------------------------------------ sub menus

## The items of the open sub menu (settings, credits): buttons styled as the main menu's,
## their text (a Callable: it may change, "AAN"/"UIT") and what choosing them does.
var _panel_buttons: Array[Button] = []


var _panel_labels: Array[Callable] = []


var _panel_actions: Array[Callable] = []


var _panel_selected := 0


const PANEL_WIDTH := 300.0


func _add_panel_item(column: VBoxContainer, label: Callable, action: Callable) -> void:
	var index := _panel_buttons.size()
	var button := Button.new()
	button.custom_minimum_size = Vector2(PANEL_WIDTH, MENU_ITEM_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font_title_medium)
	button.add_theme_font_size_override("font_size", 20)
	button.mouse_entered.connect(func() -> void: _select_in_panel(index))
	button.pressed.connect(func() -> void:
		_select_in_panel(index, false)
		_choose_in_panel(index))
	column.add_child(button)
	_panel_buttons.append(button)
	_panel_labels.append(label)
	_panel_actions.append(action)


func _select_in_panel(index: int, audible := true) -> void:
	if audible and index != _panel_selected:
		UiSounds.play(self, "kies")
	_panel_selected = index
	for button_index in _panel_buttons.size():
		_style_menu_button(_panel_buttons[button_index], button_index == index, true, _panel_labels[button_index].call())


func _choose_in_panel(index: int) -> void:
	if index < 0 or index >= _panel_actions.size():
		return
	var action := _panel_actions[index]
	var closes: bool = _panel_labels[index].call() == "TERUG"
	if not closes:
		UiSounds.play(self, "doe")
	action.call()
	if _panel != null and not closes:
		_select_in_panel(_panel_selected, false)   # the text may have changed (AAN/UIT)


# ------------------------------------------------------------------ settings

static func _read_settings() -> Dictionary:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return {"crt": config.get_value("beeld", "crt", true), "scanlines": config.get_value("beeld", "scanlijnen", true)}


static func _write_settings(settings: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("beeld", "crt", settings.crt)
	config.set_value("beeld", "scanlijnen", settings.scanlines)
	config.save(SETTINGS_PATH)


func _apply_crt(settings: Dictionary) -> void:
	var material := _crt.material as ShaderMaterial
	material.set_shader_parameter("curvature", 0.05 if settings.crt else 0.0)
	material.set_shader_parameter("corner", 0.035 if settings.crt else 0.0)
	material.set_shader_parameter("scanline_strength", 0.1 if settings.scanlines else 0.0)


# ------------------------------------------------------------------ the picture

func _build_title() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(96, 96)
	column.add_theme_constant_override("separation", 10)
	_design.add_child(column)
	_title_column = column
	column.add_child(_small("EEN ZWERFTOCHT", UiStyle.ACCENT, 13, 6))
	var title := Label.new()
	title.text = "ZWERVR"
	title.add_theme_font_override("font", _font_title)
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", TITLE_COLOUR)
	title.add_theme_color_override("font_shadow_color", UiStyle.INK)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 0)
	column.add_child(title)


func _build_footer() -> void:
	var keys := _small("[↑↓] KIEZEN      [ENTER] KIES      [ESC] TERUG", SOFT_TEXT)
	keys.position = Vector2(96, 720 - 32 - 16)
	_design.add_child(keys)
	var version := _small("%s - ZWERVR" % VERSION, MUTED_TEXT)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.size = Vector2(400, 16)
	version.position = Vector2(1280 - 32 - 400, 720 - 32 - 16)
	_design.add_child(version)
	_footer = [keys, version]


## A line of small pixel text (Silkscreen), optionally letter-spaced.
func _small(text: String, colour: Color, size := 11, spacing := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiStyle.spaced(_font_pixel, spacing) if spacing > 0 else _font_pixel)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fit_to_window() -> void:
	var window := get_viewport().get_visible_rect().size
	var factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	_design.scale = Vector2(factor, factor)
	_design.position = (window - DESIGN_SIZE * factor) * 0.5
	if _crt:
		(_crt.material as ShaderMaterial).set_shader_parameter("screen_size", window)


func _load_fonts() -> void:
	var fallback: Font = load(UiStyle.FONT_FALLBACK)
	var title := UiStyle.font(UiStyle.FONT_TITLE)
	_font_title = UiStyle.weighted(title, 700)
	_font_title_medium = UiStyle.weighted(title, 600)
	_font_pixel = UiStyle.font(UiStyle.FONT_PIXEL)
	var body := UiStyle.font(UiStyle.FONT_BODY)
	_font_body = UiStyle.weighted(body, 400)
	# the ▶ and arrows the pixel fonts may lack come from JetBrains Mono
	if body != fallback:
		var fallbacks: Array[Font] = [body]
		for font: Font in [title, _font_pixel]:
			if font != fallback:
				font.fallbacks = fallbacks
