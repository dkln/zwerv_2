class_name GameHud
extends CanvasLayer
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
## The game HUD (the "HUD" node of the city scene), in the pixel style of the design
## "HUD — open world" (1280 x 720; everything scales with the window, the corners stay in
## the corners):
## - top left: the player frame (portrait with level badge, name) and the stats as
##   segmented pixel bars with an icon each (STATS: gezondheid, uithoudingsvermogen,
##   honger, overprikkeldheid), set with set_stat(name, value, maximum), and under them the
##   experience: a thin bar and "XP 6.420 / 10.000" (set_xp(points, points_for_level));
## - top centre: "nieuw gebied ontdekt" with the name of the area, fading in and out
##   (show_area);
## - top right: a minimap of 200 x 200 (north up, the player arrow in the middle) with the
##   day and the time below it. The map is one Image built once from the Grond GridMap (a
##   colour per kind of ground) and the Gebouwen GridMap (dark), no extra camera; it shows
##   the area round the followed vehicle (Volgcamera) or the point the camera looks at. The
##   time comes from the Dagcyclus node (time_of_day; a day passes when it goes round), or
##   from set_time when there is none;
## - right: the quest tracker (set_quests), hidden while there are no quests;
## - under the minimap: where the player is (the followed vehicle, else the point the
##   camera looks at): the neighbourhood (scene metadata "wijken" from the city builder),
##   the street ("straten", with the pavement beside it) and the nearest named place
##   ("places") within place_near metres, in a box as wide as the minimap over it; entering a
##   neighbourhood for the first time shows it as a new area (show_area);
## - bottom right: the money in euros (set_money);
## - the pause menu (Escape: the game stands still; VERDER SPELEN, HOOFDMENU, AFSLUITEN);
## - a CRT look over the whole picture: the world bulges like a tube, its edges bending in
##   to black rounded corners (`crt_curvature`); the HUD bends with it, but less
##   (`crt_ui_curvature`), so its corners stay readable; faint scanlines (`scanlines`).
## Fonts: Silkscreen, Pixelify Sans and JetBrains Mono (assets/fonts, OFL); Rubik when
## one is missing.

const Iso = preload("res://scripts/camera/iso_camera.gd")

## Size of the design; the HUD is laid out at this size and scaled to the window.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const MARGIN := 24.0

const INK := Color("#0B0D1A")
const PANEL := Color("#141831")
const BORDER := Color("#343B70")
const TEXT := Color("#E8E6F0")
const MUTED := Color("#9AA0C8")
const ACCENT := Color("#FFB547")
const SIDE_ACCENT := Color("#47D6C2")
const TRANSLUCENT_INK := Color(11.0 / 255.0, 13.0 / 255.0, 26.0 / 255.0, 0.82)
const SHADOW_OFFSET := 5.0

## The stats in the order they are shown: label (for the value text), colour of a full and of
## an empty segment, number of segments, segment height and the icon (PIXEL_ICONS).
const STATS := {
	"gezondheid": {"colour": Color("#FF5D73"), "empty": Color("#3A2340"), "segments": 20, "height": 12, "icon": "heart"},
	"uithoudingsvermogen": {"colour": Color("#8BE36B"), "empty": Color("#22352A"), "segments": 20, "height": 8, "icon": "bolt"},
	"honger": {"colour": Color("#FFB547"), "empty": Color("#3D2E14"), "segments": 20, "height": 8, "icon": "chomp"},
	"overprikkeldheid": {"colour": Color("#C08BFF"), "empty": Color("#2E2340"), "segments": 20, "height": 8, "icon": "burst"},
}
## The experience bar: its colour (teal: the purple of the design is taken by
## overprikkeldheid) and width (that of the stat rows).
const XP_COLOUR := Color("#47D6C2")
const XP_BAR_WIDTH := 240.0
## Icons of 7 x 7 pixels ("#" = coloured), drawn at 2 x 2 screen pixels per pixel.
const PIXEL_ICONS := {
	"heart": [".##.##.", "#######", "#######", ".#####.", "..###..", "...#...", "......."],
	"bolt": ["....##.", "...##..", "..##...", ".######", "...##..", "..##...", ".##...."],
	"chomp": ["..###..", ".#####.", "####...", "###....", "####...", ".#####.", "..###.."],
	"burst": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	"person": ["..###..", ".#####.", ".#####.", "..###..", ".......", ".#####.", "#######"],
}
## Minimap: colour per kind of ground (MINIMAP_KINDS, by the folder of the Grond tile) and
## of a building, and of an empty cell.
const MINIMAP_COLOURS := {
	"road": Color("#6B6A8E"),
	"cycle_path": Color("#7E5A72"),
	"water": Color("#24306A"),
	"grass": Color("#3E6150"),
	"pavement": Color("#4A5378"),
	"rail": Color("#555170"),
	"land": Color("#3A4A6E"),
	"building": Color("#141729"),
}
const MINIMAP_EMPTY := Color("#0B0D1A")
## Folder of a Grond tile (the start of its library name) -> kind of ground on the minimap.
const MINIMAP_KINDS := {
	"weg": "road", "snelweg": "road", "bocht": "road", "parkeren": "road", "tunnel": "road", "brug": "road",
	"fietspad": "cycle_path", "water": "water", "zwembad": "water", "natuur": "grass", "heuvel": "grass",
	"stoep": "pavement", "plein": "pavement", "spoor": "rail", "tram": "rail", "waterkant": "pavement",
}
## Placeholder quests to see the tracker (`show_example_quests`): not story content.
const EXAMPLE_QUESTS := [
	{"kind": "verhaal", "label": "VERHAAL", "title": "Voorbeeldopdracht", "distance": "240M",
		"steps": [{"text": "Eerste stap (klaar)", "done": true}, {"text": "Tweede stap", "done": false}]},
	{"kind": "zij", "label": "ZIJMISSIE", "title": "Voorbeeld zijmissie — 2/5"},
]

## Faint CRT scanlines over the picture.
@export var scanlines := true:
	set(value):
		scanlines = value
		_update_crt()
## How dark a scanline is (0..1).
@export_range(0.0, 0.5) var scanline_strength := 0.1:
	set(value):
		scanline_strength = value
		_update_crt()
## How far the picture bulges like the glass of a CRT tube (0 = flat; the edges bend in by
## about this share of the screen at the corners).
@export_range(0.0, 0.2) var crt_curvature := 0.05:
	set(value):
		crt_curvature = value
		_update_crt()
## How far the HUD bends with it (less than the world, so its corners stay readable;
## at most crt_curvature).
@export_range(0.0, 0.2) var crt_ui_curvature := 0.02:
	set(value):
		crt_ui_curvature = value
		_update_crt()
## Rounding of the black corners of the tube (share of the screen height).
@export_range(0.0, 0.1) var crt_corner := 0.035:
	set(value):
		crt_corner = value
		_update_crt()
@export var player_name := "Speler"
@export var player_level := 1
## Metres across the minimap.
@export var minimap_metres := 160.0
## Metres within which the nearest named place shows under the neighbourhood.
@export var place_near := 45.0
## The day the game starts on (the day counter goes up when Dagcyclus goes round midnight).
@export var start_day := 1
## Shows EXAMPLE_QUESTS (to see the tracker).
@export var show_example_quests := false
@export var camera_path := NodePath("../Camera")
@export var follow_camera_path := NodePath("../Volgcamera")
@export var day_cycle_path := NodePath("../Dagcyclus")
@export var ground_path := NodePath("../Grond")
@export var buildings_path := NodePath("../Gebouwen")

var _location_wijk: Label
var _location_place: Label
var _location_street: Label
var _location_box: Control
var _location_clock := 0.0
var _focus := Vector3.ZERO       # where the player is, from the last minimap update
var _has_focus := false
var _current_wijk := ""
var _visited_wijken := {}
var _font_title: Font        # Pixelify Sans, bold
var _font_title_medium: Font # Pixelify Sans, semibold
var _font_pixel: Font        # Silkscreen
var _font_pixel_bold: Font   # Silkscreen bold
var _font_body: Font         # JetBrains Mono

var _root: Control
var _ui_viewport: SubViewport   # the HUD's own picture (see _build_crt)
var _player_frame: Control
var _level_badge: Label
var _xp_bar: ThinBar
var _xp_text: Label
var _name_label: Label
var _stat_bars := {}         # stat name -> SegmentBar
var _stat_texts := {}        # stat name -> Label
var _stat_values := {}       # stat name -> Vector2(value, maximum)
var _area_banner: Control
var _area_name: Label
var _area_tween: Tween
var _minimap_box: Control
var _minimap_map: TextureRect
var _minimap_arrow: PlayerArrow
var _minimap_origin := Vector2.ZERO   # world x, z of the map image's corner
var _minimap_cell := 4.0              # metres per map pixel
var _day_label: Label
var _time_label: Label
var _time_icon: PixelIcon
var _quest_list: VBoxContainer
var _money_panel: Control
var _money_label: Label
var _crt_overlay: ColorRect

var _day := 1
var _hour := 12.0
var _last_cycle_hour := -1.0
var _clock_from_api := false


func _ready() -> void:
	layer = 10
	# it keeps running while the game is paused (the pause menu, the CRT picture)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_day = start_day
	_read_menu_settings()
	_load_fonts()
	# the HUD is drawn into a picture of its own, which the CRT overlay lays over the world
	# bent a little less than the world (crt_ui_curvature)
	_ui_viewport = SubViewport.new()
	_ui_viewport.name = "HUDBeeld"
	_ui_viewport.transparent_bg = true
	_ui_viewport.disable_3d = true
	_ui_viewport.gui_disable_input = true
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_ui_viewport)
	_root = Control.new()
	_root.name = "Ontwerp"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_viewport.add_child(_root)
	_build_player_frame()
	_build_area_banner()
	_build_minimap()
	_build_quest_tracker()
	_build_money()
	_build_pause_menu()
	_build_crt()
	for stat_name in STATS:
		set_stat(stat_name, 0.0 if stat_name in ["honger", "overprikkeldheid"] else 100.0, 100.0)
	set_player(player_name, player_level)
	set_xp(0.0, 1000.0)
	set_money(0.0)
	set_quests(EXAMPLE_QUESTS if show_example_quests else [])
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_build_minimap_image.call_deferred()


func _process(delta: float) -> void:
	_update_clock()
	_update_minimap()
	_location_clock -= delta
	if _location_clock <= 0.0:
		_location_clock = LOCATION_INTERVAL
		_update_location()


# ------------------------------------------------------------------ API

## Sets a stat (STATS: "gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"):
## the bar fills to value / maximum; maximum < 0 keeps the last one.
func set_stat(stat_name: String, value: float, maximum := -1.0) -> void:
	if not _stat_bars.has(stat_name):
		push_warning("hud: unknown stat '%s'" % stat_name)
		return
	var previous: Vector2 = _stat_values.get(stat_name, Vector2(0.0, 100.0))
	var top := maximum if maximum > 0.0 else previous.y
	var clamped := clampf(value, 0.0, top)
	_stat_values[stat_name] = Vector2(clamped, top)
	(_stat_bars[stat_name] as SegmentBar).fill = clamped / top
	(_stat_texts[stat_name] as Label).text = "%d/%d" % [roundi(clamped), roundi(top)]


## The value and maximum of a stat (Vector2).
func get_stat(stat_name: String) -> Vector2:
	return _stat_values.get(stat_name, Vector2.ZERO)


## The experience: points so far within this level and the points the level takes; the
## bar fills to their share.
func set_xp(points: float, points_for_level: float) -> void:
	var top := maxf(points_for_level, 1.0)
	var clamped := clampf(points, 0.0, top)
	_xp_bar.fill = clamped / top
	_xp_text.text = "XP %s / %s" % [_thousands(roundi(clamped)), _thousands(roundi(top))]


func set_player(new_name: String, level: int) -> void:
	player_name = new_name
	player_level = level
	_name_label.text = new_name
	_level_badge.text = "NIV %d" % level


## Shows "nieuw gebied ontdekt" with the name of the area for a few seconds.
func show_area(area_name: String, seconds := 4.0) -> void:
	_area_name.text = area_name
	if _area_tween:
		_area_tween.kill()
	_area_banner.visible = true
	_area_banner.modulate.a = 0.0
	_area_tween = create_tween()
	_area_tween.tween_property(_area_banner, "modulate:a", 1.0, 0.6)
	_area_tween.tween_interval(seconds)
	_area_tween.tween_property(_area_banner, "modulate:a", 0.0, 0.9)
	_area_tween.tween_callback(func() -> void: _area_banner.visible = false)


## The quests in the tracker, top to bottom; empty = no tracker. Each a Dictionary:
## "kind": "verhaal" (a main quest: "label", "title", "distance", "steps" = [{"text",
## "done"}]) or "zij" (a side quest: "label" and "title" on one line).
func set_quests(quests: Array) -> void:
	for child in _quest_list.get_children():
		child.queue_free()
	for quest: Dictionary in quests:
		_quest_list.add_child(_main_quest_panel(quest) if quest.get("kind", "verhaal") == "verhaal" else _side_quest_panel(quest))
	_quest_list.visible = not quests.is_empty()


## The money in the bottom right corner (whole euros, Dutch thousands separator).
func set_money(euros: float) -> void:
	_money_label.text = "€ " + _thousands(roundi(euros))


## The clock, when there is no Dagcyclus (or to override it): hour 0..24, and the day if >= 1.
func set_time(hour: float, day := -1) -> void:
	_clock_from_api = true
	_hour = fposmod(hour, 24.0)
	if day >= 1:
		_day = day
	_show_clock()


# ------------------------------------------------------------------ building

func _load_fonts() -> void:
	var fallback: Font = load("res://assets/fonts/Rubik.ttf")
	var body := _font_file("res://assets/fonts/JetBrainsMono.ttf", fallback)
	_font_body = _weighted(body, 400)
	var pixel := _font_file("res://assets/fonts/Silkscreen-Regular.ttf", fallback)
	var pixel_bold := _font_file("res://assets/fonts/Silkscreen-Bold.ttf", fallback)
	var title := _font_file("res://assets/fonts/PixelifySans.ttf", fallback)
	# glyphs the pixel fonts lack (◆, €) come from JetBrains Mono
	if body != fallback:
		var fallback_fonts: Array[Font] = [body]
		for font: Font in [pixel, pixel_bold, title]:
			if font != fallback:
				font.fallbacks = fallback_fonts
	_font_pixel = pixel
	_font_pixel_bold = pixel_bold
	_font_title = _weighted(title, 700)
	_font_title_medium = _weighted(title, 600)


static func _font_file(path: String, fallback: Font) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("hud: font %s missing, using Rubik" % path)
	return fallback


## A variable font at this weight.
## Extra space between letters (pixels), as letter-spacing in the design.
static func _spaced(font: Font, spacing: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = spacing
	return variation


static func _weighted(font: Font, weight: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return variation


func _label(text: String, font: Font, size: int, colour := TEXT, shadow := 2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if shadow > 0:
		label.add_theme_color_override("font_shadow_color", INK)
		label.add_theme_constant_override("shadow_offset_x", shadow)
		label.add_theme_constant_override("shadow_offset_y", shadow)
		label.add_theme_constant_override("shadow_outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _box_style(background: Color, border: Color, border_width: int, left_only := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	if left_only:
		style.border_width_left = border_width
	else:
		style.set_border_width_all(border_width)
	style.anti_aliasing = false
	return style


## A panel of `size` with a border and a hard shadow SHADOW_OFFSET down and to the right.
func _shadowed_panel(size: Vector2, border: Color, border_width: int, shadow := SHADOW_OFFSET) -> Control:
	var holder := Control.new()
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_rect := ColorRect.new()
	shadow_rect.color = INK
	shadow_rect.position = Vector2(shadow, shadow)
	shadow_rect.size = size
	shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow_rect)
	var panel := Panel.new()
	panel.size = size
	panel.add_theme_stylebox_override("panel", _box_style(PANEL, border, border_width))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	return holder


func _build_player_frame() -> void:
	_player_frame = Control.new()
	_player_frame.name = "Speler"
	_player_frame.position = Vector2(MARGIN, MARGIN)
	_player_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_player_frame)
	var portrait := _shadowed_panel(Vector2(76, 76), ACCENT, 3)
	_player_frame.add_child(portrait)
	var person := PixelIcon.new()
	person.bitmap = PIXEL_ICONS["person"]
	person.colour = TEXT
	person.pixel = 6.0
	person.position = Vector2(17, 17)
	portrait.add_child(person)
	var badge_shadow := ColorRect.new()
	badge_shadow.color = INK
	badge_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(badge_shadow)
	var badge := PanelContainer.new()
	var badge_style := _box_style(ACCENT, ACCENT, 0)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 3
	badge_style.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_badge = _label("NIV 1", _font_pixel_bold, 12, INK, 0)
	badge.add_child(_level_badge)
	portrait.add_child(badge)
	# right and bottom edge 10 px outside the portrait, with a 3 px shadow
	badge.resized.connect(func() -> void:
		badge.position = Vector2(76 + 10, 76 + 10) - badge.size
		badge_shadow.position = badge.position + Vector2(3, 3)
		badge_shadow.size = badge.size)
	var column := VBoxContainer.new()
	column.position = Vector2(76 + 14, 2)
	column.add_theme_constant_override("separation", 7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(column)
	_name_label = _label("", _font_title, 22)
	column.add_child(_name_label)
	for stat_name in STATS:
		var stat: Dictionary = STATS[stat_name]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := PixelIcon.new()
		icon.bitmap = PIXEL_ICONS[stat.icon]
		icon.colour = stat.colour
		icon.pixel = 2.0
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.tooltip_text = stat_name
		row.add_child(icon)
		var bar := SegmentBar.new()
		bar.segments = stat.segments
		bar.segment_height = stat.height
		bar.full_colour = stat.colour
		bar.empty_colour = stat.empty
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var value_text := _label("", _font_pixel, 12)
		value_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(value_text)
		column.add_child(row)
		_stat_bars[stat_name] = bar
		_stat_texts[stat_name] = value_text
	# experience: a thin bar the width of the stats and the points under it, as in the design
	var experience := VBoxContainer.new()
	experience.add_theme_constant_override("separation", 5)
	experience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar = ThinBar.new()
	_xp_bar.custom_minimum_size = Vector2(XP_BAR_WIDTH, 10)
	_xp_bar.fill_colour = XP_COLOUR
	experience.add_child(_xp_bar)
	_xp_text = _label("XP 0 / 0", _font_pixel, 11)
	experience.add_child(_xp_text)
	column.add_child(experience)


func _build_area_banner() -> void:
	_area_banner = VBoxContainer.new()
	_area_banner.name = "NieuwGebied"
	_area_banner.add_theme_constant_override("separation", 4)
	_area_banner.size = Vector2(400, 0)
	_area_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := _label("— NIEUW GEBIED ONTDEKT —", _spaced(_font_pixel, 3), 12, ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_banner.add_child(heading)
	_area_name = _label("", _font_title, 34, TEXT, 3)
	_area_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_banner.add_child(_area_name)
	_area_banner.visible = false
	_root.add_child(_area_banner)


func _build_minimap() -> void:
	_minimap_box = Control.new()
	_minimap_box.name = "Kaartje"
	_minimap_box.size = Vector2(200, MAP_TOP + 240)
	_minimap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_minimap_box)
	var frame := _shadowed_panel(Vector2(200, 200), BORDER, 3)
	frame.position = Vector2(0, MAP_TOP)
	_minimap_box.add_child(frame)
	var clip := Control.new()
	clip.position = Vector2(3, 3)
	clip.size = Vector2(194, 194)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(clip)
	_minimap_map = TextureRect.new()
	_minimap_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minimap_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap_map.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_minimap_map)
	_minimap_arrow = PlayerArrow.new()
	_minimap_arrow.position = clip.size * 0.5
	clip.add_child(_minimap_arrow)
	var north := _label("N", _font_pixel_bold, 12, TEXT, 1)
	north.position = Vector2(90, 4)
	frame.add_child(north)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_box.add_child(chips)
	_day_label = _label("DAG 1", _font_pixel, 11, TEXT, 0)
	chips.add_child(_chip([_day_label]))
	_time_icon = PixelIcon.new()
	_time_icon.bitmap = ["..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.."]
	_time_icon.colour = ACCENT
	_time_icon.pixel = 12.0 / 7.0
	_time_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_time_label = _label("12:00", _font_pixel, 11, TEXT, 0)
	chips.add_child(_chip([_time_icon, _time_label]))
	# right-aligned under the map, 8 px below it
	chips.resized.connect(func() -> void: chips.position = Vector2(200 - chips.size.x, MAP_TOP + 200 + 8))
	# where the player is: over the map, as wide as it, its height fixed (long names end
	# in an ellipsis)
	var pin := PixelIcon.new()
	pin.bitmap = [".###.", "#####", "##.##", "#####", ".###.", "..#..", "..#.."]
	pin.colour = SIDE_ACCENT
	pin.pixel = 14.0 / 7.0
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_location_wijk = _label("DEN HAAG", _font_pixel, 11, SIDE_ACCENT, 0)
	_location_street = _label("", _font_body, 12, TEXT, 0)
	_location_street.visible = false
	_location_place = _label("", _font_body, 11, MUTED, 0)
	_location_place.visible = false
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	for line: Label in [_location_wijk, _location_street, _location_place]:
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.add_child(line)
	_location_box = _chip([pin, lines])
	_location_box.custom_minimum_size = Vector2(200, LOCATION_HEIGHT)
	_location_box.size = Vector2(200, LOCATION_HEIGHT)
	_minimap_box.add_child(_location_box)


func _chip(contents: Array) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := _box_style(PANEL, BORDER, 2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in contents:
		row.add_child(item)
	chip.add_child(row)
	return chip


func _build_quest_tracker() -> void:
	_quest_list = VBoxContainer.new()
	_quest_list.name = "Opdrachten"
	_quest_list.add_theme_constant_override("separation", 10)
	_quest_list.custom_minimum_size = Vector2(300, 0)
	_quest_list.size = Vector2(300, 0)
	_quest_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_quest_list)


func _quest_panel(accent: Color, background_alpha: float, vertical_margin: int, separation: int) -> Array:
	var panel := PanelContainer.new()
	var style := _box_style(Color(INK, background_alpha), accent, 4, true)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	return [panel, column]


func _main_quest_panel(quest: Dictionary) -> Control:
	var parts := _quest_panel(ACCENT, 0.82, 12, 8)
	var column: VBoxContainer = parts[1]
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label("◆ " + str(quest.get("label", "VERHAAL")), _spaced(_font_pixel, 2), 11, ACCENT, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	header.add_child(_label(str(quest.get("distance", "")), _font_pixel, 11, MUTED, 0))
	column.add_child(header)
	var title := _label(str(quest.get("title", "")), _font_title_medium, 19, TEXT, 0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for step: Dictionary in quest.get("steps", []):
		var done: bool = step.get("done", false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := CheckSquare.new()
		box.done = done
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_override("normal_font", _font_body)
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_color_override("default_color", MUTED if done else TEXT)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var escaped := str(step.get("text", "")).replace("[", "[lb]")
		text.text = "[s]%s[/s]" % escaped if done else escaped
		row.add_child(text)
		steps.add_child(row)
	column.add_child(steps)
	return parts[0]


func _side_quest_panel(quest: Dictionary) -> Control:
	var parts := _quest_panel(SIDE_ACCENT, 0.7, 10, 4)
	var column: VBoxContainer = parts[1]
	var label := _label("! " + str(quest.get("label", "ZIJMISSIE")), _spaced(_font_pixel, 2), 11, SIDE_ACCENT, 0)
	column.add_child(label)
	var title := _label(str(quest.get("title", "")), _font_body, 13, TEXT, 0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	return parts[0]


func _build_money() -> void:
	_money_panel = PanelContainer.new()
	_money_panel.name = "Geld"
	var style := _box_style(TRANSLUCENT_INK, BORDER, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_money_panel.add_theme_stylebox_override("panel", style)
	_money_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := PixelIcon.new()
	coin.bitmap = [".#####.", "##...##", "#.###.#", "#.#####", "#.###.#", "##...##", ".#####."]
	coin.colour = ACCENT
	coin.pixel = 16.0 / 7.0
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_money_label = _label("€ 0", _font_pixel, 14, TEXT, 0)
	row.add_child(_money_label)
	_money_panel.add_child(row)
	_money_panel.resized.connect(_place_corners)
	_root.add_child(_money_panel)


# ------------------------------------------------------------------ pause menu

## The pause menu (Escape): the game stands still (the tree paused) and a panel in the
## middle offers these; up/down, Enter, Escape (back to the game) or the mouse.
const PAUSE_ITEMS := [["VERDER SPELEN", "resume"], ["HOOFDMENU", "menu"], ["AFSLUITEN", "quit"]]
const MAIN_MENU_SCENE := "res://scenes/hoofdmenu.tscn"
const PAUSE_WIDTH := 300.0

var _pause_layer: Control
var _pause_buttons: Array[Button] = []
var _pause_selected := 0


func _build_pause_menu() -> void:
	_pause_layer = Control.new()
	_pause_layer.name = "Pauze"
	_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.visible = false
	_root.add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(dim)
	var box := PanelContainer.new()
	var style := _box_style(Color(INK, 0.94), BORDER, 3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	box.add_theme_stylebox_override("panel", style)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause_layer.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	var title := _label("— PAUZE —", _font_pixel, 12, ACCENT, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for index in PAUSE_ITEMS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(PAUSE_WIDTH, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", _font_title_medium)
		button.add_theme_font_size_override("font_size", 22)
		button.mouse_entered.connect(func() -> void: _select_pause_item(index))
		button.pressed.connect(func() -> void: _choose_pause_item(index))
		column.add_child(button)
		_pause_buttons.append(button)
	var keys := _label("[↑↓] KIEZEN   [ENTER] KIES   [ESC] TERUG", _font_pixel, 10, MUTED, 0)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys)
	_select_pause_item(0)


func _input(event: InputEvent) -> void:
	# the HUD's picture takes no input of its own; while the pause menu is open the mouse
	# is handed to it (the picture has the size of the window)
	if _pause_layer and _pause_layer.visible and event is InputEventMouse:
		_ui_viewport.push_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_paused(not _pause_layer.visible)
	elif not _pause_layer.visible:
		return
	elif event.is_action_pressed("ui_down"):
		_select_pause_item(posmod(_pause_selected + 1, PAUSE_ITEMS.size()))
	elif event.is_action_pressed("ui_up"):
		_select_pause_item(posmod(_pause_selected - 1, PAUSE_ITEMS.size()))
	elif event.is_action_pressed("ui_accept"):
		_choose_pause_item(_pause_selected)
	else:
		return
	# HOOFDMENU has taken it out of the tree already
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Pauses the game with the pause menu open, or goes on.
func set_paused(on: bool) -> void:
	if on != _pause_layer.visible:
		UiSounds.play(self, "doe" if on else "terug")
	_pause_layer.visible = on
	_ui_viewport.gui_disable_input = not on
	get_tree().paused = on
	if on:
		_select_pause_item(0)


func _select_pause_item(index: int) -> void:
	if index != _pause_selected and _pause_layer.visible:
		UiSounds.play(self, "kies")
	_pause_selected = index
	for button_index in _pause_buttons.size():
		var on := button_index == index
		var button := _pause_buttons[button_index]
		var style := StyleBoxFlat.new()
		style.bg_color = ACCENT if on else Color(0, 0, 0, 0)
		style.shadow_color = Color.BLACK if on else Color(0, 0, 0, 0)
		style.shadow_offset = Vector2(4, 4) if on else Vector2.ZERO
		style.anti_aliasing = false
		style.content_margin_left = 12
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(colour_name, INK if on else TEXT)
		button.text = ("▶  " if on else "    ") + PAUSE_ITEMS[button_index][0]


func _choose_pause_item(index: int) -> void:
	if PAUSE_ITEMS[index][1] != "resume":   # going on sounds as closing the menu (set_paused)
		UiSounds.play(self, "doe")
	match PAUSE_ITEMS[index][1]:
		"resume":
			set_paused(false)
		"menu":
			get_tree().paused = false
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		"quit":
			get_tree().quit()


## The CRT overlay: it takes the picture so far (the world, the vignette) and draws it
## again bent like the glass of a tube, with black rounded corners, lays the HUD's own
## picture (_ui_viewport) over it bent less (ui_curvature), and puts scanlines over both.
const CRT_SHADER := """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D ui_texture : filter_linear, repeat_disable, hint_default_transparent;
uniform float curvature = 0.05;
uniform float ui_curvature = 0.02;
uniform float corner = 0.035;
uniform float scanline_strength = 0.1;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float opacity = 1.0;
// a rolling disturbance: a band at this height of the screen (0 top .. 1 bottom; off when
// outside), shifting the picture sideways a little and lighting it, a dark line above it
uniform float glitch_y = -1.0;
uniform float glitch_strength = 1.0;
// VHS tracking trouble (0 = none .. 1): the lines jump sideways at random, most in a frayed
// strip at the bottom, the whole picture wobbles, the colours slip apart, noise
uniform float tracking = 0.0;

void fragment() {
	// from the middle (-1..1); further out the picture is taken from further out, so the
	// edges bend in, most at the corners
	float band = 1.0 - smoothstep(0.0, 0.035, abs(SCREEN_UV.y - glitch_y));
	float leading_line = 1.0 - smoothstep(0.0, 0.004, abs(SCREEN_UV.y - glitch_y + 0.04));
	vec2 screen_uv = SCREEN_UV;
	screen_uv.x += band * glitch_strength * 0.006 * sin(SCREEN_UV.y * 900.0 + TIME * 40.0);
	// tracking: per pair of screen lines a jump that changes 24 times a second
	float line_pair = floor(SCREEN_UV.y * screen_size.y * 0.5);
	float jump = fract(sin(line_pair * 12.9898 + floor(TIME * 24.0) * 78.233) * 43758.5453) - 0.5;
	float frayed = smoothstep(0.78, 0.97, SCREEN_UV.y) + 0.25 * band;
	screen_uv.x += tracking * (jump * 0.03 * frayed + 0.0025 * sin(SCREEN_UV.y * 24.0 + TIME * 6.0));
	vec2 centred = screen_uv * 2.0 - 1.0;
	vec2 bent = centred * (1.0 + curvature * centred.yx * centred.yx);
	vec2 uv = bent * 0.5 + 0.5;
	// the black edge of the tube with rounded corners (in pixels, so round on any window)
	vec2 pixels = (abs(bent) - 1.0) * 0.5 * screen_size;
	float radius = corner * screen_size.y;
	vec2 into_corner = max(pixels + radius, 0.0);
	float outside = length(into_corner) - radius;
	float glass = 1.0 - smoothstep(-1.5, 0.5, outside);
	vec3 picture = texture(screen_texture, clamp(uv, 0.0, 1.0)).rgb * glass;
	// the colours slipping apart in tracking trouble (red one way, blue the other)
	vec2 slip = vec2(0.004 * tracking, 0.0);
	picture.r = mix(picture.r, texture(screen_texture, clamp(uv + slip, 0.0, 1.0)).r * glass, step(0.001, tracking));
	picture.b = mix(picture.b, texture(screen_texture, clamp(uv - slip, 0.0, 1.0)).b * glass, step(0.001, tracking));
	// the HUD over it, bent less (and never cut off by the black corners)
	vec2 ui_uv = centred * (1.0 + ui_curvature * centred.yx * centred.yx) * 0.5 + 0.5;
	vec4 ui = texture(ui_texture, clamp(ui_uv, 0.0, 1.0));
	float ui_inside = step(0.0, ui_uv.x) * step(ui_uv.x, 1.0) * step(0.0, ui_uv.y) * step(ui_uv.y, 1.0);
	picture = mix(picture, ui.rgb, ui.a * ui_inside);
	// one darker line in every three, on the bent picture
	float line = step(mod(uv.y * screen_size.y, 3.0), 1.0);
	picture *= 1.0 - scanline_strength * line;
	// tracking noise, most in the frayed strip
	float speck = fract(sin(dot(floor(SCREEN_UV * screen_size * 0.5), vec2(12.9898, 78.233)) + floor(TIME * 30.0)) * 43758.5453);
	picture += vec3(speck - 0.5) * 0.22 * tracking * (0.25 + frayed);
	// the disturbance: lighter in its band, a dark line running ahead of it
	picture += vec3(0.07, 0.08, 0.09) * band * glitch_strength;
	picture *= 1.0 - 0.35 * leading_line * glitch_strength;
	// a little darker towards the rim, as the glass curves away
	picture *= 1.0 - 0.18 * smoothstep(0.55, 1.4, length(centred * vec2(0.9, 1.0)));
	COLOR = vec4(picture, opacity);
}
"""


## A full-window CRT overlay of its own (the loading screen): the CRT shader with these
## settings, without a HUD picture over it; it bends what is drawn before it.
static func make_crt_overlay(curvature: float, corner: float, scanline_strength: float, screen_size: Vector2) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "CRT"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = CRT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("curvature", curvature)
	material.set_shader_parameter("ui_curvature", 0.0)
	material.set_shader_parameter("corner", corner)
	material.set_shader_parameter("scanline_strength", scanline_strength)
	material.set_shader_parameter("screen_size", screen_size)
	overlay.material = material
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	return overlay


func _build_crt() -> void:
	_crt_overlay = ColorRect.new()
	_crt_overlay.name = "CRT"
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = CRT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_crt_overlay.material = material
	# outside the scaled design: always the whole window, in real screen lines
	_crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	material.set_shader_parameter("ui_texture", _ui_viewport.get_texture())
	add_child(_crt_overlay)
	_crt_overlay.resized.connect(_update_crt)
	_update_crt()


## The settings of the main menu (MainMenu.SETTINGS_PATH): the CRT look and the scanlines
## off if the player turned them off there.
func _read_menu_settings() -> void:
	var config := ConfigFile.new()
	if config.load(MainMenu.SETTINGS_PATH) != OK:
		return
	if not config.get_value("beeld", "crt", true):
		crt_curvature = 0.0
		crt_ui_curvature = 0.0
	if not config.get_value("beeld", "scanlijnen", true):
		scanlines = false


## Hands the CRT settings to its shader; off altogether when it would change nothing.
func _update_crt() -> void:
	if _crt_overlay == null:
		return
	var material := _crt_overlay.material as ShaderMaterial
	material.set_shader_parameter("curvature", crt_curvature)
	material.set_shader_parameter("ui_curvature", minf(crt_ui_curvature, crt_curvature))
	material.set_shader_parameter("corner", crt_corner if crt_curvature > 0.0 else 0.0)
	material.set_shader_parameter("scanline_strength", scanline_strength if scanlines else 0.0)
	material.set_shader_parameter("screen_size", _crt_overlay.size if _crt_overlay.size.x > 0.0 else Vector2(1280, 720))
	# always drawn: it also lays the HUD's picture over the world


# ------------------------------------------------------------------ layout

## Scales the design to the window (the smaller of the two ratios) and keeps the corners
## in the corners.
func _fit_to_window() -> void:
	var window := get_viewport().get_visible_rect().size
	if _ui_viewport:
		_ui_viewport.size = Vector2i(window)
	var factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	_root.scale = Vector2(factor, factor)
	_root.size = window / factor
	_place_corners()


func _place_corners() -> void:
	if _root == null or _money_panel == null:
		return
	var area := _root.size
	_area_banner.position = Vector2((area.x - 400.0) * 0.5, 34.0)
	_minimap_box.position = Vector2(area.x - MARGIN - 200.0, MARGIN)
	_quest_list.position = Vector2(area.x - MARGIN - 300.0, 290.0 + MAP_TOP)
	_money_panel.position = area - Vector2(MARGIN, 28.0) - _money_panel.size


static func _thousands(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


# ------------------------------------------------------------------ clock

func _update_clock() -> void:
	var day_cycle := get_node_or_null(day_cycle_path)
	if day_cycle != null and not _clock_from_api and "time_of_day" in day_cycle:
		var hour: float = day_cycle.time_of_day
		if _last_cycle_hour >= 0.0 and hour < _last_cycle_hour - 12.0:
			_day += 1   # it went round midnight
		_last_cycle_hour = hour
		_hour = hour
	_show_clock()


func _show_clock() -> void:
	var minutes := int(_hour * 60.0) % (24 * 60)
	_time_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	_day_label.text = "DAG %d" % _day
	var night := _hour < 6.5 or _hour > 21.0
	_time_icon.colour = MUTED if night else ACCENT


# ------------------------------------------------------------------ minimap

## One pixel per 4 m cell: the kind of ground of the top Grond tile at street level, and
## dark where the Gebouwen GridMap has a building. Built once.
func _build_minimap_image() -> void:
	var ground := get_node_or_null(ground_path) as GridMap
	if ground == null or ground.mesh_library == null:
		return
	var cells := ground.get_used_cells()
	if cells.is_empty():
		return
	var lowest := Vector2i(1 << 30, 1 << 30)
	var highest := -lowest
	var top := {}   # Vector2i -> the highest cell at street level or below
	for cell in cells:
		if cell.y > 0:
			continue
		var column := Vector2i(cell.x, cell.z)
		if not top.has(column) or cell.y > top[column].y:
			top[column] = cell
		lowest = Vector2i(mini(lowest.x, cell.x), mini(lowest.y, cell.z))
		highest = Vector2i(maxi(highest.x, cell.x), maxi(highest.y, cell.z))
	if top.is_empty():
		return
	var size := highest - lowest + Vector2i.ONE
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(MINIMAP_EMPTY)
	var kind_of_item := {}
	for column: Vector2i in top:
		var item := ground.get_cell_item(top[column])
		if not kind_of_item.has(item):
			kind_of_item[item] = _minimap_kind(ground.mesh_library.get_item_name(item))
		image.set_pixel(column.x - lowest.x, column.y - lowest.y, MINIMAP_COLOURS[kind_of_item[item]])
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings != null:
		for cell in buildings.get_used_cells():
			var pixel := Vector2i(cell.x, cell.z) - lowest
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < size.x and pixel.y < size.y:
				image.set_pixelv(pixel, MINIMAP_COLOURS["building"])
	_minimap_cell = ground.cell_size.x
	# cell (x, z) spans x*4 .. x*4+4 (the GridMap centres its tiles in their cells)
	_minimap_origin = Vector2(lowest) * _minimap_cell + Vector2(ground.position.x, ground.position.z)
	_minimap_map.texture = ImageTexture.create_from_image(image)


static func _minimap_kind(item_name: String) -> String:
	var folder := item_name.get_slice("/", 0)
	if item_name.contains("gras") or item_name.contains("park"):
		return "grass"
	if folder == "natuur" and (item_name.contains("pad") or item_name.contains("grind")):
		return "pavement"
	return MINIMAP_KINDS.get(folder, "land")


## Moves the map so the player (the followed vehicle, else the point the camera looks at)
## is in the middle, and turns the arrow its way.
func _update_minimap() -> void:
	if _minimap_map.texture == null:
		return
	var heading := Vector3.FORWARD
	var focus := Vector3.ZERO
	var follow := get_node_or_null(follow_camera_path)
	var followed: Node3D = null
	if follow != null and follow.has_method("is_following") and follow.is_following():
		followed = follow.get("target_node")
	var camera := get_viewport().get_camera_3d()
	if followed != null:
		focus = followed.global_position
		heading = followed.global_basis.z   # vehicles drive along +Z
	elif camera != null:
		focus = Iso.ground_focus(camera)
		heading = -camera.global_basis.z
	else:
		return
	var pixels_per_metre := (_minimap_arrow.get_parent() as Control).size.x / minimap_metres
	var scale_per_cell := pixels_per_metre * _minimap_cell
	var texture_size := _minimap_map.texture.get_size()
	_minimap_map.size = texture_size * scale_per_cell
	_focus = focus
	_has_focus = true
	var focus_on_map := (Vector2(focus.x, focus.z) - _minimap_origin) * pixels_per_metre
	_minimap_map.position = _minimap_arrow.position - focus_on_map
	var flat := Vector2(heading.x, heading.z)
	if flat.length_squared() > 0.0001:
		_minimap_arrow.rotation = atan2(flat.x, -flat.y)


## Height of the box with where the player is, over the minimap, and where the map starts
## under it (8 px lower).
const LOCATION_HEIGHT := 58.0
const MAP_TOP := LOCATION_HEIGHT + 8.0
## Seconds between looks at where the player is.
const LOCATION_INTERVAL := 0.5
## Map cells are 4 m (the "wijken" table counts in cells).
const CELL_METRES := 4.0


## Shows the neighbourhood and the nearest named place under the minimap; a neighbourhood
## entered for the first time (not the one it starts in) is announced as a new area.
func _update_location() -> void:
	if not _has_focus:
		return
	var world := owner if owner else get_parent()
	if world == null:
		return
	var cell := Vector2(_focus.x, _focus.z) / CELL_METRES
	var wijk := "Den Haag"
	for area: Array in world.get_meta("wijken", []):
		if cell.x >= area[1] and cell.y >= area[2] and cell.x < area[3] + 1 and cell.y < area[4] + 1:
			wijk = area[0]
			break
	var street := _street_at(world, cell)
	var nearest := ""
	var nearest_distance := place_near
	var places: Dictionary = world.get_meta("places", {})
	for place_key: String in places:
		if place_key.begins_with("verkeerslichten"):
			continue   # a test spot of the builder, not a place
		var distance := (places[place_key] as Vector2).distance_to(Vector2(_focus.x, _focus.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = _place_name(place_key)
	_location_wijk.text = wijk.to_upper()
	_location_street.text = street
	_location_street.visible = street != ""
	_location_place.text = nearest
	_location_place.visible = nearest != "" and nearest.to_lower() != wijk.to_lower() and nearest.to_lower() != street.to_lower()
	if wijk != _current_wijk:
		if _current_wijk != "" and not _visited_wijken.has(wijk):
			show_area(wijk)
		_current_wijk = wijk
		_visited_wijken[wijk] = true


## Cells beside a street that still count as on it (the pavement).
const STREET_MARGIN_CELLS := 1.0


## The name of the street at this map cell (fractional), from the scene metadata
## "straten"; on the lanes before the pavement beside them; "" if none.
static func _street_at(world: Node, cell: Vector2) -> String:
	var beside := ""
	for street: Array in world.get_meta("straten", []):
		var across := cell.x if street[1] == "x" else cell.y
		var along := cell.y if street[1] == "x" else cell.x
		if along < street[4] or along >= street[5] + 1:
			continue
		if across >= street[2] and across < street[3] + 1:
			return street[0]
		if beside == "" and across >= street[2] - STREET_MARGIN_CELLS and across < street[3] + 1 + STREET_MARGIN_CELLS:
			beside = street[0]
	return beside


## A key of "places" as a name: "ministerie_van_financien" -> "Ministerie van Financien",
## "a12_koningskade" -> "A12 Koningskade".
static func _place_name(place_key: String) -> String:
	var words := place_key.split("_", false)
	# a second one of the same (a supermarket chain: "derrek_3") is just its name
	if words.size() > 1 and words[-1].is_valid_int():
		words.resize(words.size() - 1)
	for index in words.size():
		var word := words[index]
		if index > 0 and word in ["van", "de", "het", "en", "der", "den", "op"]:
			continue
		words[index] = word.substr(0, 1).to_upper() + word.substr(1)
	return " ".join(words)


# ------------------------------------------------------------------ small controls

## A pixel icon: a bitmap of rows ("#" = coloured), `pixel` screen pixels per pixel.
class PixelIcon extends Control:
	var bitmap: Array = []:
		set(value):
			bitmap = value
			_resize()
	var colour := Color.WHITE:
		set(value):
			colour = value
			queue_redraw()
	var pixel := 2.0:
		set(value):
			pixel = value
			_resize()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _resize() -> void:
		var rows := bitmap.size()
		var columns: int = (bitmap[0] as String).length() if rows > 0 else 0
		custom_minimum_size = Vector2(columns, rows) * pixel
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		for row_index in bitmap.size():
			var row: String = bitmap[row_index]
			for column_index in row.length():
				if row[column_index] == "#":
					draw_rect(Rect2(Vector2(column_index, row_index) * pixel, Vector2(pixel, pixel)), colour)


## A segmented bar: `segments` blocks of 9 px wide and `segment_height` high, 2 px apart, on
## ink with a 2 px border; the first `fill` share of them in `full_colour`.
class SegmentBar extends Control:
	const SEGMENT_WIDTH := 9.0
	const GAP := 2.0
	const PADDING := 3.0
	const BORDER_WIDTH := 2.0
	var segments := 20:
		set(value):
			segments = value
			_resize()
	var segment_height := 12:
		set(value):
			segment_height = value
			_resize()
	var full_colour := Color.WHITE
	var empty_colour := Color.BLACK
	var fill := 1.0:
		set(value):
			fill = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _resize() -> void:
		var inner := Vector2(segments * SEGMENT_WIDTH + (segments - 1) * GAP, segment_height)
		custom_minimum_size = inner + Vector2.ONE * 2.0 * (PADDING + BORDER_WIDTH)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), GameHud.BORDER)
		draw_rect(Rect2(Vector2.ONE * BORDER_WIDTH, size - Vector2.ONE * 2.0 * BORDER_WIDTH), GameHud.INK)
		var full := roundi(fill * segments)
		var start := Vector2.ONE * (BORDER_WIDTH + PADDING)
		for segment_index in segments:
			var at := start + Vector2(segment_index * (SEGMENT_WIDTH + GAP), 0.0)
			draw_rect(Rect2(at, Vector2(SEGMENT_WIDTH, segment_height)), full_colour if segment_index < full else empty_colour)


## A thin bar with a border (the experience): filled to `fill` (0..1) in `fill_colour`.
class ThinBar extends Control:
	const BORDER_WIDTH := 2.0
	var fill_colour := Color.WHITE
	var fill := 0.0:
		set(value):
			fill = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), GameHud.BORDER)
		var inner := Rect2(Vector2.ONE * BORDER_WIDTH, size - Vector2.ONE * 2.0 * BORDER_WIDTH)
		draw_rect(inner, GameHud.INK)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * fill, inner.size.y)), fill_colour)


## A quest step's box: filled grey when done, else an open square.
class CheckSquare extends Control:
	var done := false

	func _init() -> void:
		custom_minimum_size = Vector2(10, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if done:
			draw_rect(Rect2(Vector2.ZERO, Vector2(10, 10)), GameHud.MUTED)
		else:
			# an open square: a 2 px border
			for edge in [Rect2(0, 0, 10, 2), Rect2(0, 8, 10, 2), Rect2(0, 2, 2, 6), Rect2(8, 2, 2, 6)]:
				draw_rect(edge, GameHud.TEXT)


## The player on the minimap: a white triangle pointing up (north) when unturned, with an
## ink outline, turned round its middle.
class PlayerArrow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var outline := PackedVector2Array([Vector2(0, -10), Vector2(10, 10), Vector2(-10, 10)])
		draw_colored_polygon(outline, GameHud.INK)
		var arrow := PackedVector2Array([Vector2(0, -8), Vector2(8, 8), Vector2(-8, 8)])
		draw_colored_polygon(arrow, Color.WHITE)
