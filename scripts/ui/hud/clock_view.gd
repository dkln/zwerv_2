extends Control
## What the clock of the HUD looks like (graphics; docs/CODE_LAGEN.md): two chips under
## the minimap, against its right edge: the day ("DAG 3") and the time ("08:30") with a
## round icon, amber by day and dim by night. It shows what clock.gd hands it
## (show_clock); its width comes from hud_layout.gd.
##   const ClockView = preload("res://scripts/ui/hud/clock_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")
const ChipView = preload("res://scripts/ui/hud/chip_view.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const DISC := ["..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.."]
const DISC_SIZE := 12.0
const CHIP_SEPARATION := 8
const DAY_COLOUR := UiStyle.ACCENT
const NIGHT_COLOUR := UiStyle.MUTED

var _day: Label
var _time: Label
var _icon: PixelIcon


func _init() -> void:
	name = "Beeld"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonts := UiStyle.fonts()
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", CHIP_SEPARATION)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chips)
	_day = UiStyle.label("DAG 1", fonts.pixel, 11, UiStyle.TEXT, 0)
	var day_chip := ChipView.new()
	day_chip.add_item(_day)
	chips.add_child(day_chip)
	_icon = PixelIcon.new()
	_icon.bitmap = DISC
	_icon.colour = DAY_COLOUR
	_icon.pixel = DISC_SIZE / 7.0
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_time = UiStyle.label("12:00", fonts.pixel, 11, UiStyle.TEXT, 0)
	var time_chip := ChipView.new()
	time_chip.add_item(_icon)
	time_chip.add_item(_time)
	chips.add_child(time_chip)
	# against the right edge of the minimap, however wide the texts are
	chips.resized.connect(func() -> void: chips.position = Vector2(HudLayout.MINIMAP_SIZE - chips.size.x, 0.0))


## The time ("08:30") and the day ("DAG 3"); the icon dim when it is `night`.
func show_clock(time: String, day: String, night: bool) -> void:
	_time.text = time
	_day.text = day
	_icon.colour = NIGHT_COLOUR if night else DAY_COLOUR


func time_text() -> String:
	return _time.text


func day_text() -> String:
	return _day.text


func icon_colour() -> Color:
	return _icon.colour
