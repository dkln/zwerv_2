extends Control
## The reward screen of the HUD (GameHud.show_reward): what you got for a task or a mission
## done (Story) or from someone in the street (Conversations: a "beloning"), in a screen of
## its own that you press away. Over the dimmed world (the game paused) one panel in the
## style of the HUD (UiStyle: INK panel, BORDER frame, ACCENT, the pixel fonts):
## - at the top what it is for ("TAAK VOLBRACHT", "MISSIE VOLBRACHT", "GEKREGEN") and from
##   what or whom (the task, the mission, "Van de toerist");
## - in the middle the item big, its voxel model turning slowly round (ItemView), light rays
##   turning behind it (LightRays, as behind a new mission), in a frame in the colour of its
##   rarity; without an item (only experience) the XP big in their place;
## - under it the name of the item in the colour of its rarity, its rarity, and its line
##   (Items "text"); then the chips of what came with it ("+50 XP", "2 x");
## - at the bottom "[ENTER] OK".
## With more than one item, one page each (the XP on the first); Enter, Space, E, Escape or
## a click goes on, the last closes and `finished` fires. Opening plays the reward jingle
## (the HUD: REWARD_JINGLE).
## A reward: {"heading", "title", "xp": int, "items": [{"item": id, "count": int}]}.
## This is the behaviour layer: open or not, the pause, the page it is on, the keys and the
## wait before they go on. screens/reward_screen_rules.gd has the logic (the pages of a
## reward, what a page says, from when a key goes on), screens/reward_screen_layout.gd the
## sizes, screens/reward_screen_view.gd builds the screen and shows the page it is handed.
##   const RewardScreen = preload("res://scripts/ui/reward_screen.gd")

signal finished

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const Items = preload("res://scripts/player/items.gd")
const ItemView = preload("res://scripts/ui/widgets/item_view.gd")
const RewardScreenRules = preload("res://scripts/ui/screens/reward_screen_rules.gd")
const RewardScreenView = preload("res://scripts/ui/screens/reward_screen_view.gd")
## The numbers and labels of the rules, here for whoever has the screen at hand.
const KEYS_AFTER := RewardScreenRules.KEYS_AFTER
const RARITY_LABELS := RewardScreenRules.RARITY_LABELS

## Fonts, set by the HUD before it is added.
var font_title: Font
var font_pixel: Font
var font_body: Font

var _view: RewardScreenView
var _pages: Array[Dictionary] = []   # per page: {"heading", "title", "xp", "item", "count"}
var _page_index := 0
var _was_paused := false
## Whether the game must stay paused when this closes (another screen still up: the story
## box, the shop, the pause menu; GameHud sets it). Else as it was before it opened.
var keep_paused := Callable()
var _since := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_view = RewardScreenView.new(font_title, font_pixel, font_body)
	add_child(_view)


func is_showing() -> bool:
	return visible


## What the screen looks like (the view; null before it is in the tree), for whoever looks
## at what is shown.
func view() -> RewardScreenView:
	return _view


## Opens on `reward` (see the top); `done` is called when it is pressed away.
func open(reward: Dictionary, done := Callable()) -> void:
	_pages = pages_of(reward)
	if _pages.is_empty():
		if done.is_valid():
			done.call()
		return
	if done.is_valid():
		finished.connect(done, CONNECT_ONE_SHOT)
	_page_index = 0
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
		_view.fade_in()
	_show_page()


## The pages of `reward`: one for each item (the XP on the first), or one with only the XP
## (RewardScreenRules.pages_of, here for whoever has the screen at hand: the HUD).
static func pages_of(reward: Dictionary) -> Array[Dictionary]:
	return RewardScreenRules.pages_of(reward)


## The page shown now (for the checks).
func current_page() -> Dictionary:
	return _pages[_page_index] if visible and _page_index < _pages.size() else {}


## The item view (for the checks).
func item_view() -> ItemView:
	return _view.item_view


## A key press or click while open: true if the screen used it (every key is its own then).
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	var go_on := false
	if event is InputEventKey and event.pressed and not event.echo:
		go_on = (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E, KEY_ESCAPE]
	elif event is InputEventMouseButton and event.pressed:
		go_on = (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if go_on and RewardScreenRules.keys_work(_since):
		next_page()
	return true


## On to the next page, or closed after the last.
func next_page() -> void:
	if not visible:
		return
	_page_index += 1
	if _page_index < _pages.size():
		UiSounds.play(self, "doe", -6.0)
		_show_page()
		return
	visible = false
	get_tree().paused = bool(keep_paused.call()) if keep_paused.is_valid() else _was_paused
	UiSounds.play(self, "terug", -6.0)
	finished.emit()


func _process(delta: float) -> void:
	if visible:
		_since += delta


func _show_page() -> void:
	_since = 0.0
	var page: Dictionary = _pages[_page_index]
	var item_id := String(page.item)
	if item_id != "":
		_view.show_item_page(RewardScreenRules.page_texts(page, Items.item(item_id)), item_id, Items.rarity_colour(item_id))
	else:
		_view.show_xp_page(RewardScreenRules.page_texts(page, {}))
	_view.show_footer(footer_text(_page_index, _pages.size()))


## The line at the bottom of page `page_index` of `page_count` (RewardScreenRules.footer_text,
## here for whoever has the screen at hand).
static func footer_text(page_index: int, page_count: int) -> String:
	return RewardScreenRules.footer_text(page_index, page_count)
