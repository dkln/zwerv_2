extends Control
## The shop screen of the HUD (GameHud.show_shop): talking to someone who sells (the one
## behind the counter of a snack bar, the sellers in the shops of Den Haag Centraal:
## Conversations.is_merchant) opens this in place of the story box. Over the dimmed world
## (the game paused, the merchant's music: SHOP_MUSIC, at full volume) one panel in the
## style of the HUD (UiStyle: INK panel, BORDER frame, ACCENT for what is chosen, the pixel
## fonts, the CRT of the HUD over it):
## - at the top the kind of shop ("KIOSK", "SNACKBAR") and its name, and your money;
## - on the left the seller (PlayerPortrait: their own look) with a name tag, and how full
##   your pockets are;
## - on the right the goods (Conversations.shop_goods: the "menu" of
##   data/gesprekken/snackbarhouder.json or of the shop in data/gesprekken/winkels.json), a
##   row each with its icon (the game menu's), its name and its price (red when you cannot
##   pay it), then "ask something" (the tip) and "leave"; under them what the chosen one is
##   (Items: its text and what it does);
## - the seller in the portrait is live (PlayerPortrait `source_figure`: their pose behind the
##   counter, the moves of their mood) with a mouth that moves while their line types out;
## - at the bottom what the seller says, typed out word by word (Typewriter) with their
##   babble (Babble) and their body moving with its mood (Emote): the greeting, what they say
##   when you buy, too little money (then also TE WEINIG GELD blinking, the money red) or full
##   pockets (ZAKKEN VOL), the tip, goodbye.
## Keys: arrows or W/S choose, 1..9 buy at once, Enter or Space buy (or ask, or leave), Esc
## or Backspace leave; the mouse too (hover chooses, a click does it). Leaving: their goodbye,
## then the screen closes (a key closes it at once) and `finished` fires.
## What you buy goes through PlayerController.buy (Conversations.shop_buy): in your pockets,
## the money off, `bought` fires (mission 1: a kroket).

signal finished

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const Interiors = preload("res://scripts/world/interiors.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
## Screen pixels per pixel of the logo in the header.
const LOGO_PIXEL := 3.0
const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")
const Babble = preload("res://scripts/audio/babble.gd")
const Items = preload("res://scripts/player/items.gd")

## The merchant's loop (assets/audio/muziek/, the one of the snack bars: Interiors).
const SHOP_MUSIC := "handelaar_loop.ogg"
const PANEL_SIZE := Vector2(960, 560)
const PADDING := 24.0
const HEADER_HEIGHT := 64.0
const LEFT_WIDTH := 240.0
const PORTRAIT_HEIGHT := 250.0
const ROW_HEIGHT := 40.0
const LIST_HEIGHT := 216.0
const SPEECH_HEIGHT := 112.0
const TEXT_SIZE := 18
const ROW_STRIP := 6
## Too little money: the colour of the notice and the money, and how long it blinks.
const WARNING := Color("#FF5D73")
const NOTICE_SECONDS := 2.6
## After goodbye has typed out, seconds before the screen closes by itself.
const GOODBYE_WAIT := 1.1
## The words of the stats in the line of what a good does (Items "effect").
const STAT_WORDS := {"honger": "HONGER", "gezondheid": "GEZONDHEID", "uithoudingsvermogen": "UITHOUDING",
	"overprikkeldheid": "OVERPRIKKELD"}

## Fonts, set by the HUD before it is added.
var font_title: Font
var font_pixel: Font
var font_body: Font

var _talk: RefCounted              # the Conversations with the seller
var _player: Node
var _rows: Array[Dictionary] = []  # {"kind": "kopen" | "tip" | "weg", "index", "button", "name", "price"}
var _chosen := 0
var _was_paused := false
var _music_before := ""
var _hud: Node
var _leaving := false
var _goodbye_wait := 0.0
var _notice_left := 0.0
var _clock := 0.0
var _line_mood := "neutraal"
var _asked_aloud := false
var _babble: AudioStreamPlayer
var _typewriter: Typewriter
var _speech: RichTextLabel
var _kind_label: Label
var _name_label: Label
var _logo_badge: PanelContainer
var _logo_icon: PixelIcon
var _money_label: Label
var _money_euro: Label
var _pockets_label: Label
var _speaker_label: Label
var _portrait_frame: Panel
var _portrait: SubViewportContainer
var _rows_box: VBoxContainer
var _rows_scroll: ScrollContainer
var _more_below: Label              # blinking arrows: more goods to scroll to
var _more_above: Label
var _detail_text: Label
var _detail_effect: Label
var _notice: PanelContainer
var _notice_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_showing() -> bool:
	return visible


## Opens the shop of `talk` (a Conversations with a seller, is_shop) for `player`; `done` is
## called when it closes. `hud`: whose music becomes the merchant's meanwhile.
func open(talk: RefCounted, player: Node, hud: Node, done := Callable()) -> void:
	if visible:
		return
	_talk = talk
	_player = player
	_hud = hud
	if done.is_valid():
		finished.connect(done, CONNECT_ONE_SHOT)
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_leaving = false
	_notice_left = 0.0
	_notice.visible = false
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	UiSounds.play(self, "doe", -4.0)
	# the merchant's music (a snack bar plays it already)
	_music_before = String(hud.get("_indoor_music")) if hud and hud.get("_indoor_music") != null else ""
	if hud and hud.has_method("set_indoor_music") and _music_before != SHOP_MUSIC:
		hud.set_indoor_music(SHOP_MUSIC)
	_kind_label.text = String(talk.call("shop_kind_label"))
	_show_logo(talk.call("shop_logo") if talk.has_method("shop_logo") else {})
	_name_label.text = String(talk.call("shop_name")).to_upper()
	_speaker_label.text = String(talk.call("speaker"))
	_portrait = PlayerPortrait.new()
	_portrait.zoom = 0.55
	_portrait.position = Vector2(3, 3)
	_portrait.size = Vector2(LEFT_WIDTH - 6, PORTRAIT_HEIGHT - 6)
	_portrait.townsfolk_look = talk.call("look")
	# live: their pose behind the counter and their mood's moves, the mouth with their lines
	var seller: Node = talk.get("person")
	_portrait.source_figure = seller.get("figure") if seller and seller.get("figure") is Node3D else null
	_portrait_frame.add_child(_portrait)
	_fill_rows()
	_choose(0, false)
	_refresh_money()
	_say(talk.call("shop_greeting"))


## The goods of the shop and the two other rows (ask, leave), as buttons.
func _fill_rows() -> void:
	for row in _rows_box.get_children():
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	var goods: Array = _talk.call("shop_goods")
	for good_index in goods.size():
		var entry: Dictionary = goods[good_index]
		var item_id := str(entry.get("item", ""))
		var item := Items.item(item_id)
		var title := str(item.get("name", entry.get("naam", item_id)))
		_add_row({"kind": "kopen", "index": good_index, "item": item_id, "price": float(entry.get("prijs", 0.0))},
			title, _euros(float(entry.get("prijs", 0.0))), item_id)
	var question := String(_talk.call("shop_tip_question"))
	if question != "":
		_add_row({"kind": "tip", "index": -1}, question, "?", "")
	_add_row({"kind": "weg", "index": -1}, "Weggaan", "ESC", "")


func _add_row(row: Dictionary, title: String, price_text: String, item_id: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 16
	line.offset_right = -14
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(32, 0)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon_box)
	if item_id != "":
		var icon := PixelIcon.new()
		icon.pixel = 3.0
		_set_icon(icon, item_id)
		icon_box.add_child(icon)
	else:
		icon_box.add_child(_make_label("?" if row.kind == "tip" else "◀", font_body, 18, UiStyle.SIDE_ACCENT if row.kind == "tip" else UiStyle.MUTED))
	var name_label := _make_label(title, font_body, TEXT_SIZE, UiStyle.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)
	var price_label := _make_label(price_text, font_pixel, 15, UiStyle.TEXT)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(price_label)
	for child in [icon_box, name_label, price_label]:
		(child as Control).size_flags_vertical = Control.SIZE_FILL
	var row_index := _rows.size()
	button.mouse_entered.connect(func() -> void: _choose(row_index))
	button.pressed.connect(func() -> void:
		_choose(row_index, false)
		_do_chosen())
	_rows_box.add_child(button)
	row["button"] = button
	row["name"] = name_label
	row["price_label"] = price_label
	_rows.append(row)


## The icon of an item as in the game menu (its own, else that of its kind).
static func _set_icon(icon: Control, item_id: String) -> void:
	var item := Items.item(item_id)
	var icon_name: String = item.get("icon", "")
	if icon_name == "" or not (GameMenu.ITEM_ICONS.has(icon_name) or GameHud.PIXEL_ICONS.has(icon_name)):
		icon_name = GameMenu.KIND_ICONS.get(item.get("kind", "spullen"), "tas")
	if GameMenu.ITEM_ICONS.has(icon_name):
		icon.set("bitmap", GameMenu.ITEM_ICONS[icon_name].rows)
		icon.set("colour", GameMenu.ITEM_ICONS[icon_name].colour)
	else:
		icon.set("bitmap", GameHud.PIXEL_ICONS[icon_name])
		icon.set("colour", GameMenu.HUD_ICON_COLOURS.get(icon_name, UiStyle.TEXT))


# ------------------------------------------------------------------ using it

## A key press or click while open: true if the screen used it (every key is its own then).
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	if not event.is_pressed() or event.is_echo():
		return true
	if _leaving:
		_close()
		return true
	if event is InputEventKey:
		var keycode := (event as InputEventKey).keycode
		if keycode in [KEY_UP, KEY_W]:
			_choose(posmod(_chosen - 1, _rows.size()))
		elif keycode in [KEY_DOWN, KEY_S]:
			_choose(posmod(_chosen + 1, _rows.size()))
		elif keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			leave()
		elif keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_do_chosen()
		elif keycode >= KEY_1 and keycode <= KEY_9 and keycode - KEY_1 < _rows.size():
			_choose(keycode - KEY_1, false)
			_do_chosen()
	return true


## The chosen row: buy it, ask, or leave.
func _do_chosen() -> void:
	if _leaving or _chosen >= _rows.size():
		return
	var row: Dictionary = _rows[_chosen]
	match String(row.kind):
		"kopen":
			buy(int(row.index))
		"tip":
			UiSounds.play(self, "doe", -6.0)
			_say(_talk.call("shop_tip"))
		_:
			leave()


## Buys good `index` (Conversations.shop_buy): the seller's answer; too little money or
## full pockets show a notice. Returns the result ("ok", "geld", "vol").
func buy(index: int) -> String:
	var answer: Dictionary = _talk.call("shop_buy", index)
	if answer.is_empty():
		return ""
	var result := String(answer.get("result", ""))
	match result:
		"ok":
			UiSounds.play(self, "munt", -2.0)
			_notice.visible = false
			_notice_left = 0.0
		"geld":
			UiSounds.play(self, "terug", -4.0)
			_show_notice("TE WEINIG GELD")
			# trying to buy without the money, again and again: thrown out (Interiors)
			Interiors.note_offence(get_tree(), "geen_geld")
		"vol":
			UiSounds.play(self, "terug", -4.0)
			_show_notice("ZAKKEN VOL")
	_refresh_money()
	_say(answer)
	return result


## Says goodbye; the screen closes once it is said (or at the next key).
func leave() -> void:
	if _leaving or not visible:
		return
	_leaving = true
	_goodbye_wait = GOODBYE_WAIT
	_say(_talk.call("shop_goodbye"))


## The notice over the seller's line ("TE WEINIG GELD", "ZAKKEN VOL"), blinking a while.
func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice.visible = true
	_notice_left = NOTICE_SECONDS
	if text == "TE WEINIG GELD":
		var flash := create_tween()
		_money_label.add_theme_color_override("font_color", WARNING)
		flash.tween_interval(NOTICE_SECONDS)
		flash.tween_callback(func() -> void: _money_label.add_theme_color_override("font_color", UiStyle.TEXT))


## What is shown now (for the checks): the notice, or "" when there is none.
func notice_text() -> String:
	return _notice_label.text if _notice.visible else ""


## What the seller says now (for the checks).
func spoken_text() -> String:
	return _typewriter.text


func _say(line: Dictionary) -> void:
	_line_mood = String(line.get("mood", "neutraal"))
	_asked_aloud = false
	if is_instance_valid(_babble):
		_babble.stop()
		_babble.queue_free()
	_talk.call("show_mood", _line_mood)
	_typewriter.start(String(line.get("text", "")))
	if _portrait:
		_portrait.speech = String(line.get("text", ""))


func _close() -> void:
	if not visible:
		return
	UiSounds.play(self, "terug", -4.0)
	visible = false
	if is_instance_valid(_babble):
		_babble.stop()
		_babble.queue_free()
	if _portrait:
		_portrait.queue_free()
		_portrait = null
	if _hud and _hud.has_method("set_indoor_music") and _music_before != SHOP_MUSIC:
		_hud.set_indoor_music(_music_before)
	get_tree().paused = _was_paused
	finished.emit()


func _choose(index: int, with_sound := true) -> void:
	if _rows.is_empty():
		return
	index = clampi(index, 0, _rows.size() - 1)
	if index != _chosen and with_sound and visible:
		UiSounds.play(self, "kies", -6.0)
	_chosen = index
	for row_index in _rows.size():
		var row: Dictionary = _rows[row_index]
		var on := row_index == _chosen
		var button := row.button as Button
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, _row_style(on))
		(row.name as Label).add_theme_color_override("font_color", UiStyle.TEXT if on else UiStyle.MUTED)
	_rows_scroll.ensure_control_visible.call_deferred(_rows[_chosen].button)
	_refresh_detail()


## A row: as the choices of the story box (PANEL with a BORDER; the chosen one RAISED with an
## ACCENT border and a strip on the left).
static func _row_style(on: bool) -> StyleBoxFlat:
	var style := UiStyle.box_style(UiStyle.RAISED if on else UiStyle.PANEL, UiStyle.ACCENT if on else UiStyle.BORDER, 2)
	style.border_width_left = ROW_STRIP if on else 2
	return style


## What the chosen good is (its text and what it does), or what the row does.
func _refresh_detail() -> void:
	var row: Dictionary = _rows[_chosen]
	match String(row.kind):
		"kopen":
			var item := Items.item(String(row.item))
			_detail_text.text = str(item.get("text", ""))
			var effects: Array[String] = []
			for stat: String in (item.get("effect", {}) as Dictionary):
				var amount := int(item.effect[stat])
				effects.append("%s%d %s" % ["+" if amount > 0 else "", amount, STAT_WORDS.get(stat, stat.to_upper())])
			_detail_effect.text = "   ".join(effects) if not effects.is_empty() else str(item.get("rarity", "")).to_upper()
		"tip":
			_detail_text.text = "Even een praatje maken. Kost niks."
			_detail_effect.text = ""
		_:
			_detail_text.text = "De winkel uit. Tot de volgende keer."
			_detail_effect.text = ""


## Your money and pockets, and the prices you cannot pay in red.
func _refresh_money() -> void:
	var money := float(_player.get("money")) if _player and _player.get("money") != null else 0.0
	_money_label.text = GameHud.money_text(money)
	if _player and _player.has_method("inventory_slots"):
		var used := (_player.get("inventory") as Dictionary).size()
		_pockets_label.text = "%d / %d VAKJES" % [used, int(_player.call("inventory_slots"))]
	for row in _rows:
		if String(row.kind) == "kopen":
			var affordable := money + 0.001 >= float(row.price)
			(row.price_label as Label).add_theme_color_override("font_color", UiStyle.TEXT if affordable else WARNING.darkened(0.15))


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_typewriter.update(delta)
	_update_babble()
	if _portrait:
		_portrait.speaking = not _typewriter.is_done()
	var room := _rows_box.size.y - _rows_scroll.size.y
	var blink := fmod(_clock, 0.8) < 0.5
	_more_below.visible = room > 1.0 and _rows_scroll.scroll_vertical < room - 1.0 and blink
	_more_above.visible = room > 1.0 and _rows_scroll.scroll_vertical > 1.0 and blink
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.modulate.a = 1.0 if fmod(_clock, 0.5) < 0.32 else 0.35
		if _notice_left <= 0.0:
			_notice.visible = false
	# goodbye said: closing, but not under a story page shown over the shop
	var story_over: bool = _hud != null and _hud.has_method("is_showing_story") and _hud.is_showing_story()
	if _leaving and _typewriter.is_done() and not story_over:
		_goodbye_wait -= delta
		if _goodbye_wait <= 0.0:
			_close()


## Their babble while their line types out (as in the story box); a question rises at its end.
func _update_babble() -> void:
	if _talk == null or (is_instance_valid(_babble) and _babble.playing):
		return
	var question := _typewriter.text.strip_edges().ends_with("?")
	var voice := String(_talk.call("voice"))
	if not _typewriter.is_done():
		var mood := "vraag" if question and _typewriter.words_left() <= 2 else _line_mood
		_asked_aloud = _asked_aloud or mood == "vraag"
		_babble = Babble.play_near(self, voice, mood)
	elif question and not _asked_aloud:
		_asked_aloud = true
		_babble = Babble.play_near(self, voice, "vraag")


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")


# ------------------------------------------------------------------ building

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := Panel.new()
	var panel_style := UiStyle.box_style(Color(UiStyle.INK, 0.95), UiStyle.BORDER, 3)
	panel_style.shadow_color = UiStyle.INK
	panel_style.shadow_offset = Vector2(UiStyle.SHADOW_OFFSET + 1, UiStyle.SHADOW_OFFSET + 1)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5 - 8.0
	panel.offset_bottom = PANEL_SIZE.y * 0.5 - 8.0
	add_child(panel)
	_build_header(panel)
	_build_seller(panel)
	_build_goods(panel)
	_build_speech(panel)
	var keys := _make_label("[↑↓] KIEZEN   [ENTER] KOPEN   [1-9] METEEN   [ESC] WEGGAAN", font_pixel, 11, UiStyle.MUTED)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.anchor_left = 0.0
	keys.anchor_right = 1.0
	keys.anchor_top = 1.0
	keys.anchor_bottom = 1.0
	keys.offset_top = 10
	keys.offset_bottom = 30
	panel.add_child(keys)


## The kind of shop and its name on the left, your money on the right, a line under them.
## The logo badge of the header: the shop's colour, its icon in the text colour; hidden
## without a logo.
func _show_logo(logo: Dictionary) -> void:
	var icon_name := String(logo.get("icoon", ""))
	_logo_badge.visible = GameMenu.ITEM_ICONS.has(icon_name)
	if not _logo_badge.visible:
		return
	var style := UiStyle.box_style(Color(String(logo.get("kleur", "#22304A"))), UiStyle.INK, 2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_logo_badge.add_theme_stylebox_override("panel", style)
	_logo_icon.bitmap = GameMenu.ITEM_ICONS[icon_name].rows
	_logo_icon.colour = Color(String(logo.get("tekst", "#FFFFFF")))


func _build_header(panel: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(PADDING, 10)
	row.size = Vector2(PANEL_SIZE.x - PADDING * 2.0, HEADER_HEIGHT - 16)
	panel.add_child(row)
	var diamond_box := Control.new()
	diamond_box.custom_minimum_size = Vector2(16, 16)
	diamond_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	diamond_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var diamond := ColorRect.new()
	diamond.color = UiStyle.ACCENT
	diamond.size = Vector2(11, 11)
	diamond.position = Vector2(2.5, 2.5)
	diamond.pivot_offset = Vector2(5.5, 5.5)
	diamond.rotation_degrees = 45.0
	diamond_box.add_child(diamond)
	row.add_child(diamond_box)
	_kind_label = _make_label("", font_pixel, 13, UiStyle.ACCENT)
	_kind_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_kind_label)
	# the shop's logo (Conversations.shop_logo): a badge in its colour with its pixel icon
	_logo_badge = PanelContainer.new()
	_logo_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_logo_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_icon = PixelIcon.new()
	_logo_icon.pixel = LOGO_PIXEL
	_logo_badge.add_child(_logo_icon)
	row.add_child(_logo_badge)
	_name_label = _make_label("", font_title, 30, UiStyle.TEXT)
	UiStyle.faux_3d(_name_label, 3)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_name_label)
	var money_box := PanelContainer.new()
	var money_style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, 2)
	money_style.content_margin_left = 12
	money_style.content_margin_right = 12
	money_style.content_margin_top = 6
	money_style.content_margin_bottom = 6
	money_box.add_theme_stylebox_override("panel", money_style)
	money_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(money_box)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 10)
	money_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_box.add_child(money_row)
	money_row.add_child(_make_label("JE GELD", font_pixel, 11, UiStyle.MUTED))
	_money_euro = _make_label("€", font_body, 18, UiStyle.ACCENT)
	money_row.add_child(_money_euro)
	_money_label = _make_label("0,00", font_pixel, 16, UiStyle.TEXT)
	money_row.add_child(_money_label)
	var line := ColorRect.new()
	line.color = UiStyle.BORDER
	line.position = Vector2(PADDING, HEADER_HEIGHT)
	line.size = Vector2(PANEL_SIZE.x - PADDING * 2.0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)


## The seller in a frame with a name tag, your pockets under it.
func _build_seller(panel: Control) -> void:
	var top := HEADER_HEIGHT + 18.0
	_portrait_frame = Panel.new()
	_portrait_frame.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, 3))
	_portrait_frame.position = Vector2(PADDING, top)
	_portrait_frame.size = Vector2(LEFT_WIDTH, PORTRAIT_HEIGHT)
	_portrait_frame.clip_contents = true
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_portrait_frame)
	var tag := PanelContainer.new()
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = UiStyle.ACCENT
	tag_style.shadow_color = UiStyle.INK
	tag_style.shadow_offset = Vector2(4, 4)
	tag_style.anti_aliasing = false
	tag_style.content_margin_left = 12
	tag_style.content_margin_right = 12
	tag_style.content_margin_top = 3
	tag_style.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.position = Vector2(PADDING + 12, top + PORTRAIT_HEIGHT - 16)
	panel.add_child(tag)
	_speaker_label = _make_label("", font_title, 16, UiStyle.INK)
	tag.add_child(_speaker_label)
	var pockets_title := _make_label("IN JE ZAKKEN", font_pixel, 11, UiStyle.MUTED)
	pockets_title.position = Vector2(PADDING, top + PORTRAIT_HEIGHT + 24)
	panel.add_child(pockets_title)
	_pockets_label = _make_label("", font_pixel, 14, UiStyle.TEXT)
	_pockets_label.position = Vector2(PADDING, top + PORTRAIT_HEIGHT + 42)
	panel.add_child(_pockets_label)


## The goods: a heading, the rows (scrolling when there are many), what the chosen one is.
func _build_goods(panel: Control) -> void:
	var left := PADDING + LEFT_WIDTH + PADDING
	var width := PANEL_SIZE.x - left - PADDING
	var top := HEADER_HEIGHT + 14.0
	var heading := _make_label("ASSORTIMENT", font_pixel, 12, UiStyle.ACCENT)
	heading.position = Vector2(left, top)
	panel.add_child(heading)
	var price_heading := _make_label("PRIJS", font_pixel, 12, UiStyle.ACCENT)
	price_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_heading.position = Vector2(left, top)
	price_heading.size = Vector2(width - 14, 16)
	panel.add_child(price_heading)
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_rows_scroll.position = Vector2(left, top + 24)
	_rows_scroll.size = Vector2(width, LIST_HEIGHT)
	panel.add_child(_rows_scroll)
	for below in [true, false]:
		var arrow := _make_label("▼" if below else "▲", font_body, 14, UiStyle.ACCENT)
		arrow.position = Vector2(left + width + 4, top + 24 + (LIST_HEIGHT - 18 if below else 0.0))
		arrow.visible = false
		panel.add_child(arrow)
		if below:
			_more_below = arrow
		else:
			_more_above = arrow
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_scroll.add_child(_rows_box)
	var detail := Panel.new()
	detail.add_theme_stylebox_override("panel", UiStyle.box_style(Color(UiStyle.PANEL, 0.6), UiStyle.BORDER, 2, true))
	detail.position = Vector2(left, top + 24 + LIST_HEIGHT + 10)
	detail.size = Vector2(width, 62)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(detail)
	_detail_text = _make_label("", font_body, 14, UiStyle.MUTED)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.position = Vector2(16, 6)
	_detail_text.size = Vector2(width - 28, 34)
	detail.add_child(_detail_text)
	_detail_effect = _make_label("", font_pixel, 11, UiStyle.SIDE_ACCENT)
	_detail_effect.position = Vector2(16, 42)
	detail.add_child(_detail_effect)


## What the seller says, across the bottom, with the notice over its right corner.
func _build_speech(panel: Control) -> void:
	var speech_panel := Panel.new()
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, 2)
	style.border_width_left = ROW_STRIP
	style.border_color = UiStyle.BORDER
	speech_panel.add_theme_stylebox_override("panel", style)
	speech_panel.position = Vector2(PADDING, PANEL_SIZE.y - PADDING - SPEECH_HEIGHT)
	speech_panel.size = Vector2(PANEL_SIZE.x - PADDING * 2.0, SPEECH_HEIGHT)
	speech_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(speech_panel)
	_speech = RichTextLabel.new()
	_speech.add_theme_font_override("normal_font", font_body)
	_speech.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_speech.add_theme_color_override("default_color", UiStyle.TEXT)
	_speech.add_theme_constant_override("line_separation", 8)
	_speech.scroll_active = false
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.position = Vector2(26, 16)
	_speech.size = speech_panel.size - Vector2(52, 26)
	speech_panel.add_child(_speech)
	_typewriter = Typewriter.new(_speech, self)
	_typewriter.blink_when_done = true
	_typewriter.sound = false   # their babble instead
	_notice = PanelContainer.new()
	var notice_style := UiStyle.box_style(WARNING, UiStyle.INK, 2)
	notice_style.content_margin_left = 12
	notice_style.content_margin_right = 12
	notice_style.content_margin_top = 4
	notice_style.content_margin_bottom = 4
	notice_style.shadow_color = UiStyle.INK
	notice_style.shadow_offset = Vector2(4, 4)
	_notice.add_theme_stylebox_override("panel", notice_style)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	_notice.position = speech_panel.position + Vector2(speech_panel.size.x - 200, -16)
	panel.add_child(_notice)
	_notice_label = _make_label("", font_pixel, 13, UiStyle.INK)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.custom_minimum_size = Vector2(160, 0)
	_notice.add_child(_notice_label)


func _make_label(text: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
