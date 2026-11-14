extends RefCounted
## The building blocks every view of the game menu is made of (graphics;
## docs/CODE_LAGEN.md): the colours of the designs beyond the shared palette, the fonts, a
## flat style, a box (menu_box.gd), rows and columns, and the frame of a page (its margins
## and its line of keys). Only static functions that make nodes; used by
## menu_frame_view.gd, inventory_tab_view.gd, quest_tab_view.gd and map_tab_view.gd.
##   const MenuParts = preload("res://scripts/ui/game_menu/menu_parts_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MenuBox = preload("res://scripts/ui/game_menu/menu_box.gd")
const FrameLayout = preload("res://scripts/ui/game_menu/menu_frame_layout.gd")

## Colours of the designs beyond the shared palette (UiStyle).
const RAISED := UiStyle.RAISED          # a chosen button or row
const SELECTED_SLOT := Color("#232A55")
const EMPTY_SLOT := Color("#10132A")
const EMPTY_BORDER := Color("#232850")
const SOFT_TEXT := Color("#C9CCE6")
const GOOD := Color("#8BE36B")
const BAD := Color("#FF5D73")
const NOTHING := Color(0, 0, 0, 0)
## How far the top of a slanted glyph leans to the right (a faux italic).
const SLANT := 0.2


## The fonts of the menu: those of every screen (UiStyle.fonts: "title", "title_medium",
## "pixel", "pixel_bold", "body") and "title_spaced" (the title with 1 px between its
## letters), "body_bold" (JetBrains Mono semibold) and "italic" (JetBrains Mono, slanted).
static func fonts() -> Dictionary:
	var all := UiStyle.fonts()
	var body := UiStyle.font(UiStyle.FONT_BODY)
	all["body_bold"] = UiStyle.weighted(body, 600)
	var slanted := UiStyle.weighted(body, 400) as FontVariation
	# FreeType's xy: the top of a glyph leans to the right
	slanted.variation_transform = Transform2D(Vector2(1.0, SLANT), Vector2(0.0, 1.0), Vector2.ZERO)
	all["italic"] = slanted
	all["title_spaced"] = UiStyle.spaced(all.title, 1)
	return all


## A flat style: background, a border of `border_width` all round, content margins.
static func style(background: Color, border: Color, border_width: int, margin_x := 0, margin_y := 0) -> StyleBoxFlat:
	var flat := UiStyle.box_style(background, border, border_width)
	flat.content_margin_left = margin_x
	flat.content_margin_right = margin_x
	flat.content_margin_top = margin_y
	flat.content_margin_bottom = margin_y
	return flat


## A style of only lines: one over it (`top` px) and one under it (`bottom` px), with
## this much room between the lines and what is in it.
static func lines_style(top: int, bottom: int, margin_top: int, margin_bottom: int) -> StyleBoxFlat:
	var lines := StyleBoxFlat.new()
	lines.bg_color = NOTHING
	lines.border_color = UiStyle.BORDER
	lines.border_width_top = top
	lines.border_width_bottom = bottom
	lines.content_margin_top = margin_top
	lines.content_margin_bottom = margin_bottom
	lines.anti_aliasing = false
	return lines


## A box in this style, with a hard shadow of `shadow` px; `clickable`: it takes the mouse.
static func box(box_style: StyleBox, shadow := 0.0, clickable := false) -> MenuBox:
	var made := MenuBox.new(box_style)
	made.shadow_offset = shadow
	if clickable:
		made.mouse_filter = Control.MOUSE_FILTER_STOP
		made.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return made


static func vbox(separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return column


static func hbox(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


## Something that takes the room that is left, down (`vertical`) or across.
static func spacer(vertical := true) -> Control:
	var room := Control.new()
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return room


## Something of a fixed smallest size that shows nothing.
static func gap(size: Vector2) -> Control:
	var room := Control.new()
	room.custom_minimum_size = size
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return room


## Makes `page` a page under the tab bar: its margins and, at the bottom, the line of
## `keys` in `key_font`. Returns the row its columns go in.
static func fill_page(page: MarginContainer, keys: String, key_font: Font) -> HBoxContainer:
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("margin_left", FrameLayout.PAGE_MARGIN_X)
	page.add_theme_constant_override("margin_right", FrameLayout.PAGE_MARGIN_X)
	page.add_theme_constant_override("margin_top", FrameLayout.PAGE_MARGIN_Y)
	page.add_theme_constant_override("margin_bottom", FrameLayout.PAGE_MARGIN_BOTTOM)
	var column := vbox(FrameLayout.PAGE_SEPARATION)
	page.add_child(column)
	var content := hbox(FrameLayout.CONTENT_SEPARATION)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	column.add_child(UiStyle.label(keys, key_font, 10, UiStyle.MUTED))
	return content
