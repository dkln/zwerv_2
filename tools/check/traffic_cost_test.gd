extends SceneTree
## What the crowd round the player costs on the CPU (headless): the town at the morning rush
## (08:00, the most vehicles and people: Traffic, Pedestrians, data/drukte.json), measured as
## the real time a frame takes (wall clock) over FRAMES frames after it filled up. It must stay
## under FRAME_BUDGET_MS, and the town must really be full (most of the vehicles and people
## wanted are there), so a slow spawner or a lookup over every vehicle shows up here.
## (The monitors TIME_PROCESS / TIME_PHYSICS_PROCESS are not used: headless they are no
## measure of what a frame costs.)
## usage: tools/godot.sh --headless --script tools/check/traffic_cost_test.gd -- [hour]

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const FRAMES := 300
const FRAME_BUDGET_MS := 16.0

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 250)
	var hour := Common.arg_float(0, 8.0)
	PlayerCharacter.choose("jos")
	var scene := Common.instantiate(Common.CITY, false)
	if scene.has_node("Verhaal"):
		scene.get_node("Verhaal").free()
	var traffic: Traffic = scene.get_node("Verkeer")
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	traffic.unseen_without_camera = true
	walkers.unseen_without_camera = true
	var day: Node = scene.get_node("Dagcyclus")
	day.speed = 0.0
	day.time_of_day = hour
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	for frame_index in 900:
		paused = false
		await process_frame
		if frame_index > 120 and player._placed:
			break
	for frame_index in 240:
		paused = false
		await process_frame
	var started := Time.get_ticks_usec()
	for frame_index in FRAMES:
		paused = false
		await process_frame
	var frame_ms := (Time.get_ticks_usec() - started) / 1000.0 / FRAMES
	var wanted: Vector2i = traffic.wanted_counts()
	print("%02.0f:00: %d voertuigen (gewenst %d + %d), %d voetgangers (gewenst %d), een beeld %.1f ms" % [hour,
			traffic._town.size(), wanted.x, wanted.y, walkers.people().size(), walkers.wanted_count(), frame_ms])
	_check(traffic._town.size() >= wanted.x * 0.8, "de stad vol verkeer (%d van %d)" % [traffic._town.size(), wanted.x])
	_check(walkers.people().size() >= walkers.wanted_count() * 0.8, "en vol mensen (%d van %d)" % [walkers.people().size(), walkers.wanted_count()])
	_check(frame_ms < FRAME_BUDGET_MS, "een beeld binnen %.0f ms (%.1f ms)" % [FRAME_BUDGET_MS, frame_ms])
	print("drukte-kosten ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
