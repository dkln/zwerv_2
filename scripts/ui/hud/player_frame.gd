extends Control
## The player frame of the HUD (the node "Speler", top left): the chosen figure's head in 3D
## (PlayerPortrait) with the level badge, its name, the stats as segmented pixel bars with an
## icon each (StatLook.STATS: gezondheid, uithoudingsvermogen, honger, overprikkeldheid;
## set_stat) and under them the experience: "XP" and a segment bar as the stats, the points
## under the bar ("6.420 / 10.000", set_xp).
##   const PlayerFrame = preload("res://scripts/ui/hud/player_frame.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PORTRAIT_SIZE := 76.0
const PORTRAIT_BORDER := 3.0
## The column of the stat icons (and "XP"): this wide, the thing in it in the middle, so
## the bars after it all start at the same place.
const ICON_COLUMN_WIDTH := 18.0
## A change of a stat of at least this many points in one go lights its value up (a hit,
## eating, hunger biting); the slow running down and filling up of the meters does not.
const STAT_SHAKE_FROM := 1.5
const STAT_FLASH_SECONDS := 0.6
const GAINED_FLASH := Color(1.7, 1.7, 1.7)
const LOST_FLASH := Color(1.6, 0.45, 0.4)

## The head and shoulders of the chosen figure.
var portrait: PlayerPortrait

var _level_badge: Label
var _name_label: Label
var _xp_bar: SegmentBar
var _xp_text: Label
var _stat_bars := {}         # stat name -> SegmentBar
var _stat_texts := {}        # stat name -> Label
var _stat_values := {}       # stat name -> Vector2(value, maximum)
var _stat_flashes := {}      # stat name -> the running flash tween
var _fonts := {}


func _init() -> void:
	name = "Speler"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonts = UiStyle.fonts()
	_build_portrait()
	var column := VBoxContainer.new()
	column.position = Vector2(PORTRAIT_SIZE + 14, 2)
	column.add_theme_constant_override("separation", 7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_name_label = UiStyle.label("", _fonts.title, 22, UiStyle.TEXT, 2)
	column.add_child(_name_label)
	for stat_name: String in StatLook.STATS:
		column.add_child(_stat_row(stat_name))
	column.add_child(_experience_rows())


# ------------------------------------------------------------------ what it shows

## Sets a stat (StatLook.STATS): the bar fills to value / maximum; maximum < 0 keeps the
## last one. A jump of STAT_SHAKE_FROM points or more lights its value up.
func set_stat(stat_name: String, value: float, maximum := -1.0) -> void:
	if not _stat_bars.has(stat_name):
		push_warning("hud: unknown stat '%s'" % stat_name)
		return
	var known := _stat_values.has(stat_name)
	var previous: Vector2 = _stat_values.get(stat_name, Vector2(0.0, 100.0))
	var stat := StatLook.clamped(value, maximum, previous.y)
	_stat_values[stat_name] = stat
	if known and is_jump(previous.x, stat.x):
		_flash_stat(stat_name, stat.x > previous.x)
	(_stat_bars[stat_name] as SegmentBar).fill = StatLook.fill(stat)
	(_stat_texts[stat_name] as Label).text = StatLook.value_text(stat)


## The value and maximum of a stat (Vector2); zero when it was never set.
func get_stat(stat_name: String) -> Vector2:
	return _stat_values.get(stat_name, Vector2.ZERO)


## Whether a stat going from `before` to `after` in one go is a jump that lights up.
static func is_jump(before: float, after: float) -> bool:
	return absf(after - before) >= STAT_SHAKE_FROM


## The experience: points so far within this level and the points the level takes; the
## bar fills to their share.
func set_xp(points: float, points_for_level: float) -> void:
	var experience := StatLook.experience(points, points_for_level)
	_xp_bar.fill = StatLook.fill(experience)
	_xp_text.text = xp_text(experience)


## The experience as written under its bar: "6.420 / 10.000".
static func xp_text(experience: Vector2) -> String:
	return "%s / %s" % [MoneyText.thousands(roundi(experience.x)), MoneyText.thousands(roundi(experience.y))]


## The name of the player and its level on the badge.
func set_player(player_name: String, level: int) -> void:
	_name_label.text = player_name
	_level_badge.text = "LEVEL %d" % level


## The bar of a stat (null: no such stat).
func stat_bar(stat_name: String) -> SegmentBar:
	return _stat_bars.get(stat_name) as SegmentBar


## The value text beside the bar of a stat ("35/80").
func stat_text(stat_name: String) -> String:
	return (_stat_texts[stat_name] as Label).text if _stat_texts.has(stat_name) else ""


func xp_bar() -> SegmentBar:
	return _xp_bar


## The label with the points under the experience bar.
func xp_label() -> Label:
	return _xp_text


func shown_name() -> String:
	return _name_label.text


func shown_level() -> String:
	return _level_badge.text


## Lights the value of a stat up for a moment: brighter when it went up, reddish when it
## went down (the bar itself shows what changed, scripts/ui/widgets/segment_bar.gd).
func _flash_stat(stat_name: String, gained: bool) -> void:
	var text: Label = _stat_texts[stat_name]
	var running: Tween = _stat_flashes.get(stat_name)
	if running and running.is_valid():
		running.kill()
	text.modulate = GAINED_FLASH if gained else LOST_FLASH
	if not is_inside_tree():
		return
	var flash := create_tween()
	flash.tween_property(text, "modulate", Color.WHITE, STAT_FLASH_SECONDS)
	_stat_flashes[stat_name] = flash


# ------------------------------------------------------------------ building

func _build_portrait() -> void:
	var frame := UiStyle.shadowed_panel(Vector2.ONE * PORTRAIT_SIZE, UiStyle.ACCENT, int(PORTRAIT_BORDER))
	add_child(frame)
	var inner := Vector2.ONE * (PORTRAIT_SIZE - 2.0 * PORTRAIT_BORDER)
	# the head and shoulders of the chosen figure (PlayerModel), in 3D, on ink
	var back := ColorRect.new()
	back.color = UiStyle.INK
	back.position = Vector2.ONE * PORTRAIT_BORDER
	back.size = inner
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)
	portrait = PlayerPortrait.new()
	portrait.name = "Portret"
	portrait.archetype_id = PlayerCharacter.current_id()
	portrait.zoom = 1.0
	portrait.face_view = 1.15
	portrait.position = Vector2.ONE * PORTRAIT_BORDER
	portrait.size = inner
	frame.add_child(portrait)
	var badge_shadow := ColorRect.new()
	badge_shadow.color = UiStyle.INK
	badge_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(badge_shadow)
	var badge := PanelContainer.new()
	var badge_style := UiStyle.box_style(UiStyle.ACCENT, UiStyle.ACCENT, 0)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 3
	badge_style.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_badge = UiStyle.label("LEVEL 1", _fonts.pixel_bold, 12, UiStyle.INK)
	badge.add_child(_level_badge)
	frame.add_child(badge)
	# right and bottom edge 10 px outside the portrait, with a 3 px shadow
	badge.resized.connect(func() -> void:
		badge.position = Vector2.ONE * (PORTRAIT_SIZE + 10.0) - badge.size
		badge_shadow.position = badge.position + Vector2(3, 3)
		badge_shadow.size = badge.size)


## A stat: its icon, its bar and its value ("35/80").
func _stat_row(stat_name: String) -> Control:
	var stat: Dictionary = StatLook.STATS[stat_name]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PixelIcon.new()
	icon.bitmap = StatLook.PIXEL_ICONS[stat.icon]
	icon.colour = stat.colour
	icon.pixel = 2.0
	icon.tooltip_text = stat_name
	row.add_child(_in_icon_column(icon))
	var bar := SegmentBar.new()
	bar.segments = stat.segments
	bar.segment_height = stat.height
	bar.full_colour = stat.colour
	bar.empty_colour = stat.empty
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value_text := UiStyle.label("", _fonts.pixel, 12, UiStyle.TEXT, 2)
	value_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_text)
	_stat_bars[stat_name] = bar
	_stat_texts[stat_name] = value_text
	return row


## Experience: a row as the stats, "XP" where they have their icon and a segment bar as
## theirs (as wide and as high as the slimmer of them), and the points under the bar,
## starting where it starts.
func _experience_rows() -> Control:
	var experience := VBoxContainer.new()
	experience.add_theme_constant_override("separation", 5)
	experience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(_in_icon_column(UiStyle.label("XP", _fonts.pixel_bold, 11, StatLook.XP_COLOUR)))
	_xp_bar = SegmentBar.new()
	_xp_bar.segments = StatLook.XP_SEGMENTS
	_xp_bar.segment_height = StatLook.XP_SEGMENT_HEIGHT
	_xp_bar.full_colour = StatLook.XP_COLOUR
	_xp_bar.empty_colour = StatLook.XP_EMPTY_COLOUR
	_xp_bar.fill = 0.0
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(_xp_bar)
	experience.add_child(xp_row)
	var points_row := HBoxContainer.new()
	points_row.add_theme_constant_override("separation", 8)
	points_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var under_icon := Control.new()
	under_icon.custom_minimum_size = Vector2(ICON_COLUMN_WIDTH, 0)
	under_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	points_row.add_child(under_icon)
	_xp_text = UiStyle.label("0 / 0", _fonts.pixel, 11, UiStyle.TEXT, 2)
	points_row.add_child(_xp_text)
	experience.add_child(points_row)
	return experience


## `item` in the middle of a holder exactly ICON_COLUMN_WIDTH wide: something wider ("XP")
## sticks out to both sides and does not push the bar after it to the right.
static func _in_icon_column(item: Control) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ICON_COLUMN_WIDTH, item.get_combined_minimum_size().y)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(item)
	item.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	item.grow_horizontal = Control.GROW_DIRECTION_BOTH
	item.grow_vertical = Control.GROW_DIRECTION_BOTH
	return holder
