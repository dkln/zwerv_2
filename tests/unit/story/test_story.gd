extends RefCounted
## Unit tests of the story (scripts/story/story.gd): what a task or a mission done gives
## (_give_reward: its XP once, its items "geeft", quietly into the player; the reward screen
## shows it). The player is a stand-in.
##   tests/run_unit_tests.sh test_story.

const Story = preload("res://scripts/story/story.gd")


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
