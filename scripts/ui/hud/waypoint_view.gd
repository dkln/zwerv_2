extends Control
## What the marker set on the map looks like under the minimap (graphics;
## docs/CODE_LAGEN.md): a chip as wide as the minimap with a pink diamond and a text (the
## name of the place and how far it is; a long one ends in an ellipsis). It shows what
## waypoint.gd hands it (show_text). Its mark on the minimap: minimap_view.gd; its beam in
## the town: scripts/world/town/waypoint_beacon.gd.
##   const WaypointView = preload("res://scripts/ui/hud/waypoint_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MapLook = preload("res://scripts/ui/hud/map_look.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")
const ChipView = preload("res://scripts/ui/hud/chip_view.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const DIAMOND := ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."]
const DIAMOND_SIZE := 12.0

var _label: Label


func _init() -> void:
	name = "Beeld"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PixelIcon.new()
	icon.bitmap = DIAMOND
	icon.colour = MapLook.WAYPOINT_COLOUR
	icon.pixel = DIAMOND_SIZE / 7.0
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label = UiStyle.label("", UiStyle.fonts().pixel, 11, UiStyle.TEXT, 0)
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip := ChipView.new()
	chip.add_item(icon)
	chip.add_item(_label)
	chip.custom_minimum_size = Vector2(HudLayout.MINIMAP_SIZE, 0)
	add_child(chip)


## The text in the chip.
func show_text(text: String) -> void:
	_label.text = text


func shown_text() -> String:
	return _label.text
