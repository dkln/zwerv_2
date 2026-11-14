extends Control
## The level-up screen of the HUD (GameHud.show_level_up): a level up is a screen of its own in
## which you choose one of your stats to make stronger. Over the dimmed world (the game
## paused), in the style of the reward screen (UiStyle: INK panel, ACCENT frame, pixel fonts):
## - at the top "LEVEL OMHOOG" and the new level big ("LEVEL 3"), with the XP that did it
##   ("+150 XP") when it came with a reward (GameHud.show_reward: one screen for both);
## - one row per stat (OPTIONS): its icon and colour (GameHud.STATS / PIXEL_ICONS), its name,
##   what it does for you and its maximum now -> after;
## - at the bottom the keys.
## W/S or the arrows choose, 1..4 pick at once, Enter, Space or E (or a click on a row) takes it.
## The choice goes to `choose` (PlayerController.raise_stat); then it closes and `finished`
## fires. Escape does nothing: a level up is always used.
## This is the behaviour layer: open or not, the pause, the keys and the mouse, which stat
## is chosen, taking it. screens/level_up_screen_rules.gd has the logic (the stats, the next
## one, from when a key takes, the texts), screens/level_up_screen_layout.gd the sizes,
## screens/level_up_screen_view.gd builds the screen and shows what it is handed.
##   const LevelUpScreen = preload("res://scripts/ui/level_up_screen.gd")

signal finished

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const LevelUpScreenRules = preload("res://scripts/ui/screens/level_up_screen_rules.gd")
const LevelUpScreenView = preload("res://scripts/ui/screens/level_up_screen_view.gd")
## The numbers and the stats of the layers, here for whoever has the screen at hand.
const KEYS_AFTER := LevelUpScreenRules.KEYS_AFTER
const OPTIONS := LevelUpScreenRules.OPTIONS

## Fonts, set by the HUD before it is added.
var font_title: Font
var font_pixel: Font
var font_body: Font
## GameHud.STATS and GameHud.PIXEL_ICONS: colour and icon per stat.
var stat_looks := {}
var pixel_icons := {}
## Called to the HUD when it closes: is the game kept paused (another screen still up)?
var keep_paused := Callable()

var _view: LevelUpScreenView
var _level := 0
var _choose := Callable()            # Callable(stat name), the player's raise_stat
var _current := Callable()           # Callable(stat name) -> Vector2(value, maximum), to show now -> after
var _raise := {}                     # stat name -> how much its maximum goes up
var _selected := 0
var _since := 0.0
var _was_paused := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_view = LevelUpScreenView.new(font_title, font_pixel, font_body, OPTIONS, stat_looks, pixel_icons)
	add_child(_view)


func is_showing() -> bool:
	return visible


## What the screen looks like (the view; null before it is in the tree), for whoever looks
## at what is shown.
func view() -> LevelUpScreenView:
	return _view


## Opens for `level`: `choose` gets the stat chosen, `current` gives (value, maximum) of a stat,
## `raise` how much each stat goes up (stat name -> amount).
func open(level: int, choose: Callable, current: Callable, raise: Dictionary, xp_gained := 0) -> void:
	_level = level
	_view.show_xp(LevelUpScreenRules.xp_text(xp_gained), LevelUpScreenRules.shows_xp(xp_gained))
	_choose = choose
	_current = current
	_raise = raise
	_view.show_level(LevelUpScreenRules.level_text(level))
	_selected = 0
	_since = 0.0
	_refresh()
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
		_view.fade_in()


## The stat chosen now (for the checks).
func selected_stat() -> String:
	return LevelUpScreenRules.stat_at(_selected)


## A key press or click while open: true if the screen used it (every key is its own then).
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_W, KEY_UP:
				_select(LevelUpScreenRules.next_index(_selected, -1))
			KEY_S, KEY_DOWN:
				_select(LevelUpScreenRules.next_index(_selected, 1))
			KEY_1, KEY_2, KEY_3, KEY_4:
				if LevelUpScreenRules.keys_work(_since):
					_select(key - KEY_1)
					take()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				if LevelUpScreenRules.keys_work(_since):
					take()
		return true
	if event is InputEventMouseMotion:
		var hovered := _row_at((event as InputEventMouseMotion).position)
		if hovered >= 0 and hovered != _selected:
			_select(hovered)
		return true
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var clicked := _row_at((event as InputEventMouseButton).position)
		if clicked >= 0 and LevelUpScreenRules.keys_work(_since):
			_select(clicked)
			take()
		return true
	return event is InputEventKey or event is InputEventMouseButton


## Takes the stat chosen now: raised, and the screen closes.
func take() -> void:
	if not visible:
		return
	if _choose.is_valid():
		_choose.call(selected_stat())
	visible = false
	get_tree().paused = bool(keep_paused.call()) if keep_paused.is_valid() else _was_paused
	UiSounds.play(self, "doe", -4.0)
	finished.emit()


func _process(delta: float) -> void:
	if visible:
		_since += delta


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	UiSounds.play(self, "kies", -8.0)
	_refresh()


## The row under a point of the window (the event's position), -1 for none.
func _row_at(point: Vector2) -> int:
	return _view.row_at(point)


## The rows anew: the chosen one lit, per stat its maximum now -> after.
func _refresh() -> void:
	var value_texts: Array[String] = []
	for option: Dictionary in OPTIONS:
		var stat_name := String(option.stat)
		var now: Vector2 = _current.call(stat_name) if _current.is_valid() else Vector2.ZERO
		value_texts.append(LevelUpScreenRules.value_text(now.y, float(_raise.get(stat_name, 0.0))))
	_view.show_rows(_selected, value_texts)


## A stat's maximum now and after the level up (LevelUpScreenRules.value_text, here for
## whoever has the screen at hand).
static func value_text(maximum: float, raised: float) -> String:
	return LevelUpScreenRules.value_text(maximum, raised)
