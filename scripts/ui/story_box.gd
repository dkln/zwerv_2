extends Control
## The story box of the HUD (in the style of the design "Dialoog — story missie"): a modal
## for a piece of story, a thought or a mission, in which the text appears word by word as
## in the old adventure games. Over the town (dimmed a little, the game paused):
## - top left a banner with what it belongs to ("PROLOOG", "MISSIE 1") and its title;
## - top right the keys;
## - at the bottom the box: on the left a thumbnail of the player (PlayerPortrait, the
##   chosen figure in 3D) in a frame in the colour of the page, on the right the text with a
##   name tag over it; when a page is all there a ▼ blinks.
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

## Seconds between two words, and the extra rest after a sentence or a comma.
const WORD_SECONDS := 0.075
const SENTENCE_REST := 0.32
const COMMA_REST := 0.12
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
var _word_ends: Array[int] = []     # visible characters at the end of each word
var _words_shown := 0
var _word_clock := 0.0
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
var _text: Label
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
		if _words_shown < _word_ends.size():
			_words_shown = _word_ends.size()
			_text.visible_characters = -1
		else:
			_next_page()
	# every key is the box's while it is open (no pause menu, no game menu under it)
	return event is InputEventKey or event is InputEventMouseButton


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_clock += delta
	if _words_shown < _word_ends.size():
		_word_clock -= delta
		while _word_clock <= 0.0 and _words_shown < _word_ends.size():
			_words_shown += 1
			_text.visible_characters = _word_ends[_words_shown - 1]
			var last := _text.text.substr(_word_ends[_words_shown - 1] - 1, 1)
			_word_clock += WORD_SECONDS + (SENTENCE_REST if last in [".", "!", "?", ":", "…"] else COMMA_REST if last in [",", ";"] else 0.0)
			if _words_shown % 2 == 1:
				UiSounds.play(self, "woord", -10.0)
		_more.visible = false
	else:
		_more.visible = fmod(_blink_clock, 0.8) < 0.5


func _show_page() -> void:
	var page: Dictionary = _pages[_page_index]
	var kind := String(page.get("kind", "verhaal"))
	var accent := UiStyle.SIDE_ACCENT if kind == "gedachte" else UiStyle.ACCENT
	var text := String(page.get("text", ""))
	if kind == "gedachte":
		text = "“" + text + "”"
	_text.text = text
	_text.add_theme_color_override("font_color", THOUGHT_COLOUR if kind == "gedachte" else UiStyle.TEXT)
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
	_word_ends = _word_ends_of(text)
	_words_shown = 0
	_word_clock = 0.15
	_text.visible_characters = 0
	_blink_clock = 0.0


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


## The number of visible characters at the end of each word (spaces and line ends between).
static func _word_ends_of(text: String) -> Array[int]:
	var ends: Array[int] = []
	var in_word := false
	for index in text.length():
		var is_space := text[index] in [" ", "\n", "\t"]
		if in_word and is_space:
			ends.append(index)
		in_word = not is_space
	if in_word:
		ends.append(text.length())
	return ends


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
	_text = _make_label("", font_body, TEXT_SIZE, UiStyle.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.add_theme_constant_override("line_spacing", 8)
	_text.anchor_right = 1.0
	_text.anchor_bottom = 1.0
	_text.offset_left = 28
	_text.offset_top = 34
	_text.offset_right = -48
	_text.offset_bottom = -18
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text_panel.add_child(_text)
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
