extends Control
## The story box of the HUD (in the style of the design "Dialoog — story missie"): a modal
## for a piece of story, a thought or a mission, in which the text appears word by word as
## in the old adventure games. Over the town (dimmed a little, the game paused):
## - top left a banner with what it belongs to ("PROLOOG", "MISSIE 1") and its title;
## - top right the keys;
## - at the bottom the box: on the left a thumbnail of who speaks (PlayerPortrait: the chosen
##   figure in 3D; for a story page the narrator, the outline of someone unknown,
##   NARRATOR_FIGURE as a silhouette; for a mission page an emblem of its own,
##   widgets/mission_badge.gd) in a frame in the colour of the page, on the right the
##   text with a name tag over it. The text types itself out (Typewriter: word by word, a
##   block cursor after it, the text blip); when a page is all there a ▼ blinks.
## Space, Enter or a click: the rest of the page at once, or (when it is all there) the next
## page; after the last the box closes, the game goes on and `finished` fires.
## A page is a Dictionary:
##   "kind": "verhaal" (story, amber), "gedachte" (a thought: teal, the text in quotes and
##           lighter) or "missie" (a new mission: amber, tag "NIEUWE MISSIE");
##           or "gesprek" (someone in the street talking to you: amber, the portrait them,
##           "portrait_look", or else the silhouette of someone else, NPC_SILHOUETTE);
##   "text": the text; "speaker": the name tag (default: the player's name, "VERTELLER" for
##   a story page); "banner" / "banner_kind": the banner (kept from the page before if left out);
##   "choices": what you can say back (Array of texts, shown under the text once it is all
##   there; arrows or W/S choose, 1..4 pick at once, Space/Enter/a click says it), with
##   "on_choice": a Callable(index) -> Array of the pages that follow (empty: the box closes).
##   A page with choices splits the text in two (TALK_SPLIT): on the left the conversation,
##   what was said before (dimmed: their lines and what you answered) over the new line, kept
##   scrolling along with the new line as its words appear (FOLLOW_RATE), so what types out
##   is always in view, no mouse wheel needed (▲ on its left while there is more above);
##   on the right the choices. Each scrolls on its own when it does not fit
##   (the mouse wheel too); a yellow arrow blinks on the right while there are more choices
##   below (▼) or above (▲), and choosing scrolls the chosen one into view. The box keeps its
##   height.
##   The conversations with passers-by (scripts/story/conversations.gd) are such pages;
##   "voice" and "mood" (Babble) make them babble while the line types out (in place of the
##   text blip), a question (the line ends in "?") going up at its end; "on_show": a
##   Callable called as the page opens (the speaker's mood: Emote); "portrait_look": the
##   TownsfolkFigure look of who speaks, shown in the portrait (else a silhouette).
## The HUD makes it (show_story) and hands it its key presses (handle_input), as its picture
## takes no input of its own.

signal finished

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")
const Babble = preload("res://scripts/audio/babble.gd")
const MissionBadge = preload("res://scripts/ui/widgets/mission_badge.gd")

## The narrator's portrait: this figure as a silhouette (only its outline, a little lighter
## than the frame's ink), so you see someone without knowing who.
const NARRATOR_FIGURE := "willem"
const NARRATOR_SILHOUETTE := Color("#2A2E52")
const THOUGHT_COLOUR := Color("#C9CCE6")
## Someone in the street: the silhouette in the portrait when there is no look (the page
## has the accent of the HUD, as a story page).
const NPC_SILHOUETTE := Color("#24402C")
const NPC_FIGURE := "jos"
## The choices: blocks as the rows of the quest log (UiStyle: PANEL with a BORDER; the chosen
## one RAISED with an ACCENT border and strip on the left), the text as big as the line
## above, right under it (CHOICE_GAP px) at its left edge.
const CHOICE_SIZE := TEXT_SIZE
const CHOICE_GAP := 12
const CHOICE_STRIP := 6
## A conversation: the share of the text panel's width for the conversation (the rest is
## the choices), and the gap between them.
const TALK_SPLIT := 0.55
const TALK_GAP := 16
## Seconds after a line has typed out that the conversation still follows it (the heights
## settle), and how fast the scroll catches up with the words (1/s).
const FOLLOW_AFTER := 0.6
const FOLLOW_RATE := 12.0
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
var _mission_badge: MissionBadge   # the thumbnail of a mission page, in place of the portrait
var _text_panel: Panel
var _name_tag: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _more: Label
var _choices_box: VBoxContainer
var _choices_scroll: ScrollContainer   # the choices, on the right of a conversation
var _column: VBoxContainer          # what was said before and the text (laid out by Godot)
var _scroll: ScrollContainer        # scrolls the column when it does not fit
var _history_text: RichTextLabel    # what was said before in this conversation, dimmed
var _history: Array[String] = []    # its lines (BBCode)
var _follow_left := 0.0             # seconds the conversation still keeps its newest line in view
var _said_before: Label             # ▲ on the left: more of the conversation above
var _more_below: Label              # the blinking arrows: more to scroll to
var _more_above: Label
var _box: Control                  # the box at the bottom (portrait and text)
var _choice_labels: Array[Label] = []
var _chosen := 0
var _babble: AudioStreamPlayer
var _asked_aloud := false          # the rising babble of a question has played for this page


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
		_history.clear()
	_show_page()


## A key press while open: true if the box used it.
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	var go_on: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE) \
		or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var choices: Array = _current_choices()
	if not choices.is_empty() and _typewriter.is_done() and event is InputEventKey and event.pressed and not event.echo:
		var keycode := (event as InputEventKey).keycode
		if keycode in [KEY_UP, KEY_W]:
			_choose(posmod(_chosen - 1, choices.size()))
			return true
		if keycode in [KEY_DOWN, KEY_S]:
			_choose(posmod(_chosen + 1, choices.size()))
			return true
		if keycode >= KEY_1 and keycode < KEY_1 + choices.size():
			_choose(keycode - KEY_1)
			_say_choice()
			return true
	if go_on:
		if not _typewriter.is_done():
			_typewriter.finish()
		elif not choices.is_empty():
			_say_choice()
		else:
			_next_page()
	# every key is the box's while it is open (no pause menu, no game menu under it)
	return event is InputEventKey or event is InputEventMouseButton


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_clock += delta
	_typewriter.update(delta)
	_update_babble()
	var choosing := not _current_choices().is_empty()
	_more.visible = _typewriter.is_done() and not choosing and fmod(_blink_clock, 0.8) < 0.5
	_choices_box.visible = choosing and _typewriter.is_done()
	# the conversation at its newest line while it types (and a moment after, as heights settle)
	if not _typewriter.is_done():
		_follow_left = FOLLOW_AFTER
	elif _follow_left > 0.0:
		_follow_left -= delta
	var history_room := _column.size.y - _scroll.size.y
	if _follow_left > 0.0 and history_room > 0.0:
		# the line where the words appear now (a line under the share typed) at the bottom
		var typed_to := _text.position.y + _text.size.y * _typewriter.shown_share() + TEXT_SIZE * 0.8
		var wanted := clampf(typed_to - _scroll.size.y, 0.0, history_room)
		var now := float(_scroll.scroll_vertical)
		_scroll.scroll_vertical = int(roundf(lerpf(now, wanted, 1.0 - exp(-FOLLOW_RATE * delta))))
	_said_before.visible = history_room > 1.0 and _scroll.scroll_vertical > 1.0 and fmod(_blink_clock, 0.8) < 0.5
	# more choices to scroll to: a blinking arrow on the right
	var room := _choices_box.size.y - _choices_scroll.size.y if choosing else 0.0
	var blink := fmod(_blink_clock, 0.8) < 0.5
	_more_below.visible = room > 1.0 and _choices_scroll.scroll_vertical < room - 1.0 and blink
	_more_above.visible = room > 1.0 and _choices_scroll.scroll_vertical > 1.0 and blink


## Babble while a line of someone in the street types out (its "voice" and "mood"), one sound
## after the other; a question goes up at its end ("vraag").
func _update_babble() -> void:
	if _page_index >= _pages.size():
		return
	var page: Dictionary = _pages[_page_index]
	if not page.has("voice"):
		return
	if is_instance_valid(_babble) and _babble.playing:
		return
	var question := String(page.get("text", "")).strip_edges().ends_with("?")
	if not _typewriter.is_done():
		var mood := "vraag" if question and _typewriter.words_left() <= 2 else String(page.get("mood", "neutraal"))
		_asked_aloud = _asked_aloud or mood == "vraag"
		_babble = Babble.play_near(self, String(page.voice), mood)
	elif question and not _asked_aloud:
		_asked_aloud = true
		_babble = Babble.play_near(self, String(page.voice), "vraag")


## Scrolls the chosen choice into view (once it has been laid out).
func _scroll_to_choice() -> void:
	if _chosen < _choice_labels.size():
		_choices_scroll.ensure_control_visible(_choice_labels[_chosen].get_parent() as Control)


## A choice's block: the chosen one lit (RAISED, ACCENT border and strip).
static func _choice_style(on: bool) -> StyleBoxFlat:
	var style := UiStyle.box_style(UiStyle.RAISED if on else UiStyle.PANEL, UiStyle.ACCENT if on else UiStyle.BORDER, 2)
	style.border_width_left = CHOICE_STRIP if on else 2
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _current_choices() -> Array:
	if not visible or _page_index >= _pages.size():
		return []
	return (_pages[_page_index] as Dictionary).get("choices", [])


func _choose(index: int) -> void:
	if index != _chosen:
		UiSounds.play(self, "kies", -6.0)
	_chosen = index
	for label_index in _choice_labels.size():
		var label := _choice_labels[label_index]
		var on := label_index == _chosen
		var block := label.get_parent() as PanelContainer
		block.add_theme_stylebox_override("panel", _choice_style(on))
		label.add_theme_color_override("font_color", UiStyle.TEXT if on else UiStyle.MUTED)
	_scroll_to_choice.call_deferred()


## Says the chosen line: the pages that follow from it (on_choice), or the box closes.
func _say_choice() -> void:
	var page: Dictionary = _pages[_page_index]
	# what was said stays in view, dimmed: their line and your answer
	var choices: Array = page.get("choices", [])
	_history.append("[color=#%s]%s: %s[/color]" % [UiStyle.MUTED.to_html(false), String(page.get("speaker", "")),
			_escaped(String(page.get("text", "")))])
	if _chosen < choices.size():
		_history.append("[color=#%s]» %s[/color]" % [UiStyle.ACCENT.darkened(0.15).to_html(false), _escaped(String(choices[_chosen]))])
	var follow: Callable = page.get("on_choice", Callable())
	var next: Array = follow.call(_chosen) if follow.is_valid() else []
	if next.is_empty():
		_page_index = _pages.size() - 1
		_next_page()
		return
	_pages = next
	_page_index = 0
	UiSounds.play(self, "doe", -6.0)
	_show_page()


func _show_page() -> void:
	var page: Dictionary = _pages[_page_index]
	var kind := String(page.get("kind", "verhaal"))
	var accent := UiStyle.SIDE_ACCENT if kind == "gedachte" else UiStyle.ACCENT
	var text := String(page.get("text", ""))
	if kind == "gedachte":
		text = "“" + text + "”"
	_text.add_theme_color_override("default_color", THOUGHT_COLOUR if kind == "gedachte" else UiStyle.TEXT)
	_typewriter.cursor_colour = accent
	_show_speaker(kind == "verhaal", kind == "gesprek", page.get("portrait_look", {}))
	_mission_badge.visible = kind == "missie"
	if _portrait:
		_portrait.visible = kind != "missie"
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
	# babble in place of the text blip for someone in the street
	_typewriter.sound = not page.has("voice")
	_asked_aloud = false
	if is_instance_valid(_babble):
		_babble.stop()
		_babble.queue_free()
	var on_show: Callable = page.get("on_show", Callable())
	if on_show.is_valid():
		on_show.call()
	_typewriter.start(text)
	_blink_clock = 0.0
	# what you can say back, under the text
	for row in _choices_box.get_children():
		_choices_box.remove_child(row)
		row.queue_free()
	_choice_labels.clear()
	_chosen = 0
	var choices: Array = page.get("choices", [])
	for choice_index in choices.size():
		var block := PanelContainer.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := _make_label(String(choices[choice_index]), font_body, CHOICE_SIZE, UiStyle.MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(label)
		_choices_box.add_child(block)
		_choice_labels.append(label)
	_choose(0)
	_choices_box.visible = false
	_choices_scroll.scroll_vertical = 0
	# a conversation: what was said before over the new line, the choices beside them
	var talking := not choices.is_empty()
	if kind != "gesprek":
		_history.clear()
	_history_text.text = "\n".join(_history)
	_history_text.visible = not _history.is_empty()
	_scroll.anchor_right = TALK_SPLIT if talking else 1.0
	_scroll.offset_right = -TALK_GAP * 0.5 if talking else -48.0
	_choices_scroll.visible = talking
	_follow_left = FOLLOW_AFTER


static func _escaped(plain: String) -> String:
	return plain.replace("[", "[lb]")


## The portrait: the player, or for a story page the narrator (a silhouette of someone), for
## someone in the street another silhouette.
func _show_speaker(narrator: bool, someone_else := false, look := {}) -> void:
	if _portrait == null:
		return
	# someone in the street with a look: them, in colour
	if _portrait.townsfolk_look != look:
		_portrait.townsfolk_look = look
	if not look.is_empty():
		_portrait.silhouette = Color(0, 0, 0, 0)
		return
	var wanted := NARRATOR_FIGURE if narrator else (NPC_FIGURE if someone_else else PlayerCharacter.current_id())
	var wanted_silhouette := NARRATOR_SILHOUETTE if narrator else (NPC_SILHOUETTE if someone_else else Color(0, 0, 0, 0))
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
	_box = box
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
	_mission_badge = MissionBadge.new()
	_mission_badge.name = "Missie-embleem"
	_mission_badge.visible = false
	_portrait_frame.add_child(_mission_badge)
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
	_text.fit_content = true
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the text and, under it, the choices: one column, as wide as the panel minus its margins
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", CHOICE_GAP)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # the arrows say it
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.anchor_right = 1.0
	_scroll.anchor_bottom = 1.0
	_scroll.offset_left = 28
	_scroll.offset_top = 34
	_scroll.offset_right = -48
	_scroll.offset_bottom = -18
	_text_panel.add_child(_scroll)
	_scroll.add_child(_column)
	_history_text = RichTextLabel.new()
	_history_text.bbcode_enabled = true
	_history_text.fit_content = true
	_history_text.scroll_active = false
	_history_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_text.add_theme_font_override("normal_font", font_body)
	_history_text.add_theme_font_size_override("normal_font_size", TEXT_SIZE - 2)
	_history_text.add_theme_constant_override("line_separation", 6)
	_history_text.visible = false
	_column.add_child(_history_text)
	_column.add_child(_text)
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
	# ▲ at the top left of a conversation: more of it above
	_said_before = _make_label("▲", font_body, 16, UiStyle.ACCENT)
	_said_before.position = Vector2(6, 30)
	_said_before.visible = false
	_text_panel.add_child(_said_before)
	for below in [true, false]:
		var arrow := _make_label("▼" if below else "▲", font_body, 16, UiStyle.ACCENT)
		arrow.anchor_left = 1.0
		arrow.anchor_right = 1.0
		arrow.anchor_top = 1.0 if below else 0.0
		arrow.anchor_bottom = 1.0 if below else 0.0
		arrow.offset_left = -40
		arrow.offset_right = -20
		arrow.offset_top = -36 if below else 30
		arrow.offset_bottom = -14 if below else 52
		arrow.visible = false
		_text_panel.add_child(arrow)
		if below:
			_more_below = arrow
		else:
			_more_above = arrow
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	_choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices_box.visible = false
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the choices on the right of a conversation, scrolling on their own
	_choices_scroll = ScrollContainer.new()
	_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # the arrows say it
	_choices_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_choices_scroll.anchor_left = TALK_SPLIT
	_choices_scroll.anchor_right = 1.0
	_choices_scroll.anchor_bottom = 1.0
	_choices_scroll.offset_left = TALK_GAP * 0.5
	_choices_scroll.offset_top = 34
	_choices_scroll.offset_right = -48
	_choices_scroll.offset_bottom = -18
	_choices_scroll.visible = false
	_text_panel.add_child(_choices_scroll)
	_choices_scroll.add_child(_choices_box)


func _make_label(text: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
