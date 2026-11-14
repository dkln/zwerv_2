extends PanelContainer
## What the money of the HUD looks like (the node "Geld", bottom right; graphics,
## docs/CODE_LAGEN.md): a panel with a euro sign and the amount. It shows the text it is
## handed (show_amount; written by scripts/common/money_text.gd). Where it stands:
## hud_layout.gd.
##   const MoneyView = preload("res://scripts/ui/hud/money_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
## A euro sign: a C open to the right with two bars through it.
const EURO := ["...####", "..#....", "######.", ".#.....", "######.", "..#....", "...####"]
const EURO_SIZE := 16.0
const SIDE_MARGIN := 12
const TOP_MARGIN := 8
const SEPARATION := 8

var _amount: Label


func _init() -> void:
	name = "Geld"
	var style := UiStyle.box_style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, 2)
	style.content_margin_left = SIDE_MARGIN
	style.content_margin_right = SIDE_MARGIN
	style.content_margin_top = TOP_MARGIN
	style.content_margin_bottom = TOP_MARGIN
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := PixelIcon.new()
	coin.bitmap = EURO
	coin.colour = UiStyle.ACCENT
	coin.pixel = EURO_SIZE / 7.0
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_amount = UiStyle.label("0", UiStyle.fonts().pixel, 14, UiStyle.TEXT, 0)
	row.add_child(_amount)
	add_child(row)


## The amount as it is written ("1.284,50"; the euro sign is the icon before it).
func show_amount(text: String) -> void:
	_amount.text = text


func amount_text() -> String:
	return _amount.text
