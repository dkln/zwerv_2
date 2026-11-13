extends Control
## The logo of a bank (Banks) on a cash machine's welcome screen: its pixel emblem (PIXEL px
## per pixel) and its name in the pixel font in the bank's colour beside it, the whole
## centred in the width it is given.
##   var logo := BankLogo.new()
##   logo.show_bank("og_bank", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))

const Banks = preload("res://scripts/world/things/banks.gd")

const PIXEL := 6.0
const NAME_SIZE := 30
const GAP := 14.0

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
	custom_minimum_size = Vector2(0.0, maxf(rows.size() * PIXEL, float(NAME_SIZE)) + 4.0)
	queue_redraw()


func _draw() -> void:
	if _bank.is_empty() or _font == null:
		return
	var rows: Array = _bank.emblem
	var emblem_width := (rows[0] as String).length() * PIXEL
	var name_text := String(_bank.name).to_upper()
	var name_width := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	var left := roundf((size.x - emblem_width - GAP - name_width) * 0.5)
	var top := roundf((size.y - rows.size() * PIXEL) * 0.5)
	var colours := {"a": _bank.colour, "b": _bank.second, "w": Color.WHITE}
	for row_index in rows.size():
		var row: String = rows[row_index]
		for column in row.length():
			var pixel := row[column]
			if colours.has(pixel):
				draw_rect(Rect2(left + column * PIXEL, top + row_index * PIXEL, PIXEL, PIXEL), colours[pixel])
	var baseline := roundf(size.y * 0.5 + _font.get_ascent(NAME_SIZE) * 0.5 - 2.0)
	draw_string(_font, Vector2(left + emblem_width + GAP, baseline), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, _bank.colour)
