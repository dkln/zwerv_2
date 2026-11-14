extends Control
## What the location over the minimap looks like (graphics; docs/CODE_LAGEN.md): a chip
## as wide as the minimap with a pin and three lines: the neighbourhood in capitals, the
## street and the nearest place; a long name ends in an ellipsis. It shows what
## location.gd hands it (show_location, show_area_font_size); its size comes from
## hud_layout.gd.
##   const LocationView = preload("res://scripts/ui/hud/location_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const ChipView = preload("res://scripts/ui/hud/chip_view.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")
const PIN := [".###.", "#####", "##.##", "#####", ".###.", "..#..", "..#.."]
const PIN_SIZE := 14.0

var _area: Label
var _street: Label
var _place: Label


func _init() -> void:
	name = "Beeld"
	size = HudLayout.location_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonts := UiStyle.fonts()
	var pin := PixelIcon.new()
	pin.bitmap = PIN
	pin.colour = UiStyle.SIDE_ACCENT
	pin.pixel = PIN_SIZE / 7.0
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area = UiStyle.label("DEN HAAG", fonts.pixel, 11, UiStyle.SIDE_ACCENT, 0)
	_street = UiStyle.label("", fonts.body, 12, UiStyle.TEXT, 0)
	_street.visible = false
	_place = UiStyle.label("", fonts.body, 11, UiStyle.MUTED, 0)
	_place.visible = false
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	for line: Label in [_area, _street, _place]:
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.add_child(line)
	var chip := ChipView.new()
	chip.add_item(pin)
	chip.add_item(lines)
	chip.custom_minimum_size = HudLayout.location_size()
	chip.size = HudLayout.location_size()
	add_child(chip)


## The three lines: `area` (as it is written), `street` ("" hides its line) and `place`
## (shown when `place_shown`).
func show_location(area: String, street: String, place: String, place_shown: bool) -> void:
	_area.text = area
	_street.text = street
	_street.visible = street != ""
	_place.text = place
	_place.visible = place_shown


## The font size of the neighbourhood line.
func show_area_font_size(font_size: int) -> void:
	_area.add_theme_font_size_override("font_size", font_size)


## How wide the neighbourhood line is (0 while it is not laid out yet).
func area_room() -> float:
	return _area.size.x


## How wide `text` is in the font of the neighbourhood line at `font_size`.
func area_width(text: String, font_size: int) -> float:
	return _area.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func area_text() -> String:
	return _area.text


func area_font_size() -> int:
	return _area.get_theme_font_size("font_size")


## The street that shows ("" when its line is hidden).
func street_text() -> String:
	return _street.text if _street.visible else ""


## The place that shows ("" when its line is hidden).
func place_text() -> String:
	return _place.text if _place.visible else ""
