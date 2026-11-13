extends Control
## The character creation screen (scenes/karakter.tscn), its own step between the main
## menu (NIEUW SPEL) and the town, in the style of the menu and the HUD: the night sky
## with stars (no town behind it) and the title, then
## - left: the archetypes (PlayerCharacter.ARCHETYPES) in a list, sharing the height of
##   the detail panel exactly (it scrolls only when there are too many to fit), each a thumbnail of the face (PlayerPortrait, zoomed in), the name (a nickname), what
##   they are good at under it and the level they start on; the chosen one in amber;
## - right: the chosen one large: the whole figure in 3D, walking on the spot and turning
##   slowly round its axis (from the front each time it is chosen), the difficulty in the top right
##   corner (MOEILIJKHEID, five blocks green to red, its name), the name, what they are good at, the level, what only they
##   have (the perk, in teal, if any), their story (typed out word by word with a block
##   cursor, widgets/typewriter.gd, as in the story box) and the stats (leven, stamina,
##   honger) as the HUD's segment bars, a share of
##   PlayerCharacter.STAT_CEILING, with the number.
## Keys: up/down (or left/right, or 1 to 9) choose, Enter begins, Escape goes back to the
## main menu; the mouse: a click chooses, a click on the chosen one or on BEGIN begins.
## Beginning stores the choice (PlayerCharacter.choose) and opens the town under the swipe;
## its own loading screen takes over from there.
## Music: a soft loop of its own (karakterkeuze_loop.ogg), fading in.
## When you look at a character (when chosen, and the first one SHOUT_FIRST_DELAY s after the
## screen opens) they first do their own move facing you (PlayerModel.play_gesture) and only
## then walk and turn; at its moment they shout (assets/audio/kreten/kreet_<id>.ogg, made by
## tools/megadrive/stemmen.py), the words in a speech balloon over their head (SpeechBalloon,
## "shout" of the archetype). A new one cuts the last one off.
## Laid out at 1280 x 720, scaled with the window.

const SoundVariation = preload("res://scripts/audio/sound_variation.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")

const CITY_SCENE := "res://scenes/stad.tscn"
const MENU_SCENE := "res://scenes/hoofdmenu.tscn"
const MUSIC := "res://assets/audio/muziek/karakterkeuze_loop.ogg"
## Soft, in the background; it fades in over MUSIC_FADE_IN seconds.
const MUSIC_VOLUME_DB := -6.0
const MUSIC_FADE_IN := 2.5
const MUSIC_FADE_OUT := 1.6
const SHOUT_FOLDER := "res://assets/audio/kreten/"
const SHOUT_VOLUME_DB := -6.0
const SHOUT_FIRST_DELAY := 0.6
## The tip of the balloon's tail from the top of the head (px): a little to the side and up.
const BALLOON_OFFSET := Vector2(26, -6)
const DESIGN_SIZE := Vector2(1280, 720)
const SKY := Color("#0E1130")
const SOFT_TEXT := Color("#C9CCE6")

## Where the list and the detail panel lie, both from TOP to TOP + HEIGHT.
const LEFT := 48.0
const TOP := 128.0
const HEIGHT := 488.0
const LIST_WIDTH := 372.0
## The entries share the height of the detail panel exactly (ENTRY_GAP between them); only
## when they would get lower than ENTRY_LOWEST the list scrolls.
const ENTRY_GAP := 10.0
const ENTRY_LOWEST := 70.0
const THUMBNAIL_LARGEST := 76.0
const DETAIL_LEFT := 444.0
const DETAIL_WIDTH := 788.0
## The whole figure in the detail panel.
const FIGURE_SIZE := Vector2(300, 456)
const STAT_SEGMENTS := 20
## Degrees a second the figure in the detail panel turns round its axis, and the seconds it
## takes to start walking when chosen.
const SPIN := 40.0
const WALK_IN := 0.6
## The difficulty in the top right corner: a block per step, green to red.
const DIFFICULTY_COLOURS := [Color("#8BE36B"), Color("#C8E35A"), Color("#FFB547"), Color("#FF8A4A"), Color("#FF5D73")]
const DIFFICULTY_EMPTY := Color("#2A2E4A")

var _design: Control
var _scroll: ScrollContainer
var _entries: Array[Control] = []
var _entry_panels: Array[Panel] = []
var _detail: Control
var _detail_figure
var _detail_name: Label
var _detail_subtitle: Label
var _detail_level: PanelContainer
var _detail_story: RichTextLabel
var _story_typewriter: Typewriter    # types the story out, as the story box and the balloons do
var _detail_perk: Label
var _difficulty_blocks: Array[ColorRect] = []
var _difficulty_name: Label
var _detail_bars := {}       # stat name -> SegmentBar
var _detail_numbers := {}    # stat name -> Label
var _begin_button: Button
var _selected := -1
var _leaving := false
var _crt: ColorRect
var _music: AudioStreamPlayer
var _shout: AudioStreamPlayer
var _balloon: SpeechBalloon
var _figure_window: Control
var _font_title: Font
var _font_title_medium: Font
var _font_pixel: Font
var _font_pixel_bold: Font
var _font_body: Font


func _process(delta: float) -> void:
	if _story_typewriter:
		_story_typewriter.update(delta)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var stars := StarField.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stars)
	_design = Control.new()
	_design.name = "Ontwerp"
	_design.size = DESIGN_SIZE
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design)
	_build_title()
	_build_list()
	_build_detail()
	_build_begin()
	_build_footer()
	var settings := MainMenu._read_settings()
	_crt = UiStyle.make_crt_overlay(0.05 if settings.crt else 0.0, 0.035 if settings.crt else 0.0,
			get_viewport().get_visible_rect().size)
	add_child(_crt)
	_crt.add_child(load("res://scripts/ui/crt_disturbance.gd").new())
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	var earlier := PlayerCharacter.ORDER.find(PlayerCharacter.chosen_id)
	_select(earlier if earlier >= 0 else 0, false)
	_play_entrance()
	_start_music()
	get_tree().create_timer(SHOUT_FIRST_DELAY).timeout.connect(func() -> void:
		if not _leaving:
			_detail_figure.play_gesture())


# ------------------------------------------------------------------ choosing

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_select(posmod(_selected + 1, _entries.size()))
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_select(posmod(_selected - 1, _entries.size()))
	elif event.is_action_pressed("ui_accept"):
		begin()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode >= KEY_1 and event.keycode < KEY_1 + mini(_entries.size(), 9):
		_select(event.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()


func _select(index: int, audible := true) -> void:
	if index == _selected:
		return
	if audible:
		UiSounds.play(self, "kies")
	_selected = index
	for entry_index in _entries.size():
		var on := entry_index == index
		var style := UiStyle.box_style(UiStyle.PANEL if on else UiStyle.TRANSLUCENT_INK, UiStyle.ACCENT if on else UiStyle.BORDER, 3 if on else 2)
		_entry_panels[entry_index].add_theme_stylebox_override("panel", style)
		_entries[entry_index].modulate = Color.WHITE if on else Color(0.75, 0.75, 0.75)
	_scroll.ensure_control_visible(_entries[index])
	_show_detail(index)
	if audible:
		_detail_figure.play_gesture()
	var archetype: Dictionary = PlayerCharacter.ARCHETYPES[PlayerCharacter.ORDER[index]]
	_begin_button.text = "→  BEGIN ALS %s" % String(archetype.name).to_upper()


## The moment of the gesture: the shout of the one shown, and its words over their head.
func _on_gesture_cue() -> void:
	var archetype_id: String = PlayerCharacter.ORDER[_selected]
	var archetype: Dictionary = PlayerCharacter.ARCHETYPES[archetype_id]
	_play_shout(archetype_id)
	_balloon.say(String(archetype.get("shout", "")), 1.4)
	_balloon.position = _figure_window.position + _detail_figure.position + _detail_figure.head_point() + BALLOON_OFFSET


## The shout of character `archetype_id`, cutting off the one before (nothing without the file).
func _play_shout(archetype_id: String) -> void:
	var path := SHOUT_FOLDER + "kreet_%s.ogg" % archetype_id
	if not ResourceLoader.exists(path):
		return
	if _shout == null:
		_shout = AudioStreamPlayer.new()
		_shout.name = "Kreet"
		_shout.volume_db = SHOUT_VOLUME_DB
		add_child(_shout)
	_shout.stream = load(path)
	_shout.pitch_scale = SoundVariation.pitch()
	_shout.play()


## The chosen one in the detail panel: the figure, the texts and the stats, fading in.
func _show_detail(index: int) -> void:
	var archetype_id: String = PlayerCharacter.ORDER[index]
	var archetype: Dictionary = PlayerCharacter.ARCHETYPES[archetype_id]
	_detail_figure.archetype_id = archetype_id
	# it walks on the spot while it turns
	_detail_figure.walking = 0.0
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(_detail_figure, "walking", 1.0, WALK_IN)
	# its own move first (the shout at its moment), then it walks and turns
	if _balloon:
		_balloon.visible = false
	if _shout:
		_shout.stop()

	var difficulty := int(archetype.get("difficulty", 1))
	for block_index in _difficulty_blocks.size():
		_difficulty_blocks[block_index].color = DIFFICULTY_COLOURS[mini(difficulty - 1, DIFFICULTY_COLOURS.size() - 1)] \
				if block_index < difficulty else DIFFICULTY_EMPTY
	_difficulty_name.text = PlayerCharacter.DIFFICULTY_NAMES[clampi(difficulty, 1, PlayerCharacter.DIFFICULTY_CEILING)]
	_difficulty_name.add_theme_color_override("font_color", DIFFICULTY_COLOURS[clampi(difficulty, 1, 5) - 1])
	_detail_name.text = archetype.name
	_detail_subtitle.text = archetype.subtitle
	_set_level_chip(_detail_level, int(archetype.level))
	_story_typewriter.start(archetype.story)
	_detail_perk.text = "EXTRA: " + String(archetype.get("perk", "")).to_upper()
	_detail_perk.visible = archetype.has("perk")
	for stat_name: String in PlayerCharacter.STAT_LABELS:
		var value := float(archetype.stats[stat_name])
		(_detail_bars[stat_name] as SegmentBar).fill = value / PlayerCharacter.STAT_CEILING
		var number: Label = _detail_numbers[stat_name]
		number.text = "%d%s" % [roundi(value), "+" if value > 100.0 else ("-" if value < 100.0 else "")]
		number.add_theme_color_override("font_color", UiStyle.TEXT if value >= 100.0 else UiStyle.MUTED)
	_detail.modulate.a = 0.4
	create_tween().tween_property(_detail, "modulate:a", 1.0, 0.25)


## Begins as the chosen archetype: the choice is stored and the town opens.
func begin() -> void:
	if _leaving:
		return
	_leaving = true
	UiSounds.play(self, "doe")
	PlayerCharacter.choose(PlayerCharacter.ORDER[_selected])
	_begin_button.text = "→  LADEN…"
	await _leave()
	get_tree().change_scene_to_file(CITY_SCENE)


func _back_to_menu() -> void:
	_leaving = true
	UiSounds.play(self, "terug")
	await _leave()
	get_tree().change_scene_to_file(MENU_SCENE)


## The list and the detail fade away, the music fades, and the swipe (the one transition of
## the game) sweeps over it: to the town (its loading screen behind it) or back to the menu.
func _leave() -> void:
	var exit := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for index in _entries.size():
		exit.tween_property(_entries[index], "modulate:a", 0.0, 0.4).set_delay(0.06 * index)
	exit.tween_property(_detail, "modulate:a", 0.0, 0.5)
	exit.tween_property(_detail, "position:x", _detail.position.x + 30.0, 0.5)
	_fade_out_music()
	await SwipeTransition.swipe(get_tree()).covered


# ------------------------------------------------------------------ building

func _build_title() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(LEFT, 30)
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(column)
	column.add_child(_small("NIEUW SPEL", UiStyle.ACCENT, 13, 6))
	column.add_child(_label("KIES JE KARAKTER", _font_title, 46, Color("#F4EEDD"), 5))


## The list on the left: a vertical scroll of entries (a slim amber scroll bar on ink).
func _build_list() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "Lijst"
	_scroll.position = Vector2(LEFT, TOP)
	_scroll.size = Vector2(LIST_WIDTH, HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var bar := _scroll.get_v_scroll_bar()
	var track := UiStyle.box_style(UiStyle.INK, UiStyle.BORDER, 1)
	track.content_margin_left = 6
	var grabber := UiStyle.box_style(UiStyle.ACCENT, UiStyle.ACCENT, 0)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber)
	bar.add_theme_stylebox_override("grabber_pressed", grabber)
	_design.add_child(_scroll)
	var count := PlayerCharacter.ORDER.size()
	# whole pixels: the first entries a pixel higher until the heights add up exactly
	var room := int(HEIGHT - ENTRY_GAP * (count - 1))
	var shared := room / count
	var left_over := room - shared * count
	var scrolls := shared < ENTRY_LOWEST
	var entry_width := LIST_WIDTH - (20.0 if scrolls else 0.0)
	# all fit (as now with six): no scrolling at all
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if scrolls else ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(ENTRY_GAP))
	column.custom_minimum_size = Vector2(entry_width, 0)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(column)
	for index in count:
		var entry_height := ENTRY_LOWEST if scrolls else float(shared + (1 if index < left_over else 0))
		column.add_child(_list_entry(index, Vector2(entry_width, entry_height)))


## An entry of the list, `entry_size`: the face as a thumbnail, the name, what they are
## good at and the level, in the middle of its height. A click chooses it (the wheel goes
## through to the scroll).
func _list_entry(index: int, entry_size: Vector2) -> Control:
	var archetype_id: String = PlayerCharacter.ORDER[index]
	var archetype: Dictionary = PlayerCharacter.ARCHETYPES[archetype_id]
	var entry := Control.new()
	entry.name = "Keuze_" + archetype_id
	entry.custom_minimum_size = entry_size
	entry.mouse_filter = Control.MOUSE_FILTER_PASS
	entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	entry.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _leaving:
			if _selected == index:
				begin()
			else:
				_select(index))
	var panel := Panel.new()
	panel.size = entry.custom_minimum_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(panel)
	var thumbnail_size := minf(THUMBNAIL_LARGEST, entry_size.y - 16.0)
	var thumbnail_top := (entry_size.y - thumbnail_size) * 0.5
	var frame := Panel.new()
	frame.position = Vector2(10, thumbnail_top)
	frame.size = Vector2(thumbnail_size, thumbnail_size)
	frame.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.INK, UiStyle.BORDER, 2))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(frame)
	var thumbnail := PlayerPortrait.new()
	thumbnail.archetype_id = archetype_id
	thumbnail.zoom = 1.0
	thumbnail.face_view = 1.0
	thumbnail.position = Vector2(12, thumbnail_top + 2)
	thumbnail.size = Vector2(thumbnail_size - 4, thumbnail_size - 4)
	entry.add_child(thumbnail)
	var texts := VBoxContainer.new()
	texts.position = Vector2(thumbnail_size + 24, (entry_size.y - 44.0) * 0.5)
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(texts)
	texts.add_child(_label(archetype.name, _font_title, 24, UiStyle.TEXT, 2))
	texts.add_child(_small(archetype.subtitle, UiStyle.ACCENT, 11, 2))
	# the level on the right, just in from the edge, in the middle of the height
	var level := _chip("", UiStyle.BORDER, UiStyle.TEXT)
	_set_level_chip(level, int(archetype.level))
	entry.add_child(level)
	level.resized.connect(func() -> void:
		level.position = Vector2(entry_size.x - 12.0 - level.size.x, (entry_size.y - level.size.y) * 0.5))
	_entries.append(entry)
	_entry_panels.append(panel)
	return entry


## The detail panel on the right: the figure large, and beside it the name, what they are good at, the level, the story and the stats.
func _build_detail() -> void:
	_detail = Control.new()
	_detail.name = "Detail"
	_detail.position = Vector2(DETAIL_LEFT, TOP)
	_detail.size = Vector2(DETAIL_WIDTH, HEIGHT)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_detail)
	var shadow := ColorRect.new()
	shadow.color = UiStyle.INK
	shadow.position = Vector2.ONE * UiStyle.SHADOW_OFFSET
	shadow.size = _detail.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(shadow)
	var panel := Panel.new()
	panel.size = _detail.size
	panel.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, 3))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(panel)
	# the whole figure in an ink window with a faint floor
	var window := Panel.new()
	window.position = Vector2(16, 16)
	window.size = FIGURE_SIZE
	window.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.INK, UiStyle.BORDER, 2))
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(window)
	var floor_glow := ColorRect.new()
	floor_glow.color = Color(1, 1, 1, 0.04)
	floor_glow.position = Vector2(2, FIGURE_SIZE.y - 60)
	floor_glow.size = Vector2(FIGURE_SIZE.x - 4, 58)
	floor_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(floor_glow)
	_detail_figure = PlayerPortrait.new()
	_detail_figure.spin = SPIN
	_detail_figure.position = Vector2(2, 2)
	_detail_figure.size = FIGURE_SIZE - Vector2(4, 4)
	window.add_child(_detail_figure)
	_detail_figure.gesture_cue.connect(_on_gesture_cue)
	_figure_window = window
	# over the window, so it is not cut off at its edge
	_balloon = SpeechBalloon.new()
	_balloon.name = "Tekstballon"
	_balloon.z_index = 1
	_detail.add_child(_balloon)
	# the difficulty in the top right corner: its name over a row of blocks
	var difficulty := VBoxContainer.new()
	difficulty.name = "Moeilijkheid"
	difficulty.add_theme_constant_override("separation", 6)
	difficulty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	difficulty.alignment = BoxContainer.ALIGNMENT_BEGIN
	difficulty.position = Vector2(DETAIL_WIDTH - 20 - 140, 20)
	difficulty.custom_minimum_size = Vector2(140, 0)
	_detail.add_child(difficulty)
	var difficulty_title := _small("MOEILIJKHEID", SOFT_TEXT, 11, 2)
	difficulty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	difficulty_title.custom_minimum_size = Vector2(140, 0)
	difficulty.add_child(difficulty_title)
	var blocks := HBoxContainer.new()
	blocks.alignment = BoxContainer.ALIGNMENT_END
	blocks.add_theme_constant_override("separation", 4)
	blocks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocks.custom_minimum_size = Vector2(140, 14)
	for block_index in PlayerCharacter.DIFFICULTY_CEILING:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(14, 14)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blocks.add_child(block)
		_difficulty_blocks.append(block)
	difficulty.add_child(blocks)
	_difficulty_name = _label("", _font_pixel_bold, 12, UiStyle.TEXT, 0)
	_difficulty_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_difficulty_name.custom_minimum_size = Vector2(140, 0)
	difficulty.add_child(_difficulty_name)
	# the texts and the stats beside it
	var column_width := DETAIL_WIDTH - FIGURE_SIZE.x - 16 * 3 - 8
	var column := VBoxContainer.new()
	column.position = Vector2(16 + FIGURE_SIZE.x + 24, 22)
	column.custom_minimum_size = Vector2(column_width, 0)
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(column)
	_detail_name = _label("", _font_title, 38, Color("#F4EEDD"), 3)
	column.add_child(_detail_name)
	_detail_subtitle = _small("", UiStyle.ACCENT, 13, 3)
	column.add_child(_detail_subtitle)
	var level_row := HBoxContainer.new()
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_level = _chip("", UiStyle.BORDER, UiStyle.TEXT)
	level_row.add_child(_detail_level)
	column.add_child(level_row)
	_detail_perk = _label("", _font_pixel_bold, 11, UiStyle.SIDE_ACCENT, 0)
	_detail_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_perk.custom_minimum_size = Vector2(column_width, 0)
	column.add_child(_detail_perk)
	column.add_child(_divider(column_width))
	# the story, typed out word by word with the block cursor (Typewriter, as the story box)
	_detail_story = RichTextLabel.new()
	_detail_story.add_theme_font_override("normal_font", _font_body)
	_detail_story.add_theme_font_size_override("normal_font_size", 14)
	_detail_story.add_theme_color_override("default_color", SOFT_TEXT)
	_detail_story.add_theme_constant_override("line_separation", 3)
	_detail_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# a long story (the Ufo Piloot) scrolls along by itself as it is typed, without a bar
	_detail_story.scroll_active = true
	_detail_story.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_story.custom_minimum_size = Vector2(column_width, 136)
	_hide_story_scroll_bar(_detail_story.get_v_scroll_bar())
	column.add_child(_detail_story)
	_story_typewriter = Typewriter.new(_detail_story, self)
	_story_typewriter.follow_cursor = true
	_story_typewriter.blink_when_done = false   # the cursor goes when the story is all there
	column.add_child(_divider(column_width))
	column.add_child(_small("STATS", SOFT_TEXT, 11, 4))
	for stat_name: String in PlayerCharacter.STAT_LABELS:
		column.add_child(_stat_row(stat_name))


## The story scrolls by itself (Typewriter.follow_cursor): its scroll bar is not shown and
## takes no room (empty styles, zero wide).
func _hide_story_scroll_bar(scroll_bar: VScrollBar) -> void:
	var nothing := StyleBoxEmpty.new()
	for style_name in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		scroll_bar.add_theme_stylebox_override(style_name, nothing)
	scroll_bar.modulate = Color(1, 1, 1, 0)
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


## A stat as in the HUD: its icon and colour (GameHud.STATS), the label, a segment bar and
## the number (set by _show_detail; ordinary is 100, marked + or - beside it).
func _stat_row(stat_name: String) -> Control:
	var stat: Dictionary = GameHud.STATS[stat_name]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PixelIcon.new()
	icon.bitmap = GameHud.PIXEL_ICONS[stat.icon]
	icon.colour = stat.colour
	icon.pixel = 2.0
	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(18, 0)
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)
	row.add_child(icon_holder)
	var name_label := _small(PlayerCharacter.STAT_LABELS[stat_name], SOFT_TEXT, 12)
	name_label.custom_minimum_size = Vector2(84, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var bar := SegmentBar.new()
	bar.segments = STAT_SEGMENTS
	bar.segment_height = 10
	bar.full_colour = stat.colour
	bar.empty_colour = stat.empty
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var number := _label("", _font_pixel_bold, 13, UiStyle.TEXT, 0)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	_detail_bars[stat_name] = bar
	_detail_numbers[stat_name] = number
	return row


func _divider(width: float) -> ColorRect:
	var line := ColorRect.new()
	line.color = UiStyle.BORDER
	line.custom_minimum_size = Vector2(width, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _build_begin() -> void:
	_begin_button = Button.new()
	_begin_button.name = "Begin"
	_begin_button.position = Vector2(DETAIL_LEFT, TOP + HEIGHT + 18)
	_begin_button.custom_minimum_size = Vector2(420, 40)
	_begin_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_begin_button.focus_mode = Control.FOCUS_NONE
	_begin_button.add_theme_font_override("font", _font_title_medium)
	_begin_button.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.ACCENT
	style.shadow_color = Color.BLACK
	style.shadow_offset = Vector2(4, 4)
	style.shadow_size = 0
	style.anti_aliasing = false
	style.content_margin_left = 12
	style.content_margin_right = 16
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_begin_button.add_theme_stylebox_override(state, style)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		_begin_button.add_theme_color_override(colour_name, UiStyle.INK)
	_begin_button.pressed.connect(begin)
	_design.add_child(_begin_button)


func _build_footer() -> void:
	var keys := _small("[↑↓] KIEZEN      [ENTER] BEGIN      [ESC] TERUG", SOFT_TEXT)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.size = Vector2(600, 16)
	keys.position = Vector2(1280 - LEFT - 600, TOP + HEIGHT + 30)
	_design.add_child(keys)


## A small block of colour with pixel text on it (the level).
func _chip(text: String, background: Color, colour: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := UiStyle.box_style(background, background, 0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_label(text, _font_pixel_bold, 11, colour, 0))
	return chip


## "LEVEL n" on a chip: amber (as the HUD's badge) above level 1, else plain.
func _set_level_chip(chip: PanelContainer, level: int) -> void:
	var background := UiStyle.ACCENT if level > 1 else UiStyle.BORDER
	var style := UiStyle.box_style(background, background, 0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", style)
	var label := chip.get_child(0) as Label
	label.text = "LEVEL %d" % level
	label.add_theme_color_override("font_color", UiStyle.INK if level > 1 else UiStyle.TEXT)


# ------------------------------------------------------------------ the entrance

func _play_entrance() -> void:
	var entrance := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for index in _entries.size():
		var entry := _entries[index]
		var shown := entry.modulate.a
		entry.modulate.a = 0.0
		entrance.tween_property(entry, "modulate:a", shown, 0.6).set_delay(0.25 + 0.12 * index)
	var detail_at := _detail.position
	_detail.position = detail_at + Vector2(40, 0)
	_detail.modulate.a = 0.0
	entrance.tween_property(_detail, "position", detail_at, 1.0).set_delay(0.4)
	entrance.tween_property(_detail, "modulate:a", 1.0, 0.8).set_delay(0.4)
	_begin_button.modulate.a = 0.0
	entrance.tween_property(_begin_button, "modulate:a", 1.0, 0.6).set_delay(1.0)
	var material := _crt.material as ShaderMaterial
	material.set_shader_parameter("tracking", 0.6)
	entrance.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), 0.6, 0.0, 1.2)


# ------------------------------------------------------------------ music

## The soft loop, fading in from silence (imported by the editor, or read from the file
## when it has not been imported yet).
func _start_music() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(MUSIC):
		stream = load(MUSIC)
	elif FileAccess.file_exists(MUSIC):
		stream = AudioStreamOggVorbis.load_from_file(MUSIC)
	if stream == null:
		push_warning("character creation: no music at %s" % MUSIC)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
		(stream as AudioStreamOggVorbis).loop_offset = 0.0
	_music = AudioStreamPlayer.new()
	_music.name = "Muziek"
	_music.stream = stream
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_IN).set_trans(Tween.TRANS_SINE)


## Fades the music out as the screen is left (it moves to the root so it outlives the scene).
func _fade_out_music() -> void:
	if _music == null or not _music.playing:
		return
	var music := _music
	_music = null
	music.reparent(get_tree().root)
	var fade := get_tree().create_tween()
	fade.tween_property(music, "volume_db", -60.0, MUSIC_FADE_OUT)
	fade.tween_callback(music.queue_free)


# ------------------------------------------------------------------ helpers

func _label(text: String, font: Font, size: int, colour := UiStyle.TEXT, shadow := 2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if shadow > 0:
		UiStyle.faux_3d(label, shadow)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _small(text: String, colour: Color, size := 11, spacing := 0) -> Label:
	var label := _label(text, UiStyle.spaced(_font_pixel, spacing) if spacing > 0 else _font_pixel, size, colour, 0)
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
	_font_pixel_bold = UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	var body := UiStyle.font(UiStyle.FONT_BODY)
	_font_body = UiStyle.weighted(body, 400)
	# the →, · and arrows the pixel fonts may lack come from JetBrains Mono
	if body != fallback:
		var fallbacks: Array[Font] = [body]
		for font: Font in [title, _font_pixel, _font_pixel_bold]:
			if font != fallback:
				font.fallbacks = fallbacks


## The night behind the screen: still stars in two colours (the menu's), some twinkling,
## the same every time, and a faint violet glow along the bottom.
class StarField:
	extends Control

	const STAR_BRIGHT := Color("#F2E8C9")
	const STAR_DIM := Color("#8A90C0")
	const STAR_COUNT := 140

	var _stars: Array = []
	var _clock := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var random := RandomNumberGenerator.new()
		random.seed = 1707
		for star_index in STAR_COUNT:
			_stars.append({"at": Vector2(random.randf(), random.randf() * 0.9), "bright": random.randf() < 0.25,
					"size": 2.0 if random.randf() < 0.2 else 1.0, "phase": random.randf() * TAU,
					"twinkles": random.randf() < 0.3})

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var pixel := maxf(1.0, roundf(size.y / 360.0))
		var bands := 12
		for band_index in bands:
			var share := float(band_index) / bands
			var alpha := 0.10 * share * share
			draw_rect(Rect2(0, size.y * (0.7 + 0.3 * share), size.x, size.y * 0.3 / bands + 1.0), Color(0.45, 0.28, 0.75, alpha))
		for star: Dictionary in _stars:
			var colour: Color = STAR_BRIGHT if star.bright else STAR_DIM
			if star.twinkles:
				colour.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_clock * 1.7 + star.phase))
			var at: Vector2 = (star.at as Vector2) * size
			draw_rect(Rect2(at.snapped(Vector2.ONE * pixel), Vector2.ONE * pixel * star.size), colour)
