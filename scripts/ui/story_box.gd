extends Control
## The story box of the HUD (in the style of the design "Dialoog — story missie"): a modal
## for a piece of story, a thought or a mission, in which the text appears word by word as
## in the old adventure games. Over the town (dimmed a little, the game paused):
## - top left a banner with what it belongs to ("PROLOOG", "MISSIE 1") and its title;
## - top right the keys;
## - at the bottom the box: on the left a thumbnail of who speaks (PlayerPortrait: the chosen
##   figure in 3D; for a story page the narrator, the outline of someone unknown,
##   NARRATOR_FIGURE as a silhouette) in a frame in the colour of the page, on the right the
##   text with a name tag over it. The text types itself out (Typewriter: word by word, a
##   block cursor after it, the text blip); when a page is all there a ▼ blinks.
## Space, Enter or a click: the rest of the page at once, or (when it is all there) the next
## page; after the last the box closes, the game goes on and `finished` fires.
## A page is a Dictionary:
##   "kind": "verhaal" (story, amber), "gedachte" (a thought: teal, the text in quotes and
##           lighter) or "missie" (a new mission: amber, tag "NIEUWE MISSIE");
##   "text": the text; "speaker": the name tag (default: the player's name, "VERTELLER" for
##   a story page); "banner" / "banner_kind": the banner (kept from the page before if left out).
## The HUD makes it (show_story) and hands it its key presses (handle_input), as its picture
## takes no input of its own.

signal finished

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")

## The narrator's portrait: this figure as a silhouette (only its outline, a little lighter
## than the frame's ink), so you see someone without knowing who.
const NARRATOR_FIGURE := "willem"
const NARRATOR_SILHOUETTE := Color("#2A2E52")
const THOUGHT_COLOUR := Color("#C9CCE6")
const BOX_LEFT := 40.0
const BOX_BOTTOM := 32.0
const BOX_HEIGHT := 200.0
const PORTRAIT_WIDTH := 180.0
const TEXT_SIZE := 18

## Fonts, set by the HUD before it is added.
var font_title: Font
var font_pixel: Font
var font_body: Font
var player_name := ""

var _pages: Array = []
var _page_index := 0
var _typewriter: Typewriter
var _was_paused := false
var _blink_clock := 0.0
var _dim: ColorRect
var _banner: PanelContainer
var _banner_kind: Label
var _banner_title: Label
var _banner_diamond: ColorRect
var _portrait_frame: Panel
var _portrait: SubViewportContainer
var _text_panel: Panel
var _name_tag: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _more: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


## True while the box is open.
func is_showing() -> bool:
	return visible


## Opens the box with these pages (see the top); `done` is called after the last.
func show_pages(pages: Array, done := Callable()) -> void:
	if pages.is_empty():
		if done.is_valid():
			done.call()
		return
	_pages = pages
	_page_index = 0
	if done.is_valid():
		finished.connect(done, CONNECT_ONE_SHOT)
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
		_portrait = PlayerPortrait.new()
		_portrait.archetype_id = PlayerCharacter.current_id()
		_portrait.zoom = 0.55
		_portrait.position = Vector2(3, 3)
		_portrait.size = Vector2(PORTRAIT_WIDTH - 6, BOX_HEIGHT - 6)
		_portrait_frame.add_child(_portrait)
		UiSounds.play(self, "doe", -4.0)
	_show_page()


## A key press while open: true if the box used it.
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	var go_on: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE) \
		or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if go_on:
		if not _typewriter.is_done():
			_typewriter.finish()
		else:
			_next_page()
	# every key is the box's while it is open (no pause menu, no game menu under it)
	return event is InputEventKey or event is InputEventMouseButton


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_clock += delta
	_typewriter.update(delta)
	_more.visible = _typewriter.is_done() and fmod(_blink_clock, 0.8) < 0.5


func _show_page() -> void:
	var page: Dictionary = _pages[_page_index]
	var kind := String(page.get("kind", "verhaal"))
	var accent := UiStyle.SIDE_ACCENT if kind == "gedachte" else UiStyle.ACCENT
	var text := String(page.get("text", ""))
	if kind == "gedachte":
		text = "“" + text + "”"
	_text.add_theme_color_override("default_color", THOUGHT_COLOUR if kind == "gedachte" else UiStyle.TEXT)
	_typewriter.cursor_colour = accent
	_show_speaker(kind == "verhaal")
	var default_speaker := "VERTELLER" if kind == "verhaal" else ("NIEUWE MISSIE" if kind == "missie" else player_name)
	_name_label.text = String(page.get("speaker", default_speaker))
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = accent
	tag_style.shadow_color = UiStyle.INK
	tag_style.shadow_offset = Vector2(4, 4)
	tag_style.anti_aliasing = false
	tag_style.content_margin_left = 14
	tag_style.content_margin_right = 14
	tag_style.content_margin_top = 4
	tag_style.content_margin_bottom = 4
	_name_tag.add_theme_stylebox_override("panel", tag_style)
	_portrait_frame.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.PANEL, accent, 3))
	if page.has("banner"):
		_banner_title.text = String(page.banner)
		_banner_kind.text = String(page.get("banner_kind", ""))
	_banner.visible = _banner_title.text != ""
	_banner_kind.add_theme_color_override("font_color", accent)
	_banner_diamond.color = accent
	_typewriter.start(text)
	_blink_clock = 0.0


## The portrait: the player, or for a story page the narrator (a silhouette of someone).
func _show_speaker(narrator: bool) -> void:
	if _portrait == null:
		return
	var wanted := NARRATOR_FIGURE if narrator else PlayerCharacter.current_id()
	var wanted_silhouette := NARRATOR_SILHOUETTE if narrator else Color(0, 0, 0, 0)
	if _portrait.archetype_id != wanted:
		_portrait.archetype_id = wanted
	if _portrait.silhouette != wanted_silhouette:
		_portrait.silhouette = wanted_silhouette


func _next_page() -> void:
	_page_index += 1
	if _page_index < _pages.size():
		UiSounds.play(self, "kies", -6.0)
		_show_page()
		return
	UiSounds.play(self, "terug", -4.0)
	visible = false
	if _portrait:
		_portrait.queue_free()
		_portrait = null
	get_tree().paused = _was_paused
	finished.emit()


# ------------------------------------------------------------------ building

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(UiStyle.INK, 0.35)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	# the banner, top left
	_banner = PanelContainer.new()
	var banner_style := UiStyle.box_style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, 2)
	banner_style.content_margin_left = 14
	banner_style.content_margin_right = 14
	banner_style.content_margin_top = 8
	banner_style.content_margin_bottom = 8
	_banner.add_theme_stylebox_override("panel", banner_style)
	_banner.position = Vector2(24, 24)
	add_child(_banner)
	var banner_row := HBoxContainer.new()
	banner_row.add_theme_constant_override("separation", 12)
	_banner.add_child(banner_row)
	var diamond_box := Control.new()
	diamond_box.custom_minimum_size = Vector2(14, 14)
	diamond_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_banner_diamond = ColorRect.new()
	_banner_diamond.size = Vector2(10, 10)
	_banner_diamond.position = Vector2(2, 2)
	_banner_diamond.pivot_offset = Vector2(5, 5)
	_banner_diamond.rotation_degrees = 45.0
	diamond_box.add_child(_banner_diamond)
	banner_row.add_child(diamond_box)
	_banner_kind = _make_label("", font_pixel, 12, UiStyle.ACCENT)
	_banner_kind.add_theme_constant_override("outline_size", 0)
	banner_row.add_child(_banner_kind)
	_banner_title = _make_label("", font_body, 13, UiStyle.TEXT)
	banner_row.add_child(_banner_title)
	# the keys, top right
	var keys_panel := PanelContainer.new()
	var keys_style := UiStyle.box_style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, 2)
	keys_style.content_margin_left = 12
	keys_style.content_margin_right = 12
	keys_style.content_margin_top = 10
	keys_style.content_margin_bottom = 10
	keys_panel.add_theme_stylebox_override("panel", keys_style)
	keys_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	keys_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	keys_panel.position = Vector2(-24, 24)
	keys_panel.add_child(_make_label("[SPATIE] VERDER", font_pixel, 11, UiStyle.TEXT))
	add_child(keys_panel)
	# the box: the portrait on the left, the text on the right
	var box := Control.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = BOX_LEFT
	box.offset_right = -BOX_LEFT
	box.offset_top = -BOX_BOTTOM - BOX_HEIGHT
	box.offset_bottom = -BOX_BOTTOM
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_portrait_frame = Panel.new()
	_portrait_frame.position = Vector2.ZERO
	_portrait_frame.size = Vector2(PORTRAIT_WIDTH, BOX_HEIGHT)
	_portrait_frame.clip_contents = true
	box.add_child(_portrait_frame)
	_text_panel = Panel.new()
	var text_style := UiStyle.box_style(Color(UiStyle.INK, 0.92), UiStyle.BORDER, 3)
	text_style.border_width_left = 0
	text_style.shadow_color = UiStyle.INK
	text_style.shadow_offset = Vector2(6, 6)
	_text_panel.add_theme_stylebox_override("panel", text_style)
	_text_panel.anchor_right = 1.0
	_text_panel.anchor_bottom = 1.0
	_text_panel.offset_left = PORTRAIT_WIDTH
	box.add_child(_text_panel)
	_text = RichTextLabel.new()
	_text.add_theme_font_override("normal_font", font_body)
	_text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_text.add_theme_color_override("default_color", UiStyle.TEXT)
	_text.add_theme_constant_override("line_separation", 8)
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.anchor_right = 1.0
	_text.anchor_bottom = 1.0
	_text.offset_left = 28
	_text.offset_top = 34
	_text.offset_right = -48
	_text.offset_bottom = -18
	_text_panel.add_child(_text)
	_typewriter = Typewriter.new(_text, self)
	_typewriter.blink_when_done = false
	_name_tag = PanelContainer.new()
	_name_tag.position = Vector2(20, -20)
	_name_label = _make_label("", font_title, 18, UiStyle.INK)
	_name_label.add_theme_constant_override("outline_size", 0)
	_name_tag.add_child(_name_label)
	_text_panel.add_child(_name_tag)
	_more = _make_label("▼", font_body, 16, UiStyle.ACCENT)
	_more.anchor_left = 1.0
	_more.anchor_right = 1.0
	_more.anchor_top = 1.0
	_more.anchor_bottom = 1.0
	_more.offset_left = -40
	_more.offset_top = -36
	_more.offset_right = -20
	_more.offset_bottom = -14
	_text_panel.add_child(_more)


func _make_label(text: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
