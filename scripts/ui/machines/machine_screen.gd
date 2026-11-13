extends CanvasLayer
## The close-up of a machine, a 3D scene of its own (as the lift ride): the swipe, and you see
## yourself (a stand-in of your character, PlayerModel) standing at the machine, its voxel
## model (machine_parts: MachineModels, or the tile of the OV machine) against a wall over the
## pavement or the floor of the shop (`backdrop`), the camera over your shoulder sliding in
## close as it opens (CAMERA_FROM, CAMERA_AT), the plain light of the portraits and the glow of
## its screen. On that screen what the machine says (show_display: a title and lines in
## `screen_colour` on dark glass, drawn in a little picture of its own laid on the model's
## screen, as on a little CRT) and, on a machine with a touch screen, its buttons beside them
## (build_controls: a keypad, choices): you click them on the screen itself (the click is
## carried from the 3D screen into its picture, _screen_point). Parts of the machine itself
## can be clicked too (machine_parts "hotspots": the hole of the deposit machine, its BON
## key; hotspot_pressed). The camera comes in close on the part you use (machine_parts
## "focus"). A key pressed lights up at its keypad (press_feedback); what comes out (the bon,
## the money, the card: show_tray) slides out of its slot as a little thing of its own, and
## is listed in the panel on the left, under it what you carry (pocket_lines) and the keys. In the pixel look of
## the HUD (UiStyle: hard panels, the pixel fonts, the CRT over it). The game is paused
## meanwhile (the scene keeps moving). Esc leaves (cancel), then the swipe back and `finished`.
## The machines: DepositMachineScreen (statiegeld, the supermarkets), OvMachineScreen
## (OV-chipkaart, Den Haag Centraal and tram stops), CashMachineScreen (the cash machines in
## the town); their sounds are MachineSounds.
##   CashMachineScreen.show_for(player)       # each has its own show_for
## `animate` false (the checks): no swipe, no waiting, the steps at once.

signal finished

const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const MachineSounds = preload("res://scripts/ui/machines/machine_sounds.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")

const NODE_NAME := "Automaatscherm"
## The look of the machine's screen: a little CRT (no scanlines).
const DISPLAY_SHADER := preload("res://scripts/ui/machines/machine_display.gdshader")
const DESIGN_SIZE := Vector2(1280, 720)
const LAYER := 90
const TRAY_RECT := Rect2(40, 40, 300, 330)
const POCKETS_RECT := Rect2(40, 390, 300, 270)
const CONTROLS_RECT := Rect2(920, 40, 320, 620)
const GLASS := Color("#0A1410")
## The scene (metres, the machine's front at its origin facing +z): where you stand before it
## and the camera, from a little back to close in over your right shoulder as it opens.
const STAND_AT := Vector3(-0.42, 0.0, 0.62)
const CAMERA_FROM := Vector3(0.95, 1.7, 2.6)
const CAMERA_AT := Vector3(0.42, 1.45, 1.25)
const LOOK_AT := Vector3(-0.05, 1.05, 0.0)
const CAMERA_SLIDE := 0.8
const CAMERA_FOV := 42.0
## The close-up on the part you use (machine_parts "focus"): its share of the height of the
## view (unless the machine gives "focus_share"), the most of the width it may take, and
## where its middle is across the window (px: right of the panels on the left).
const FOCUS_SHARE := 0.6
const FOCUS_WIDTH_SHARE := 0.62
const FOCUS_CENTRE_X := 790.0
## The picture on the screen: its width (px; the height follows the screen), the width of
## the column of buttons beside the text on a touch screen, the size of a button's text and
## its height.
const DISPLAY_WIDTH := 720
const SCREEN_CONTROLS_WIDTH := 300.0
const SCREEN_BUTTON_TEXT := 18
const SCREEN_BUTTON_HEIGHT := 46.0
## The wall and the ground of each backdrop: its colour and the colour of its joints.
const BACKDROPS := {
	"straat": {"wall": Color("#8A4A3A"), "joint": Color("#B8A898"), "ground": Color("#8C8A92"), "ground_joint": Color("#6E6C76"), "brick": true},
	"supermarkt": {"wall": Color("#E8E4DA"), "joint": Color("#C8C2B4"), "ground": Color("#D8D2C4"), "ground_joint": Color("#B8B0A0"), "brick": false},
	"station": {"wall": Color("#C8C4BC"), "joint": Color("#9A968E"), "ground": Color("#6A6A70"), "ground_joint": Color("#56565C"), "brick": false},
}
## How long the light of a key shines, and what slides out of the slot (seconds, metres).
const PRESS_SECONDS := 0.18
const SLIDE_SECONDS := 0.6
const SLIDE_OUT := 0.12
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
## The wall and ground behind it (BACKDROPS): the street, a supermarket, the station.
var backdrop := "straat"

var font_title: Font
var font_pixel: Font
var font_body: Font
var _root: Control
var _stage: SubViewport                # the 3D scene
var _camera: Camera3D
var _machine: MeshInstance3D
var _stand_in: Node3D
var _press_light: OmniLight3D
var _came_out: Array[Node3D] = []      # what slid out of the slot (show_tray)
var _parts := {}                       # machine_parts()
var _display_viewport: SubViewport     # the picture on its screen
var _display_title: Label
var _display_text: Label
## The column of the screen's buttons (build_controls), right of its text.
var _controls: VBoxContainer
## The title and the text of the screen (px), set by a machine before it is built; a
## machine with a little screen shows a few big words.
var display_title_size := 28
var display_text_size := 20
## How wide the column of the screen's buttons is (px).
var screen_controls_width := SCREEN_CONTROLS_WIDTH
var _display_holder: Node3D
var _display_mesh: MeshInstance3D
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
	_slide_camera_in()
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


## The model of the machine and where its parts are on it (metres, in the model's space: it
## stands on y = 0, centred, its front facing +z): {"mesh": Mesh, "screen": Rect2 (x and y of
## its lower left corner, its size), "front": z of its front, "screen_sunk": how far the
## screen lies behind the front (m, 0 if left out), "keys": Vector3 (the keypad),
## "slot": Vector3 (where things come out)}. Without one: a box with the parts where a
## machine has them.
func machine_parts() -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75, 1.75, 0.5)
	return {"mesh": mesh, "screen": Rect2(-0.25, 1.0, 0.5, 0.32), "front": 0.25,
		"keys": Vector3(-0.15, 0.75, 0.25), "slot": Vector3(0.0, 0.45, 0.25)}


## A key of the machine pressed: the light at its keypad shines a moment, the key sound.
func press_feedback() -> void:
	if _press_light == null:
		return
	_press_light.light_energy = 1.6
	if animate:
		var fade := _press_light.create_tween()
		fade.tween_property(_press_light, "light_energy", 0.0, PRESS_SECONDS)
	else:
		_press_light.light_energy = 0.0


## The buttons of the machine on its screen, beside its text (a keypad, choices). Nothing:
## the screen only shows (the deposit machine: you use its hole and its BON key).
func build_controls(_box: VBoxContainer) -> void:
	pass


## A part of the machine clicked (machine_parts "hotspots": its "name").
func hotspot_pressed(_hotspot: String) -> void:
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


## What came out of the machine, in the tray on the left: a title and lines; and in the
## scene it slides out of the slot (a slip in `colour`; nothing when the title is empty).
func show_tray(title: String, lines: Array, colour := UiStyle.TEXT) -> void:
	for child in _tray.get_children():
		if child != _tray_title:
			child.queue_free()
	_slide_out(colour if title != "" else Color(0, 0, 0, 0))
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
			press_feedback()
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
	if event is InputEventMouse:
		_mouse(event as InputEventMouse)
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo or _busy:
			return
		if key_event.physical_keycode == KEY_ESCAPE:
			cancel()
		elif _key(key_event.physical_keycode):
			press_feedback()


## The mouse over the machine: on its screen the event goes into the screen's picture (its
## buttons), on a part (hotspots) a click uses it; the hand over both.
func _mouse(event: InputEventMouse) -> void:
	var design := transform.affine_inverse() * event.position
	var on_screen := _screen_point(design)
	var hotspot := _hotspot_at(design)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (on_screen.x >= 0.0 and _controls.get_child_count() > 0) or hotspot != "" else Input.CURSOR_ARROW)
	if on_screen.x >= 0.0 and _controls.get_child_count() > 0:
		var carried := event.duplicate() as InputEventMouse
		carried.position = on_screen
		carried.global_position = on_screen
		_display_viewport.push_input(carried, true)
		get_viewport().set_input_as_handled()
	elif hotspot != "" and event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		get_viewport().set_input_as_handled()
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _busy:
			press_feedback()
			hotspot_pressed(hotspot)


## Where the ray of the camera through `design` (a point of the window, in design pixels)
## meets the plane at `z` (the scene's metres); null when it does not.
func _ray_to_plane(design: Vector2, z: float) -> Variant:
	if _camera == null:
		return null
	var origin := _camera.project_ray_origin(design)
	var way := _camera.project_ray_normal(design)
	if absf(way.z) < 0.0001:
		return null
	var along := (z - origin.z) / way.z
	return origin + way * along if along > 0.0 else null


## The pixel of the screen's picture under `design` (a point of the window), the bulge of
## its glass (machine_display.gdshader) taken into account; (-1, -1) when it is not on it.
func _screen_point(design: Vector2) -> Vector2:
	if _display_mesh == null:
		return Vector2(-1, -1)
	var hit: Variant = _ray_to_plane(design, _display_mesh.global_position.z)
	if hit == null:
		return Vector2(-1, -1)
	var screen: Rect2 = _parts.get("screen", Rect2(-0.25, 1.0, 0.5, 0.32))
	var local: Vector3 = (hit as Vector3) - _display_holder.global_position
	var uv := Vector2((local.x - screen.position.x) / screen.size.x, (screen.position.y + screen.size.y - local.y) / screen.size.y)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	var centred := uv * 2.0 - Vector2.ONE
	var curvature := float((_display_mesh.material_override as ShaderMaterial).get_shader_parameter("curvature"))
	var bent := centred * (Vector2.ONE + curvature * Vector2(centred.y * centred.y, centred.x * centred.x))
	var picture_uv := bent * 0.5 + Vector2(0.5, 0.5)
	if picture_uv.x < 0.0 or picture_uv.y < 0.0 or picture_uv.x > 1.0 or picture_uv.y > 1.0:
		return Vector2(-1, -1)
	return picture_uv * Vector2(_display_viewport.size)


## The name of the part of the machine (machine_parts "hotspots") under `design`, or "".
func _hotspot_at(design: Vector2) -> String:
	var hotspots: Array = _parts.get("hotspots", [])
	if hotspots.is_empty() or _display_holder == null:
		return ""
	var front := float(_parts.get("front", 0.25))
	var hit: Variant = _ray_to_plane(design, _display_holder.global_position.z + front)
	if hit == null:
		return ""
	var local: Vector3 = (hit as Vector3) - _display_holder.global_position
	for hotspot: Dictionary in hotspots:
		if (hotspot.rect as Rect2).has_point(Vector2(local.x, local.y)):
			return String(hotspot.name)
	return ""


func _fit() -> void:
	var window := get_viewport().get_visible_rect().size
	var scale_factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	transform = Transform2D(0.0, Vector2(scale_factor, scale_factor), 0.0, (window - DESIGN_SIZE * scale_factor) * 0.5)


func _build() -> void:
	var backdrop_rect := ColorRect.new()
	backdrop_rect.color = Color.BLACK
	backdrop_rect.size = DESIGN_SIZE * 4.0
	backdrop_rect.position = -DESIGN_SIZE * 1.5
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop_rect)
	_root = Control.new()
	_root.name = "Automaat"
	_root.size = DESIGN_SIZE
	add_child(_root)
	_build_display()
	_build_stage()
	# the tray and your pockets on the left; the buttons of the machine are on its screen
	_tray = _side_panel(TRAY_RECT, "UIT DE AUTOMAAT" + ("  ·  " + place_name if place_name != "" else ""))
	_tray_title = label("", font_pixel, 16, UiStyle.ACCENT)
	_tray.add_child(_tray_title)
	_pockets = _side_panel(POCKETS_RECT, "")
	build_controls(_controls)
	_controls.visible = _controls.get_child_count() > 0
	_style_screen_buttons(_controls)
	_keys_label = label("", font_pixel, 11, UiStyle.TEXT)
	_keys_label.position = Vector2(0, DESIGN_SIZE.y - 32)
	_keys_label.size = Vector2(DESIGN_SIZE.x, 24)
	_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_keys_label.add_theme_constant_override("shadow_offset_x", 2)
	_keys_label.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_child(_keys_label)
	# the CRT over the whole window (its own layer: it bends the picture in window pixels)
	_crt_layer = CanvasLayer.new()
	_crt_layer.layer = LAYER + 1
	_crt_layer.visible = false
	add_child(_crt_layer)
	_crt_layer.add_child(UiStyle.make_crt_overlay(0.03, 0.02, get_viewport().get_visible_rect().size))


## The picture on the machine's screen: the title and the lines on dark glass (show_display),
## as wide as its screen is in proportion.
func _build_display() -> void:
	_parts = machine_parts()
	var screen: Rect2 = _parts.get("screen", Rect2(-0.25, 1.0, 0.5, 0.32))
	_display_viewport = SubViewport.new()
	_display_viewport.name = "Schermbeeld"
	_display_viewport.size = Vector2i(DISPLAY_WIDTH, maxi(roundi(DISPLAY_WIDTH * screen.size.y / maxf(screen.size.x, 0.01)), 180))
	_display_viewport.disable_3d = true
	_display_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_display_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_root.add_child(_display_viewport)
	var glass := PanelContainer.new()
	var glass_style := UiStyle.box_style(GLASS, Color("#1A1C22"), 6)
	# margins a little wider than the bulge of the glass takes off at the edges
	glass_style.content_margin_left = 34
	glass_style.content_margin_right = 34
	glass_style.content_margin_top = 26
	glass_style.content_margin_bottom = 26
	glass.add_theme_stylebox_override("panel", glass_style)
	glass.size = Vector2(_display_viewport.size)
	_display_viewport.add_child(glass)
	var glass_column := VBoxContainer.new()
	glass_column.add_theme_constant_override("separation", 10)
	_display_title = label("", font_pixel, display_title_size, screen_colour)
	_display_text = label("", font_pixel, display_text_size, screen_colour)
	glass_column.add_child(_display_title)
	# the text, and on a touch screen the column of its buttons beside it
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_display_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_display_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_display_text)
	_controls = VBoxContainer.new()
	_controls.name = "Knoppen"
	_controls.add_theme_constant_override("separation", 8)
	_controls.custom_minimum_size.x = screen_controls_width
	body.add_child(_controls)
	glass_column.add_child(body)
	glass.add_child(glass_column)


## The buttons on the screen a size to be read there (button makes them for the panels).
func _style_screen_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			(child as Button).add_theme_font_size_override("font_size", SCREEN_BUTTON_TEXT)
			(child as Button).custom_minimum_size.y = SCREEN_BUTTON_HEIGHT
			(child as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_screen_buttons(child)


## The 3D scene: its own world behind everything, the wall and the ground, the machine with
## its screen, the light, you standing at it, the camera.
func _build_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "Scene"
	container.stretch = true
	container.size = DESIGN_SIZE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(container)
	_stage = SubViewport.new()
	GraphicsSettings.plain_3d(_stage)
	_stage.own_world_3d = true
	_stage.msaa_3d = Viewport.MSAA_DISABLED
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#101220")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#9A9AA4")
	environment.environment.ambient_light_energy = 0.4
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.light_color = Color("#FFF2E0")
	key.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	key.shadow_enabled = true
	key.shadow_bias = 0.02
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 8.0
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.3
	fill.light_color = Color("#D8E0F0")
	fill.rotation_degrees = Vector3(-10.0, -50.0, 0.0)
	_stage.add_child(fill)
	_build_backdrop()
	# the machine, its back against the wall, its front at z = 0
	var front := float(_parts.get("front", 0.25))
	var holder := Node3D.new()
	holder.name = "Automaat"
	holder.position = Vector3(0.0, 0.0, -front)
	_stage.add_child(holder)
	_display_holder = holder
	_machine = MeshInstance3D.new()
	_machine.name = "Model"
	_machine.mesh = _parts.get("mesh")
	holder.add_child(_machine)
	# its screen: the picture of the display, lit by itself, and its glow on you
	var screen: Rect2 = _parts.get("screen", Rect2(-0.25, 1.0, 0.5, 0.32))
	var display := MeshInstance3D.new()
	display.name = "Scherm"
	var quad := QuadMesh.new()
	quad.size = screen.size
	display.mesh = quad
	# as on a little CRT: bulging, rounded corners, a glow (machine_display.gdshader)
	var display_material := ShaderMaterial.new()
	display_material.shader = DISPLAY_SHADER
	display_material.set_shader_parameter("picture", _display_viewport.get_texture())
	display_material.set_shader_parameter("picture_size", Vector2(_display_viewport.size))
	display.material_override = display_material
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# on the glass, sunk into the machine as far as its screen is (machine_parts "screen_sunk")
	var sunk := float(_parts.get("screen_sunk", 0.0))
	display.position = Vector3(screen.position.x + screen.size.x * 0.5, screen.position.y + screen.size.y * 0.5, front - sunk + 0.004)
	holder.add_child(display)
	_display_mesh = display
	var glow := OmniLight3D.new()
	glow.light_color = screen_colour
	glow.light_energy = 0.5
	glow.omni_range = 1.4
	glow.position = display.position + Vector3(0.0, 0.0, 0.25)
	holder.add_child(glow)
	_press_light = OmniLight3D.new()
	_press_light.name = "Toetslicht"
	_press_light.light_color = trim_colour.lerp(Color.WHITE, 0.4)
	_press_light.light_energy = 0.0
	_press_light.omni_range = 0.35
	_press_light.position = (_parts.get("keys", Vector3(-0.15, 0.75, front)) as Vector3) + Vector3(0.0, 0.0, 0.08)
	holder.add_child(_press_light)
	_make_stand_in()
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_stage.add_child(_camera)
	_camera.position = CAMERA_AT
	_camera.look_at_from_position(CAMERA_AT, LOOK_AT, Vector3.UP)
	_camera.make_current()


## The wall the machine stands against and the ground before it (BACKDROPS): boxes in the
## colour of the place, the joints of the bricks or panels and of the tiles laid over them.
func _build_backdrop() -> void:
	var look: Dictionary = BACKDROPS.get(backdrop, BACKDROPS.straat)
	var front := float(_parts.get("front", 0.25))
	var wall_z := -front * 2.0 - 0.02
	_stage.add_child(_box_of(Vector3(8.0, 4.0, 0.2), Vector3(0.0, 2.0, wall_z - 0.1), look.wall))
	_stage.add_child(_box_of(Vector3(8.0, 0.1, 6.0), Vector3(0.0, -0.05, wall_z + 3.0), look.ground))
	var brick := bool(look.brick)
	var course := 0.0625 * 2.0 if brick else 0.5
	for row in int(4.0 / course):
		var height := row * course
		_stage.add_child(_box_of(Vector3(8.0, 0.012, 0.01), Vector3(0.0, height, wall_z + 0.005), look.joint))
		var step := 0.25 if brick else 1.0
		var offset := (step * 0.5 if row % 2 == 1 else 0.0) if brick else 0.0
		var column := -4.0 + offset
		while column < 4.0:
			_stage.add_child(_box_of(Vector3(0.012, course, 0.01), Vector3(column, height + course * 0.5, wall_z + 0.005), look.joint))
			column += step
	for line in 13:
		var along := -3.0 + line * 0.5
		_stage.add_child(_box_of(Vector3(8.0, 0.004, 0.012), Vector3(0.0, 0.002, wall_z + along + 3.0), look.ground_joint))
		_stage.add_child(_box_of(Vector3(0.012, 0.004, 6.0), Vector3(along, 0.002, wall_z + 3.0), look.ground_joint))


static func _box_of(box_size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	instance.material_override = material
	instance.position = at
	return instance


## You, standing at the machine, turned to it (as the lift's stand-in).
func _make_stand_in() -> void:
	var model := PlayerModel.new()
	model.name = "Speler"
	model.archetype_id = PlayerCharacter.current_id()
	model.figure_scale = float(player.get("FIGURE_SCALE")) if player and player.get("FIGURE_SCALE") != null else 0.78
	model.backpack = bool(player.get("has_backpack")) if player and player.get("has_backpack") != null else false
	model.idle = true
	_stage.add_child(model)
	model.position = STAND_AT
	model.rotation.y = PI + 0.35   # facing the machine (-z), a little towards its middle
	_stand_in = model


## The camera from a little back, over your shoulder, in close on the part you use
## (_close_up) as the machine comes up.
func _slide_camera_in() -> void:
	if _camera == null:
		return
	var close: Array = _close_up()
	var close_at: Vector3 = close[0]
	var close_look: Vector3 = close[1]
	if not animate:
		_camera.look_at_from_position(close_at, close_look, Vector3.UP)
		return
	_camera.look_at_from_position(CAMERA_FROM, LOOK_AT, Vector3.UP)
	var slide := _camera.create_tween()
	slide.tween_method(func(share: float) -> void:
		_camera.look_at_from_position(CAMERA_FROM.lerp(close_at, share), LOOK_AT.lerp(close_look, share), Vector3.UP),
		0.0, 1.0, CAMERA_SLIDE * 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Where the camera stands and looks for the close-up: straight before the part you use
## (machine_parts "focus", else its screen), far enough off for it to take FOCUS_SHARE of the
## height of the view (or FOCUS_WIDTH_SHARE of its width), its middle at FOCUS_CENTRE_X.
## [position, point looked at].
func _close_up() -> Array:
	var focus: Rect2 = _parts.get("focus", _parts.get("screen", Rect2(-0.25, 1.0, 0.5, 0.32)))
	var share := float(_parts.get("focus_share", FOCUS_SHARE))
	var tangent := tan(deg_to_rad(CAMERA_FOV * 0.5))
	var aspect := DESIGN_SIZE.x / DESIGN_SIZE.y
	var distance := maxf(focus.size.y / (share * 2.0 * tangent), focus.size.x / (FOCUS_WIDTH_SHARE * 2.0 * tangent * aspect))
	var metres_per_pixel := 2.0 * distance * tangent / DESIGN_SIZE.y
	var aside := (FOCUS_CENTRE_X - DESIGN_SIZE.x * 0.5) * metres_per_pixel
	var middle := Vector3(focus.get_center().x, focus.get_center().y, 0.0)
	var look := middle - Vector3(aside, 0.0, 0.0)
	return [look + Vector3(0.0, 0.0, distance), look]


## Something slides out of the slot (a slip in `colour`: the bon, the notes, the card); the
## last one before it goes.
func _slide_out(colour: Color) -> void:
	for earlier in _came_out:
		if is_instance_valid(earlier):
			earlier.queue_free()
	_came_out.clear()
	if colour.a == 0.0 or _machine == null:
		return
	var slot: Vector3 = _parts.get("slot", Vector3(0.0, 0.45, 0.25))
	var slip := _box_of(Vector3(0.16, 0.012, 0.1), slot + Vector3(0.0, 0.0, -0.04), colour)
	(_machine.get_parent() as Node3D).add_child(slip)
	_came_out.append(slip)
	if animate:
		var slide := slip.create_tween()
		slide.tween_property(slip, "position:z", slot.z + SLIDE_OUT, SLIDE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		slip.position.z = slot.z + SLIDE_OUT


## The scene (for the checks): the machine's model, the stand-in, what came out.
func stage_parts() -> Dictionary:
	return {"machine": _machine, "stand_in": _stand_in, "came_out": _came_out, "camera": _camera,
		"display": _display_viewport}


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
