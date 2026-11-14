extends Control
## The logo of a bank (Banks) on a cash machine's welcome screen: its pixel emblem and its
## name in the pixel font in the bank's colour beside it, the whole centred in the width it
## is given. Graphics (docs/CODE_LAGEN.md): a picture on its own, nothing to decide; its
## sizes come from bank_logo_layout.gd.
##   const BankLogo = preload("res://scripts/ui/widgets/bank_logo.gd")
##   var logo := BankLogo.new()
##   logo.show_bank("og_bank", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))

const Banks = preload("res://scripts/world/things/banks.gd")
const BankLogoLayout = preload("res://scripts/ui/widgets/bank_logo_layout.gd")

var bank_id := ""
var _bank := {}
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the logo of bank `id` with its name in `font`.
func show_bank(id: String, font: Font) -> void:
	bank_id = id
	_bank = Banks.bank(id)
	_font = font
	var rows: Array = _bank.emblem
	custom_minimum_size = Vector2(0.0, BankLogoLayout.minimum_height(rows.size()))
	queue_redraw()


func _draw() -> void:
	if _bank.is_empty() or _font == null:
		return
	var rows: Array = _bank.emblem
	var emblem := BankLogoLayout.emblem_size(rows)
	var name_text := String(_bank.name).to_upper()
	var name_size := BankLogoLayout.NAME_SIZE
	var name_width := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var origin := BankLogoLayout.emblem_origin(size, emblem, name_width)
	var colours := {"a": _bank.colour, "b": _bank.second, "w": Color.WHITE}
	for row_index in rows.size():
		var row: String = rows[row_index]
		for column in row.length():
			if colours.has(row[column]):
				draw_rect(BankLogoLayout.pixel_rect(origin, column, row_index), colours[row[column]])
	draw_string(_font, BankLogoLayout.name_position(origin, emblem, size.y, _font.get_ascent(name_size)), name_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, _bank.colour)
