extends PanelContainer
## A chip of the HUD (graphics; docs/CODE_LAGEN.md): a small panel with a border, the
## things added to it in a row (an icon, a label). The day and the time under the minimap
## (clock_view.gd), the marker (waypoint_view.gd) and the location over it
## (location_view.gd) are chips.
##   const ChipView = preload("res://scripts/ui/hud/chip_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const SIDE_MARGIN := 8
const TOP_MARGIN := 4
const SEPARATION := 6

var _row: HBoxContainer


func _init() -> void:
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, 2)
	style.content_margin_left = SIDE_MARGIN
	style.content_margin_right = SIDE_MARGIN
	style.content_margin_top = TOP_MARGIN
	style.content_margin_bottom = TOP_MARGIN
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", SEPARATION)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)


## Adds `item` at the end of the row.
func add_item(item: Control) -> void:
	_row.add_child(item)


## The things in the row, left to right.
func items() -> Array:
	return _row.get_children()
