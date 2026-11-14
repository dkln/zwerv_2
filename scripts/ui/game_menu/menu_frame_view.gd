extends Control
## What the frame of the game menu looks like (graphics; docs/CODE_LAGEN.md): the ink
## background, the design that scales with the window, the tab bar at the top ("[Q]
## INVENTARIS QUESTS KAART [E]", the open one filled amber; a line of text, the money and
## the close button on the right), the room for the pages under it and a slight CRT bend
## over it all. It shows what scripts/ui/game_menu.gd hands it and says what was clicked
## (tab_pressed, close_pressed); its sizes come from menu_frame_layout.gd.
##   const MenuFrameView = preload("res://scripts/ui/game_menu/menu_frame_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const MenuParts = preload("res://scripts/ui/game_menu/menu_parts_view.gd")
const MenuBox = preload("res://scripts/ui/game_menu/menu_box.gd")
const Layout = preload("res://scripts/ui/game_menu/menu_frame_layout.gd")
## The euro sign beside the money, as in the HUD, and how wide it is drawn (design pixels).
const EURO_BITMAP := ["...####", "..#....", "######.", ".#.....", "######.", "..#....", "...####"]
const EURO_WIDTH := 14.0

## A tab title was clicked.
signal tab_pressed(tab_name: String)
## "[ESC] SLUITEN" was clicked.
signal close_pressed

var _fonts := {}
var _root: Control
var _pages: Control
var _tabs_row: HBoxContainer
var _tab_boxes := {}         # tab name -> MenuBox
var _tab_labels := {}        # tab name -> Label
var _header: Label
var _money: Label
var _crt_overlay: ColorRect


func _init() -> void:
	name = "Beeld"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonts = MenuParts.fonts()
	var background := ColorRect.new()
	background.name = "Achtergrond"
	background.color = UiStyle.INK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	_root = Control.new()
	_root.name = "Ontwerp"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var column := MenuParts.vbox(0)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(column)
	column.add_child(_tab_bar())
	_pages = Control.new()
	_pages.name = "Tabbladen"
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_pages)


## A tab in the bar, after the ones before it: `tab_name` and the `title` on it.
func add_tab(tab_name: String, title: String) -> void:
	var tab := MenuParts.box(_tab_style(false), 0.0, true)
	var tab_label := UiStyle.label(title, _fonts.title_medium, 18)
	tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab.add_child(tab_label)
	tab.pressed.connect(func() -> void: tab_pressed.emit(tab_name))
	_tabs_row.add_child(tab)
	_tab_boxes[tab_name] = tab
	_tab_labels[tab_name] = tab_label


## The page of a tab, under the bar (it fills the room there).
func add_page(page: Control) -> void:
	_pages.add_child(page)


## The tab that is open: its title filled amber, the others plain.
func show_tab(tab_name: String) -> void:
	for name_of_tab: String in _tab_boxes:
		var on := name_of_tab == tab_name
		(_tab_boxes[name_of_tab] as MenuBox).style = _tab_style(on)
		var tab_label: Label = _tab_labels[name_of_tab]
		tab_label.add_theme_font_override("font", _fonts.title if on else _fonts.title_medium)
		tab_label.add_theme_color_override("font_color", UiStyle.INK if on else UiStyle.TEXT)


## The line of text on the right of the bar ("7 SPULLEN BIJ JE").
func show_header(text: String) -> void:
	_header.text = text


## The money beside the euro sign ("12,00").
func show_money(text: String) -> void:
	_money.text = text


## The slight bend over the menu: this curvature and this much rounded corner.
func show_bend(curvature: float, corner: float) -> void:
	if _crt_overlay:
		_crt_overlay.queue_free()
	_crt_overlay = UiStyle.make_crt_overlay(curvature, corner, Layout.DESIGN_SIZE)
	add_child(_crt_overlay)
	var overlay := _crt_overlay
	overlay.resized.connect(func() -> void:
		(overlay.material as ShaderMaterial).set_shader_parameter("screen_size", overlay.size))


## Scales the design to `window`; the layout fills the window at that scale.
func fit(window: Vector2) -> void:
	var factor := Layout.scale_for(window)
	if factor <= 0.0:
		return
	_root.scale = Vector2(factor, factor)
	_root.size = Layout.size_for(window, factor)


## The tab whose title is filled now ("" none): for the tests.
func shown_tab() -> String:
	for name_of_tab: String in _tab_boxes:
		if ((_tab_boxes[name_of_tab] as MenuBox).style as StyleBoxFlat).bg_color == UiStyle.ACCENT:
			return name_of_tab
	return ""


func header_text() -> String:
	return _header.text


func money_text() -> String:
	return _money.text


## How much the design is scaled now.
func design_scale() -> float:
	return _root.scale.x


func _tab_style(on: bool) -> StyleBoxFlat:
	return MenuParts.style(UiStyle.ACCENT if on else MenuParts.NOTHING, UiStyle.ACCENT, 0, Layout.TAB_PADDING_X)


func _key_label(text: String) -> Label:
	var key := UiStyle.label(text, _fonts.pixel, 11, UiStyle.MUTED)
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.custom_minimum_size = Vector2(Layout.TAB_KEY_WIDTH, 0)
	return key


func _tab_bar() -> Control:
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = UiStyle.PANEL
	bar_style.border_color = UiStyle.BORDER
	bar_style.border_width_bottom = Layout.TAB_BAR_BORDER
	bar_style.anti_aliasing = false
	bar_style.content_margin_left = Layout.PAGE_MARGIN_X
	bar_style.content_margin_right = Layout.PAGE_MARGIN_X
	var bar := MenuParts.box(bar_style)
	bar.name = "Tabs"
	bar.custom_minimum_size = Layout.tab_bar_size()
	var row := MenuParts.hbox(Layout.TAB_SEPARATION)
	bar.add_child(row)
	row.add_child(_key_label("[Q]"))
	_tabs_row = MenuParts.hbox(Layout.TAB_SEPARATION)
	row.add_child(_tabs_row)
	var right_key := _key_label("[E]")
	right_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right_key)
	row.add_child(MenuParts.spacer(false))
	_header = UiStyle.label("", UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.MUTED)
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_header)
	row.add_child(MenuParts.gap(Vector2(Layout.HEADER_GAP, 0)))
	# the money as in the HUD: a pixel euro sign and euros to the cent
	var coin := PixelIcon.new()
	coin.bitmap = EURO_BITMAP
	coin.colour = UiStyle.ACCENT
	coin.pixel = EURO_WIDTH / 7.0
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_money = UiStyle.label("0", _fonts.pixel, 13)
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_money)
	row.add_child(MenuParts.gap(Vector2(Layout.HEADER_GAP, 0)))
	var close_box := MenuParts.box(MenuParts.style(UiStyle.INK, UiStyle.BORDER, 2, 10, 6), 0.0, true)
	close_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_box.add_child(UiStyle.label("[ESC] SLUITEN", _fonts.pixel, 10, UiStyle.MUTED))
	close_box.pressed.connect(func() -> void: close_pressed.emit())
	row.add_child(close_box)
	return bar
