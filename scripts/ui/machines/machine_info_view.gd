extends PanelContainer
## The one panel bottom left of a machine's close-up (a graphics layer of
## scripts/ui/machines/machine_screen.gd; machine_screen_view.gd has this as its child,
## machine_info_layout.gd has its sizes): the tray (its heading with the place, the title
## and the lines of what came out of the machine: show_tray; hidden while empty), a line,
## and your pockets (show_pockets). Anchored to the bottom left, it grows upwards with what
## is in it. It builds and styles them and shows what it is handed; it decides nothing.
##   const MachineInfoView = preload("res://scripts/ui/machines/machine_info_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MachineLook = preload("res://scripts/ui/machines/machine_look.gd")
const MachineInfoLayout = preload("res://scripts/ui/machines/machine_info_layout.gd")
const NODE_NAME := "Info"
## The font sizes of its lines and of its headings (the heading of the tray, of the pockets
## and the title of what came out a little bigger).
const LINE_SIZE := 13
const HEADING_SIZE := 11
const TRAY_HEADING_SIZE := HEADING_SIZE + 2
const POCKETS_HEADING_SIZE := HEADING_SIZE + 3
const TRAY_TITLE_SIZE := HEADING_SIZE + 4
## What came out fades and slides into the tray in so long (seconds).
const TRAY_FADE_SECONDS := 0.35
const TRAY_SLIDE_SECONDS := 0.5

var _font_title: Font
var _font_body: Font
var _tray: VBoxContainer
var _tray_section: VBoxContainer          # the tray and its heading, hidden while empty
var _rule: ColorRect                      # the line between the tray and the pockets
var _tray_title: Label
var _pockets: VBoxContainer


func _init() -> void:
	name = NODE_NAME
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, MachineInfoLayout.BORDER)
	style.content_margin_left = MachineInfoLayout.PADDING.x
	style.content_margin_right = MachineInfoLayout.PADDING.x
	style.content_margin_top = MachineInfoLayout.PADDING.y
	style.content_margin_bottom = MachineInfoLayout.PADDING.y
	style.shadow_color = Color.BLACK
	style.shadow_offset = Vector2(UiStyle.SHADOW_OFFSET, UiStyle.SHADOW_OFFSET)
	add_theme_stylebox_override("panel", style)
	# anchored to the bottom left, growing upwards with what is in it
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = MachineInfoLayout.sides().x
	offset_right = MachineInfoLayout.sides().y
	offset_top = MachineInfoLayout.bottom()
	offset_bottom = MachineInfoLayout.bottom()
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	clip_contents = true


## Builds what is in the panel: the tray under `heading` (in `font_heading`; hidden: it is
## empty), the line and the pockets; titles in `font_title`, lines in `font_body`.
func build(heading: String, font_heading: Font, font_title: Font, font_body: Font) -> void:
	_font_title = font_title
	_font_body = font_body
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", MachineInfoLayout.SECTION_SEPARATION)
	add_child(column)
	_tray_section = VBoxContainer.new()
	_tray_section.add_theme_constant_override("separation", MachineInfoLayout.LINE_SEPARATION)
	column.add_child(_tray_section)
	_tray_section.add_child(MachineLook.label(heading, font_heading, TRAY_HEADING_SIZE, UiStyle.MUTED))
	_tray = VBoxContainer.new()
	_tray.add_theme_constant_override("separation", MachineInfoLayout.LINE_SEPARATION)
	_tray_section.add_child(_tray)
	_tray_title = MachineLook.label("", font_title, TRAY_TITLE_SIZE, UiStyle.ACCENT)
	_tray.add_child(_tray_title)
	_tray_section.visible = false
	_rule = ColorRect.new()
	_rule.color = UiStyle.BORDER
	_rule.custom_minimum_size = Vector2(0, MachineInfoLayout.RULE_HEIGHT)
	_rule.visible = false
	column.add_child(_rule)
	_pockets = VBoxContainer.new()
	_pockets.add_theme_constant_override("separation", MachineInfoLayout.LINE_SEPARATION)
	column.add_child(_pockets)


## What came out of the machine: `title` and `lines` (in `colour`) in place of what was in
## the tray; the tray and the line under it show when `shown`. `animated`: it fades and
## slides in.
func show_tray(title: String, lines: Array, colour: Color, shown: bool, animated: bool) -> void:
	for child in _tray.get_children():
		if child != _tray_title:
			child.queue_free()
	_tray_title.text = title
	for line: String in lines:
		_tray.add_child(MachineLook.label(line, _font_body, LINE_SIZE, colour))
	_tray_section.visible = shown
	_rule.visible = shown
	if animated:
		_tray.modulate.a = 0.0
		_tray.position.y = MachineInfoLayout.TRAY_SLIDE_FROM
		var slide := _tray.create_tween().set_parallel()
		slide.tween_property(_tray, "modulate:a", 1.0, TRAY_FADE_SECONDS)
		slide.tween_property(_tray, "position:y", 0.0, TRAY_SLIDE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## What you carry: `heading` over `lines` ([text, colour] each), in place of what stood there.
func show_pockets(heading: String, lines: Array) -> void:
	if _pockets == null:
		return
	for child in _pockets.get_children():
		child.queue_free()
	_pockets.add_child(MachineLook.label(heading, _font_title, POCKETS_HEADING_SIZE, UiStyle.ACCENT))
	for line: Array in lines:
		_pockets.add_child(MachineLook.label(String(line[0]), _font_body, LINE_SIZE, line[1]))


## Whether the tray (and the line under it) shows.
func tray_showing() -> bool:
	return _tray_section != null and _tray_section.visible and _rule.visible


func tray_title() -> String:
	return _tray_title.text if _tray_title else ""


## What the tray says now, top to bottom: its title and its lines.
func tray_texts() -> Array:
	return _texts(_tray)


## What the pockets say now, top to bottom: the heading and the lines.
func pocket_texts() -> Array:
	return _texts(_pockets)


## The labels of the tray and of the pockets that stand there now (not the ones on their way out).
func tray_labels() -> Array:
	return _labels(_tray)


func pocket_labels() -> Array:
	return _labels(_pockets)


static func _texts(box: Node) -> Array:
	var texts := []
	for found: Label in _labels(box):
		texts.append(found.text)
	return texts


static func _labels(box: Node) -> Array:
	var labels := []
	if box == null:
		return labels
	for child in box.get_children():
		if child is Label and not child.is_queued_for_deletion():
			labels.append(child)
	return labels
