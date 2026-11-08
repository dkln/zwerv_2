class_name ActionPrompts
extends VBoxContainer
## The actions the player can do now, in the style of the HUD's action prompt: one under
## the other, each a key cap ("SPATIE") and what it does ("Overslaan") on an ink panel
## with a border. Context-sensitive: set_actions replaces them whenever what can be done
## changes (an empty list hides it). Mouse clicks go through it.
##   var prompts := ActionPrompts.new()
##   prompts.set_actions([["SPATIE", "Overslaan"], ["ENTER", "Sneller"]])

const FONT_KEY := "res://assets/fonts/Silkscreen-Bold.ttf"
const FONT_TEXT := "res://assets/fonts/JetBrainsMono.ttf"
const FONT_FALLBACK := "res://assets/fonts/Rubik.ttf"
const GAP := 8

var _actions: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", GAP)


## The actions shown, top to bottom: [key text, action text] each.
func set_actions(actions: Array) -> void:
	if actions == _actions:
		return
	_actions = actions.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for action: Array in _actions:
		add_child(_prompt(str(action[0]), str(action[1])))
	visible = not _actions.is_empty()


func actions() -> Array:
	return _actions.duplicate(true)


## One action: key cap `key_text` and `action_text` beside it on an ink panel.
static func _prompt(key_text: String, action_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := GameHud._box_style(GameHud.TRANSLUCENT_INK, GameHud.BORDER, 2)
	style.content_margin_left = 10
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var key := PanelContainer.new()
	var key_style := GameHud._box_style(GameHud.TEXT, GameHud.TEXT, 0)
	key_style.content_margin_left = 8
	key_style.content_margin_right = 8
	key_style.content_margin_top = 4
	key_style.content_margin_bottom = 4
	key_style.shadow_color = GameHud.MUTED
	key_style.shadow_offset = Vector2(0, 3)
	key.add_theme_stylebox_override("panel", key_style)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_label := Label.new()
	key_label.text = key_text
	key_label.add_theme_font_override("font", _font(FONT_KEY))
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_color", GameHud.INK)
	key.add_child(key_label)
	row.add_child(key)
	var action := Label.new()
	action.text = action_text
	action.add_theme_font_override("font", GameHud._weighted(_font(FONT_TEXT), 400))
	action.add_theme_font_size_override("font_size", 14)
	action.add_theme_color_override("font_color", GameHud.TEXT)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	return panel


static func _font(path: String) -> Font:
	return load(path) if ResourceLoader.exists(path) else load(FONT_FALLBACK)
