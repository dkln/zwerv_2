extends RefCounted
## Unit tests of the mission data (data/missies/*.json, scripts/story/story.gd): every mission
## can be read, has what the story needs, its goals are of a kind the story knows, and the
## missions it starts after exist.

const Story = preload("res://scripts/story/story.gd")
const GOALS := ["geld_verdiend", "kopen", "praten_met", "naar_plek"]


func test_the_missions_can_be_read(test) -> void:
	var missions := Story.load_missions()
	test.check(missions.size() >= 1, "missies gevonden (%d)" % missions.size())
	test.check(missions.any(func(data: Dictionary) -> bool: return data.id == "missie_1_kroket"), "missie 1")


func test_every_mission_is_complete(test) -> void:
	var missions := Story.load_missions()
	var ids := missions.map(func(data: Dictionary) -> String: return str(data.id))
	for data: Dictionary in missions:
		for key in ["id", "titel", "start", "stappen"]:
			test.check(data.has(key), "%s heeft %s" % [data.get("id", "?"), key])
		var start := str(data.get("start", ""))
		test.check(start == "na_proloog" or (start.begins_with("na:") and ids.has(start.trim_prefix("na:"))),
				"%s start na iets dat er is (%s)" % [data.id, start])
		for step: Dictionary in data.get("stappen", []):
			var goal: Dictionary = step.get("doel", {})
			test.check(step.has("id") and step.has("tekst"), "%s: stap met id en tekst" % data.id)
			test.check(GOALS.has(str(goal.get("soort", ""))), "%s/%s: een bekend doel (%s)" % [data.id, step.get("id"), goal.get("soort")])
