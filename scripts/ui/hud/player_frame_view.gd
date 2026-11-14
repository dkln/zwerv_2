extends Control
## What the player frame of the HUD looks like (graphics; docs/CODE_LAGEN.md): the chosen
## figure's head in 3D (PlayerPortrait) with the level badge, the name, the stats as
## segmented pixel bars with an icon each (StatLook) and under them the experience: "XP"
## and a segment bar as the stats, the points under the bar. It shows what player_frame.gd
## hands it (show_stat, show_experience, show_player, flash_stat) and decides nothing; its
## sizes come from player_frame_layout.gd.
##   const PlayerFrameView = preload("res://scripts/ui/hud/player_frame_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const Layout = preload("res://scripts/ui/hud/player_frame_layout.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")

## The head and shoulders of the chosen figure.
var portrait: PlayerPortrait

var _level_badge: Label
var _name_label: Label
var _xp_bar: SegmentBar
var _xp_text: Label
var _stat_bars := {}         # stat name -> SegmentBar
var _stat_texts := {}        # stat name -> Label
var _stat_flashes := {}      # stat name -> the running flash tween
var _fonts := {}


func _init() -> void:
	name = "Beeld"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonts = UiStyle.fonts()
	_build_portrait()
	var column := VBoxContainer.new()
	column.position = Layout.column_position()
	column.add_theme_constant_override("separation", Layout.ROW_SEPARATION)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_name_label = UiStyle.label("", _fonts.title, 22, UiStyle.TEXT, 2)
	column.add_child(_name_label)
	for stat_name: String in StatLook.STATS:
		column.add_child(_stat_row(stat_name))
	column.add_child(_experience_rows())


# ------------------------------------------------------------------ showing

## Whether there is a bar for the stat `stat_name`.
func has_stat(stat_name: String) -> bool:
	return _stat_bars.has(stat_name)


## The bar of a stat filled to `fill` (0..1) with `text` beside it ("35/80").
func show_stat(stat_name: String, fill: float, text: String) -> void:
	(_stat_bars[stat_name] as SegmentBar).fill = fill
	(_stat_texts[stat_name] as Label).text = text


## The experience bar filled to `fill` (0..1) with `text` under it ("6.420 / 10.000").
func show_experience(fill: float, text: String) -> void:
	_xp_bar.fill = fill
	_xp_text.text = text


## The name beside the portrait and the text on the level badge.
func show_player(player_name: String, level_text: String) -> void:
	_name_label.text = player_name
	_level_badge.text = level_text


## Lights the value of a stat up for a moment: brighter when it went up (`gained`), reddish
## when it went down (the bar itself shows what changed, widgets/segment_bar.gd).
func flash_stat(stat_name: String, gained: bool) -> void:
	var text: Label = _stat_texts[stat_name]
	var running: Tween = _stat_flashes.get(stat_name)
	if running and running.is_valid():
		running.kill()
	text.modulate = StatLook.GAINED_FLASH if gained else StatLook.LOST_FLASH
	if not is_inside_tree():
		return
	var flash := create_tween()
	flash.tween_property(text, "modulate", Color.WHITE, StatLook.FLASH_SECONDS)
	_stat_flashes[stat_name] = flash


# ------------------------------------------------------------------ what it shows now

## The bar of a stat (null: no such stat).
func stat_bar(stat_name: String) -> SegmentBar:
	return _stat_bars.get(stat_name) as SegmentBar


## The label with the value beside the bar of a stat (null: no such stat).
func stat_label(stat_name: String) -> Label:
	return _stat_texts.get(stat_name) as Label


func xp_bar() -> SegmentBar:
	return _xp_bar


## The label with the points under the experience bar.
func xp_label() -> Label:
	return _xp_text


func shown_name() -> String:
	return _name_label.text


func shown_level() -> String:
	return _level_badge.text


# ------------------------------------------------------------------ building

func _build_portrait() -> void:
	var frame := UiStyle.shadowed_panel(Vector2.ONE * Layout.PORTRAIT_SIZE, UiStyle.ACCENT, int(Layout.PORTRAIT_BORDER))
	add_child(frame)
	var inner := Layout.portrait_inner()
	# the head and shoulders of the chosen figure (PlayerModel), in 3D, on ink
	var back := ColorRect.new()
	back.color = UiStyle.INK
	back.position = inner.position
	back.size = inner.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)
	portrait = PlayerPortrait.new()
	portrait.name = "Portret"
	portrait.zoom = 1.0
	portrait.face_view = 1.15
	portrait.position = inner.position
	portrait.size = inner.size
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
	_level_badge = UiStyle.label("", _fonts.pixel_bold, 12, UiStyle.INK)
	badge.add_child(_level_badge)
	frame.add_child(badge)
	badge.resized.connect(func() -> void:
		badge.position = Layout.badge_position(badge.size)
		badge_shadow.position = badge.position + Layout.BADGE_SHADOW
		badge_shadow.size = badge.size)


## A stat: its icon, its bar and its value ("35/80").
func _stat_row(stat_name: String) -> Control:
	var stat: Dictionary = StatLook.STATS[stat_name]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Layout.STAT_SEPARATION)
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
	experience.add_theme_constant_override("separation", Layout.EXPERIENCE_SEPARATION)
	experience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", Layout.STAT_SEPARATION)
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
	points_row.add_theme_constant_override("separation", Layout.STAT_SEPARATION)
	points_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var under_icon := Control.new()
	under_icon.custom_minimum_size = Vector2(Layout.ICON_COLUMN_WIDTH, 0)
	under_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	points_row.add_child(under_icon)
	_xp_text = UiStyle.label("", _fonts.pixel, 11, UiStyle.TEXT, 2)
	points_row.add_child(_xp_text)
	experience.add_child(points_row)
	return experience


## `item` in the middle of a holder exactly ICON_COLUMN_WIDTH wide: something wider ("XP")
## sticks out to both sides and does not push the bar after it to the right.
static func _in_icon_column(item: Control) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(Layout.ICON_COLUMN_WIDTH, item.get_combined_minimum_size().y)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(item)
	item.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	item.grow_horizontal = Control.GROW_DIRECTION_BOTH
	item.grow_vertical = Control.GROW_DIRECTION_BOTH
	return holder
