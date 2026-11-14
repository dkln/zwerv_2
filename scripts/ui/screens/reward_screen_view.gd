extends Control
## How the reward screen looks (the graphics layer of scripts/ui/reward_screen.gd, which is
## the behaviour and has this as its child; reward_screen_rules.gd has the logic,
## reward_screen_layout.gd the sizes): the world dimmed, one panel in the style of the HUD
## with what it is for and from whom, the item big (its voxel model turning, light rays
## behind it, in a frame in the colour of its rarity) or the XP big in its place, its name,
## rarity and line, the chips of what came with it and the line with the keys. It shows the
## page it is handed (show_item_page, show_xp_page, show_footer); it decides nothing.
##   const RewardScreenView = preload("res://scripts/ui/screens/reward_screen_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const ItemView = preload("res://scripts/ui/widgets/item_view.gd")
const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")
const RewardScreenLayout = preload("res://scripts/ui/screens/reward_screen_layout.gd")
const XP_COLOUR := Color("#8BE36B")
const DIM_ALPHA := 0.72
const RAYS_ALPHA := 0.12
## Seconds the screen takes to come up.
const FADE_IN := 0.2
## The kind of chip that is drawn in the colour of experience (the others in the text colour).
const XP_CHIP := "xp"

## What it is for and from whom, the stage (its frame, the rays, the item or the XP big),
## the name, rarity and line of the item, the chips and the line with the keys.
var heading: Label
var title: Label
var stage_frame: PanelContainer
var rays: LightRays
var item_view: ItemView
var big_xp: Label
var name_label: Label
var rarity: Label
var text: Label
var chips: HBoxContainer
var footer: Label
var _font_title: Font
var _font_pixel: Font
var _font_body: Font


func _init(font_title: Font = null, font_pixel: Font = null, font_body: Font = null) -> void:
	name = "Beeld"
	_font_title = font_title
	_font_pixel = font_pixel
	_font_body = font_body
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", RewardScreenLayout.COLUMN_SEPARATION)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel(centre).add_child(column)
	heading = _centred(UiStyle.label("", _font_pixel, 16, UiStyle.ACCENT))
	column.add_child(heading)
	title = _centred(UiStyle.label("", _font_title, 22, UiStyle.TEXT))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	column.add_child(_stage())
	name_label = _centred(UiStyle.label("", _font_title, 30, UiStyle.TEXT))
	column.add_child(name_label)
	rarity = _centred(UiStyle.label("", _font_pixel, 12, UiStyle.MUTED))
	column.add_child(rarity)
	text = _centred(UiStyle.label("", _font_body, 16, UiStyle.TEXT))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = RewardScreenLayout.text_size()
	column.add_child(text)
	chips = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", RewardScreenLayout.CHIP_SEPARATION)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(chips)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	footer = _centred(UiStyle.label("[ENTER] OK", _font_pixel, 13, UiStyle.MUTED))
	column.add_child(footer)


## A page with an item: `texts` what it says (RewardScreenRules.page_texts), the model of
## item `item_id` turning, the frame, the rays, the name and the rarity in `colour` (that
## of its rarity).
func show_item_page(texts: Dictionary, item_id: String, colour: Color) -> void:
	_show_texts(texts, colour)
	item_view.visible = true
	big_xp.visible = false
	item_view.show_item(item_id)
	rarity.add_theme_color_override("font_color", colour)


## A page with only experience: `texts` what it says, the XP big in place of an item.
func show_xp_page(texts: Dictionary) -> void:
	_show_texts(texts, XP_COLOUR)
	item_view.visible = false
	big_xp.visible = true
	big_xp.text = String(texts.get("big_xp", ""))


## Writes the line with the keys at the bottom.
func show_footer(footer_text: String) -> void:
	footer.text = footer_text


## Brings the screen up from nothing (FADE_IN s).
func fade_in() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)


## What the chips say now, left to right.
func chip_texts() -> Array[String]:
	var texts: Array[String] = []
	for chip in chips.get_children():
		if not chip.is_queued_for_deletion():
			texts.append((chip.get_child(0) as Label).text)
	return texts


## What every page has: the heading, the title, the name, the rarity, the line, the chips,
## with the frame, the rays and the name in `colour`.
func _show_texts(texts: Dictionary, colour: Color) -> void:
	heading.text = String(texts.get("heading", ""))
	title.text = String(texts.get("title", ""))
	title.visible = title.text != ""
	stage_frame.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.INK, colour, RewardScreenLayout.STAGE_BORDER))
	rays.colour = Color(colour, RAYS_ALPHA)
	name_label.text = String(texts.get("name", ""))
	name_label.add_theme_color_override("font_color", colour)
	rarity.text = String(texts.get("rarity", ""))
	rarity.visible = rarity.text != ""
	text.text = String(texts.get("text", ""))
	for chip in chips.get_children():
		chips.remove_child(chip)
		chip.queue_free()
	for chip: Array in texts.get("chips", []):
		chips.add_child(_chip(String(chip[0]), XP_COLOUR if String(chip[1]) == XP_CHIP else UiStyle.TEXT))
	chips.visible = chips.get_child_count() > 0


static func _centred(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _panel(centre: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Beloning"
	panel.custom_minimum_size = RewardScreenLayout.PANEL_SIZE
	var panel_style := UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, RewardScreenLayout.PANEL_BORDER)
	panel_style.content_margin_left = RewardScreenLayout.PADDING
	panel_style.content_margin_right = RewardScreenLayout.PADDING
	panel_style.content_margin_top = RewardScreenLayout.panel_margin_top()
	panel_style.content_margin_bottom = RewardScreenLayout.panel_margin_top()
	panel_style.shadow_color = UiStyle.INK
	panel_style.shadow_offset = Vector2.ONE * UiStyle.SHADOW_OFFSET
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	return panel


## The stage: the rays, the item turning (or the XP) over them.
func _stage() -> PanelContainer:
	stage_frame = PanelContainer.new()
	stage_frame.custom_minimum_size = RewardScreenLayout.STAGE_SIZE
	stage_frame.clip_contents = true
	stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_frame.add_child(stage)
	rays = LightRays.new()
	rays.count = 12
	rays.length = 0.8
	stage.add_child(rays)
	item_view = ItemView.new()
	item_view.name = "Itembeeld"
	item_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(item_view)
	big_xp = _centred(UiStyle.label("", _font_title, 64, XP_COLOUR))
	big_xp.set_anchors_preset(Control.PRESET_FULL_RECT)
	big_xp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_xp.add_theme_color_override("font_shadow_color", UiStyle.INK)
	big_xp.add_theme_constant_override("shadow_offset_x", 4)
	big_xp.add_theme_constant_override("shadow_offset_y", 4)
	stage.add_child(big_xp)
	return stage_frame


func _chip(chip_text: String, colour: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.INK, colour, RewardScreenLayout.CHIP_BORDER)
	style.content_margin_left = RewardScreenLayout.CHIP_MARGIN_SIDE
	style.content_margin_right = RewardScreenLayout.CHIP_MARGIN_SIDE
	style.content_margin_top = RewardScreenLayout.CHIP_MARGIN_TOP
	style.content_margin_bottom = RewardScreenLayout.CHIP_MARGIN_TOP
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(UiStyle.label(chip_text, _font_pixel, 14, colour))
	return chip
