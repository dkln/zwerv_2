extends RefCounted
## Unit tests of the reward screen (scripts/ui/reward_screen.gd) on its own: its pages (one
## per item, the XP on the first, only XP alone), the screen itself (the item turning,
## pressed away, the game paused meanwhile), the footer, the keys and the pause after it.
##   tests/run_unit_tests.sh reward_screen

const RewardScreen = preload("res://scripts/ui/reward_screen.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The reward screen has one page per item with the XP on the first, one page for XP
## alone, and none for nothing.
func test_the_pages_of_the_reward_screen(test) -> void:
	var two := RewardScreen.pages_of({"heading": "GEKREGEN", "title": "Van de toerist", "xp": 25,
		"items": [{"item": "appel", "count": 1}, {"item": "koffie", "count": 3}]})
	test.check(two.size() == 2, "één bladzijde per item")
	test.check(int(two[0].xp) == 25 and int(two[1].xp) == 0, "de XP op de eerste")
	test.check(two[1].item == "koffie" and int(two[1].count) == 3, "met hoeveel")
	var only_xp := RewardScreen.pages_of({"xp": 100})
	test.check(only_xp.size() == 1 and only_xp[0].item == "", "alleen XP: één bladzijde zonder item")
	test.check(RewardScreen.pages_of({}).is_empty(), "niets: geen scherm")


## The open reward screen pauses the game and shows the item's model, name and text; a
## game key does not close it at once, Enter does and the game goes on.
func test_the_reward_screen_shows_the_item_and_is_pressed_away(test) -> void:
	var screen := RewardScreen.new()
	tree.root.add_child(screen)
	var closed := [false]
	screen.open({"heading": "GEKREGEN", "title": "Van iemand", "xp": 25, "items": [{"item": "kroket"}]},
		func() -> void: closed[0] = true)
	test.check(screen.is_showing() and tree.paused, "open, het spel staat stil")
	test.check(screen.current_page().item == "kroket", "de kroket")
	test.check(screen.item_view().mesh() != null, "het model van het item in beeld")
	test.check(screen._name.text == "WARME KROKET" and screen._text.text != "", "zijn naam en zijn tekstje")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	screen.handle_input(key)
	test.check(screen.is_showing(), "niet meteen weg (een toets van het spel)")
	screen._since = 1.0
	test.check(screen.handle_input(key), "Enter is van het scherm")
	test.check(not screen.is_showing() and closed[0] and not tree.paused, "weggedrukt: dicht, het spel gaat door")
	screen.free()


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


## pages_of skips entries without an item, counts one when no count is given and names the
## page "BELONING" when the reward has no heading.
func test_pages_of_edge_cases(test) -> void:
	var pages := RewardScreen.pages_of({"xp": 10, "items": [{"item": ""}, {"count": 2}, {"item": "appel"}]})
	test.check(pages.size() == 1 and pages[0].item == "appel" and int(pages[0].count) == 1 and int(pages[0].xp) == 10,
		"items zonder naam overgeslagen, één stuk als er niets staat, de XP op de eerste echte")
	test.check(pages[0].heading == "BELONING" and pages[0].title == "", "zonder kop: BELONING, zonder titel")
	test.check(RewardScreen.pages_of({"xp": 0}).is_empty() and RewardScreen.pages_of({"xp": -5}).is_empty(), "geen of negatieve XP zonder items: geen bladzijde")
	var only_empty := RewardScreen.pages_of({"xp": 30, "items": [{"item": ""}]})
	test.check(only_empty.size() == 1 and only_empty[0].item == "" and int(only_empty[0].xp) == 30, "alleen lege items: de bladzijde met alleen XP")


func test_footer_text(test) -> void:
	test.check(RewardScreen.footer_text(0, 1) == "[ENTER] OK", "een bladzijde: OK")
	test.check(RewardScreen.footer_text(0, 3) == "[ENTER] VERDER  1 / 3", "de eerste van drie: verder, 1 / 3")
	test.check(RewardScreen.footer_text(2, 3) == "[ENTER] OK", "de laatste van drie: OK")


## A reward with nothing in it does not open the screen: `done` at once, the game not paused.
func test_an_empty_reward_does_not_open(test) -> void:
	var screen := RewardScreen.new()
	tree.root.add_child(screen)
	var was_paused := tree.paused
	var closed := [0]
	screen.open({"heading": "GEKREGEN"}, func() -> void: closed[0] += 1)
	test.check(not screen.is_showing() and closed[0] == 1 and tree.paused == was_paused, "niets gekregen: geen scherm, wel meteen klaar")
	test.check(screen.current_page().is_empty(), "geen bladzijde in beeld")
	test.check(not screen.handle_input(_key(KEY_ENTER)), "dicht: toetsen zijn niet voor het scherm")
	screen.next_page()
	test.check(closed[0] == 1, "verder op een dicht scherm doet niets")
	screen.free()


## Two items and XP: a page each, the XP chip and the count chip, the footer counting, and
## closed after the last (finished once, the pause back).
func test_pages_one_after_the_other(test) -> void:
	var screen := RewardScreen.new()
	tree.root.add_child(screen)
	var was_paused := tree.paused
	var closed := [0]
	screen.finished.connect(func() -> void: closed[0] += 1)
	screen.open({"heading": "MISSIE VOLBRACHT", "title": "Eerst eten", "xp": 150,
		"items": [{"item": "kroket", "count": 1}, {"item": "appel", "count": 3}]})
	test.check(screen._heading.text == "◆ MISSIE VOLBRACHT" and screen._title.text == "Eerst eten" and screen._title.visible, "de kop en waarvoor")
	test.check(screen._footer.text == "[ENTER] VERDER  1 / 2", "de voet telt de bladzijden")
	test.check(screen._chips.visible and screen._chips.get_child_count() == 1 and screen._item_view.visible and not screen._big_xp.visible,
		"de eerste: het item met een chip voor de XP")
	test.check(screen._rarity.text == "BIJZONDER" and screen._rarity.visible, "hoe zeldzaam het is")
	screen.next_page()
	test.check(screen.is_showing() and screen.current_page().item == "appel" and screen._footer.text == "[ENTER] OK", "de tweede: de appel, de laatste")
	var chips := screen._chips.get_children().filter(func(chip: Node) -> bool: return not chip.is_queued_for_deletion())
	test.check(chips.size() == 1 and (chips[0].get_child(0) as Label).text == "3 x", "een chip voor het aantal, geen XP meer")
	test.check(screen._name.text == "GEKNEUSDE APPEL" and screen._rarity.text == "GEWOON", "zijn naam en zeldzaamheid")
	test.check(screen._since == 0.0, "de wachttijd voor de toetsen begint opnieuw")
	screen.next_page()
	test.check(not screen.is_showing() and closed[0] == 1 and tree.paused == was_paused, "na de laatste: dicht, finished, de pauze terug")
	screen.next_page()
	test.check(closed[0] == 1, "nog een keer verder: niets")
	tree.paused = was_paused
	screen.free()


## Only experience: the XP big in place of the item, no chips, no rarity, no title line.
func test_only_xp_shows_it_big(test) -> void:
	var screen := RewardScreen.new()
	tree.root.add_child(screen)
	var was_paused := tree.paused
	screen.open({"heading": "TAAK VOLBRACHT", "xp": 75})
	test.check(screen._big_xp.visible and screen._big_xp.text == "+75 XP" and not screen._item_view.visible, "de XP groot, geen item")
	test.check(screen._name.text == "ERVARING" and not screen._rarity.visible and not screen._chips.visible and not screen._title.visible,
		"ERVARING, zonder zeldzaamheid, chips of titel")
	test.check(screen._name.get_theme_color("font_color") == RewardScreen.XP_COLOUR and screen._footer.text == "[ENTER] OK", "in de kleur van XP")
	screen.next_page()
	tree.paused = was_paused
	screen.free()


## The keys and the mouse: only after KEYS_AFTER, only the keys of the screen, a click too;
## everything else is the screen's own but does nothing.
func test_which_keys_press_the_reward_away(test) -> void:
	var screen := RewardScreen.new()
	tree.root.add_child(screen)
	var was_paused := tree.paused
	var reward := {"xp": 10, "items": [{"item": "kroket"}]}
	screen.open(reward)
	screen._process(RewardScreen.KEYS_AFTER * 0.5)
	screen.handle_input(_key(KEY_SPACE))
	test.check(screen.is_showing(), "te vroeg: Spatie doet nog niets")
	screen._process(RewardScreen.KEYS_AFTER * 0.6)
	test.check(screen.handle_input(_key(KEY_W)) and screen.is_showing(), "een toets van het spel is van het scherm maar sluit niet")
	var released := _key(KEY_ENTER)
	released.pressed = false
	var echo := _key(KEY_ENTER)
	echo.echo = true
	screen.handle_input(released)
	screen.handle_input(echo)
	test.check(screen.is_showing(), "loslaten of ingehouden houden sluit niet")
	test.check(not screen.handle_input(InputEventMouseMotion.new()) and not screen.handle_input(InputEventJoypadButton.new()), "de muis bewegen of een controllerknop is niet voor handle_input")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	test.check(screen.handle_input(right_click) and screen.is_showing(), "de rechtermuisknop sluit niet")
	for keycode: Key in [KEY_SPACE, KEY_E, KEY_ESCAPE, KEY_KP_ENTER]:
		screen.open(reward)
		screen._since = RewardScreen.KEYS_AFTER
		screen.handle_input(_key(keycode))
		test.check(not screen.is_showing(), "%s drukt het weg" % OS.get_keycode_string(keycode))
	screen.open(reward)
	screen._since = RewardScreen.KEYS_AFTER
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	test.check(screen.handle_input(click) and not screen.is_showing(), "een klik ook")
	tree.paused = was_paused
	screen.free()


## keep_paused (the HUD: another screen still up) decides the pause after closing; a reward
## opened while one is up replaces its pages and keeps the pause of before the first.
func test_the_pause_after_the_reward(test) -> void:
	var screen := RewardScreen.new()
	tree.root.add_child(screen)
	var was_paused := tree.paused
	screen.keep_paused = func() -> bool: return true
	screen.open({"xp": 10})
	screen.next_page()
	test.check(not screen.is_showing() and tree.paused, "een ander scherm staat nog open: het spel blijft stil")
	screen.keep_paused = Callable()
	tree.paused = false
	screen.open({"xp": 10})
	screen.open({"xp": 20, "items": [{"item": "appel"}]})
	test.check(screen.current_page().item == "appel" and tree.paused, "een nieuwe beloning in het open scherm")
	screen.next_page()
	test.check(not tree.paused, "dicht: de pauze van voor de eerste")
	tree.paused = was_paused
	screen.free()
