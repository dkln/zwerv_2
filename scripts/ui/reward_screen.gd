extends Control
## The reward screen of the HUD (GameHud.show_reward): what you got for a task or a mission
## done (Story) or from someone in the street (Conversations: a "beloning"), in a screen of
## its own that you press away. Over the dimmed world (the game paused) one panel in the
## style of the HUD (UiStyle: INK panel, BORDER frame, ACCENT, the pixel fonts):
## - at the top what it is for ("TAAK VOLBRACHT", "MISSIE VOLBRACHT", "GEKREGEN") and from
##   what or whom (the task, the mission, "Van de toerist");
## - in the middle the item big, its voxel model turning slowly round (ItemView), light rays
##   turning behind it (LightRays, as behind a new mission), in a frame in the colour of its
##   rarity; without an item (only experience) the XP big in their place;
## - under it the name of the item in the colour of its rarity, its rarity, and its line
##   (Items "text"); then the chips of what came with it ("+50 XP", "2 x");
## - at the bottom "[ENTER] OK".
## With more than one item, one page each (the XP on the first); Enter, Space, E, Escape or
## a click goes on, the last closes and `finished` fires. Opening plays the reward jingle
## (the HUD: REWARD_JINGLE).
## A reward: {"heading", "title", "xp": int, "items": [{"item": id, "count": int}]}.

signal finished

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const Items = preload("res://scripts/player/items.gd")
const ItemView = preload("res://scripts/ui/widgets/item_view.gd")
const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")

const PANEL_SIZE := Vector2(560, 600)
const PADDING := 24.0
const STAGE_SIZE := Vector2(512, 260)
const XP_COLOUR := Color("#8BE36B")
## Seconds before a key goes on (a key still held from the game does not skip it).
const KEYS_AFTER := 0.35
const RARITY_LABELS := {"gewoon": "GEWOON", "bijzonder": "BIJZONDER", "zeldzaam": "ZELDZAAM",
	"episch": "EPISCH", "legendarisch": "LEGENDARISCH"}

var font_title: Font
var font_pixel: Font
var font_body: Font

var _pages: Array[Dictionary] = []   # per page: {"heading", "title", "xp", "item", "count"}
var _page_index := 0
var _was_paused := false
## Whether the game must stay paused when this closes (another screen still up: the story
## box, the shop, the pause menu; GameHud sets it). Else as it was before it opened.
var keep_paused := Callable()
var _since := 0.0
var _panel: PanelContainer
var _heading: Label
var _title: Label
var _stage_frame: PanelContainer
var _rays: LightRays
var _item_view: ItemView
var _big_xp: Label
var _name: Label
var _rarity: Label
var _text: Label
var _chips: HBoxContainer
var _footer: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_showing() -> bool:
	return visible


## Opens on `reward` (see the top); `done` is called when it is pressed away.
func open(reward: Dictionary, done := Callable()) -> void:
	_pages = pages_of(reward)
	if _pages.is_empty():
		if done.is_valid():
			done.call()
		return
	if done.is_valid():
		finished.connect(done, CONNECT_ONE_SHOT)
	_page_index = 0
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_show_page()


## The pages of `reward`: one for each item (the XP on the first), or one with only the XP.
static func pages_of(reward: Dictionary) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var xp := int(reward.get("xp", 0))
	for entry: Dictionary in reward.get("items", []):
		var item_id := String(entry.get("item", ""))
		if item_id == "":
			continue
		pages.append({"heading": String(reward.get("heading", "BELONING")), "title": String(reward.get("title", "")),
			"xp": xp if pages.is_empty() else 0, "item": item_id, "count": int(entry.get("count", 1))})
	if pages.is_empty() and xp > 0:
		pages.append({"heading": String(reward.get("heading", "BELONING")), "title": String(reward.get("title", "")),
			"xp": xp, "item": "", "count": 0})
	return pages


## The page shown now (for the checks).
func current_page() -> Dictionary:
	return _pages[_page_index] if visible and _page_index < _pages.size() else {}


## The item view (for the checks).
func item_view() -> ItemView:
	return _item_view


## A key press or click while open: true if the screen used it (every key is its own then).
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	var go_on := false
	if event is InputEventKey and event.pressed and not event.echo:
		go_on = (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E, KEY_ESCAPE]
	elif event is InputEventMouseButton and event.pressed:
		go_on = (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if go_on and _since >= KEYS_AFTER:
		next_page()
	return true


## On to the next page, or closed after the last.
func next_page() -> void:
	if not visible:
		return
	_page_index += 1
	if _page_index < _pages.size():
		UiSounds.play(self, "doe", -6.0)
		_show_page()
		return
	visible = false
	get_tree().paused = bool(keep_paused.call()) if keep_paused.is_valid() else _was_paused
	UiSounds.play(self, "terug", -6.0)
	finished.emit()


func _process(delta: float) -> void:
	if visible:
		_since += delta


func _show_page() -> void:
	_since = 0.0
	var page: Dictionary = _pages[_page_index]
	var item_id := String(page.item)
	_heading.text = "◆ " + String(page.heading)
	_title.text = String(page.title)
	_title.visible = _title.text != ""
	var colour := Items.rarity_colour(item_id) if item_id != "" else XP_COLOUR
	_stage_frame.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.INK, colour, 3))
	_rays.colour = Color(colour, 0.12)
	_item_view.visible = item_id != ""
	_big_xp.visible = item_id == ""
	for chip in _chips.get_children():
		_chips.remove_child(chip)
		chip.queue_free()
	if item_id != "":
		var item := Items.item(item_id)
		_item_view.show_item(item_id)
		_name.text = String(item.get("name", item_id)).to_upper()
		_name.add_theme_color_override("font_color", colour)
		_rarity.text = String(RARITY_LABELS.get(String(item.get("rarity", "gewoon")), "GEWOON"))
		_rarity.add_theme_color_override("font_color", colour)
		_text.text = String(item.get("text", ""))
		if int(page.count) > 1:
			_chips.add_child(_chip("%d x" % int(page.count), UiStyle.TEXT))
	else:
		_big_xp.text = "+%d XP" % int(page.xp)
		_name.text = "ERVARING"
		_name.add_theme_color_override("font_color", XP_COLOUR)
		_rarity.text = ""
		_text.text = "Je bent weer wat wijzer geworden op straat."
	if int(page.xp) > 0 and item_id != "":
		_chips.add_child(_chip("+%d XP" % int(page.xp), XP_COLOUR))
	_rarity.visible = _rarity.text != ""
	_chips.visible = _chips.get_child_count() > 0
	_footer.text = "[ENTER] OK" if _page_index == _pages.size() - 1 else "[ENTER] VERDER  %d / %d" % [_page_index + 1, _pages.size()]


# ------------------------------------------------------------------ building

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.name = "Beloning"
	_panel.custom_minimum_size = PANEL_SIZE
	var panel_style := UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, 3)
	panel_style.content_margin_left = PADDING
	panel_style.content_margin_right = PADDING
	panel_style.content_margin_top = PADDING * 0.75
	panel_style.content_margin_bottom = PADDING * 0.75
	panel_style.shadow_color = UiStyle.INK
	panel_style.shadow_offset = Vector2.ONE * UiStyle.SHADOW_OFFSET
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_heading = UiStyle.label("", font_pixel, 16, UiStyle.ACCENT)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_heading)
	_title = UiStyle.label("", font_title, 22, UiStyle.TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	# the stage: the rays, the item turning (or the XP) over them
	_stage_frame = PanelContainer.new()
	_stage_frame.custom_minimum_size = STAGE_SIZE
	_stage_frame.clip_contents = true
	_stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage_frame)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_frame.add_child(stage)
	_rays = LightRays.new()
	_rays.count = 12
	_rays.length = 0.8
	stage.add_child(_rays)
	_item_view = ItemView.new()
	_item_view.name = "Itembeeld"
	_item_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_item_view)
	_big_xp = UiStyle.label("", font_title, 64, XP_COLOUR)
	_big_xp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_xp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big_xp.add_theme_color_override("font_shadow_color", UiStyle.INK)
	_big_xp.add_theme_constant_override("shadow_offset_x", 4)
	_big_xp.add_theme_constant_override("shadow_offset_y", 4)
	stage.add_child(_big_xp)
	_name = UiStyle.label("", font_title, 30, UiStyle.TEXT)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name)
	_rarity = UiStyle.label("", font_pixel, 12, UiStyle.MUTED)
	_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rarity)
	_text = UiStyle.label("", font_body, 16, UiStyle.TEXT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(PANEL_SIZE.x - PADDING * 2.0, 0.0)
	column.add_child(_text)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 10)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_chips)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	_footer = UiStyle.label("[ENTER] OK", font_pixel, 13, UiStyle.MUTED)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_footer)


func _chip(text: String, colour: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.INK, colour, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(UiStyle.label(text, font_pixel, 14, colour))
	return chip
