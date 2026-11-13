extends RefCounted
## Unit tests of rewards: what a task or a mission done gives (scripts/story/story.gd
## _give_reward: its XP once, its items "geeft", quietly into the player), the pages of the
## reward screen (scripts/ui/reward_screen.gd: one per item, the XP on the first, only XP
## alone), the screen itself (the item turning, pressed away, the game paused meanwhile),
## the quiet add_item/add_xp of the player, and the cash machines as places of the map
## (scripts/ui/game_menu.gd). The player is a stand-in.

const Story = preload("res://scripts/story/story.gd")
const RewardScreen = preload("res://scripts/ui/reward_screen.gd")
const GameMenu = preload("res://scripts/ui/game_menu.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Takes what it gets and remembers whether it was quiet.
class TestPlayer:
	extends Node
	var items := {}
	var xp := 0.0
	var loud := 0

	func add_item(item_id: String, count := 1, quiet := false) -> bool:
		items[item_id] = int(items.get(item_id, 0)) + count
		if not quiet:
			loud += 1
		return true

	func add_xp(points: float, quiet := false) -> void:
		xp += points
		if not quiet:
			loud += 1


func _mission() -> Dictionary:
	return {"id": "proef", "titel": "Een proef", "xp": 150, "geeft": [{"item": "koffie"}],
		"stappen": [
			{"id": "een", "tekst": "Doe iets", "xp": 50, "geeft": [{"item": "stroopwafel", "aantal": 2}]},
			{"id": "twee", "tekst": "Doe nog iets", "xp": 100},
		]}


## A task done gives its XP and items into the player quietly (nothing floats up, the
## screen shows it), the XP only once; the whole mission done says so.
func test_a_task_done_gives_its_xp_and_items_quietly_once(test) -> void:
	var story := Story.new()
	var player := TestPlayer.new()
	story.set("_player", player)
	var data := _mission()
	var first: Dictionary = data.stappen[0]
	var reward: Dictionary = story._give_reward(data, first, false)
	test.check(reward.heading == "TAAK VOLBRACHT" and reward.title == "Doe iets", "een taak: TAAK VOLBRACHT, met de taak")
	test.check(int(reward.xp) == 50 and reward.items == [{"item": "stroopwafel", "count": 2}], "zijn XP en zijn items")
	test.check(player.xp == 50.0 and int(player.items.get("stroopwafel", 0)) == 2, "in de speler")
	test.check(player.loud == 0, "stil: niets zweeft op, het scherm laat het zien")
	var again: Dictionary = story._give_reward(data, first, false)
	test.check(int(again.xp) == 0, "de XP maar één keer")
	var last: Dictionary = data.stappen[1]
	var whole: Dictionary = story._give_reward(data, last, true)
	test.check(whole.heading == "MISSIE VOLBRACHT" and whole.title == "Een proef", "de hele missie: MISSIE VOLBRACHT")
	test.check(int(whole.xp) == 250 and whole.items == [{"item": "koffie", "count": 1}], "stap en missie samen (%d XP)" % int(whole.xp))
	player.free()
	story.free()


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


## GameMenu tells the cash machines among the places of the map: pinautomaat_3 is one
## and no supermarket, a supermarket is no cash machine.
func test_the_cash_machines_are_places_of_the_map(test) -> void:
	test.check(GameMenu.is_cash_machine("pinautomaat_3"), "pinautomaat_3 is een pinautomaat")
	test.check(not GameMenu.is_cash_machine("derrek_2") and GameMenu.supermarket_chain("pinautomaat_3") == "",
		"geen supermarkt, en een supermarkt geen pinautomaat")
